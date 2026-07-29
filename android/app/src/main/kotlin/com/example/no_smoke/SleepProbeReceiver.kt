package com.example.no_smoke

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import androidx.core.content.ContextCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import kotlin.math.sqrt

/// Wakes briefly on an AlarmManager tick to record two free, already-cached
/// OS signals (screen-interactive state, charging state) as one row, then
/// reschedules itself for as long as the current time stays inside the
/// configured window. Stops once past the window end; SleepProbeBootReceiver
/// re-arms after a reboot, and SleepIntelligenceEngine (Dart side) treats a
/// night with too few rows as "insufficient coverage" and falls back to the
/// user's static survey sleep time rather than guessing.
class SleepProbeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_PROBE) {
            return
        }

        val windowStartMinute = intent.getIntExtra(EXTRA_WINDOW_START_MINUTE, -1)
        val windowEndMinute = intent.getIntExtra(EXTRA_WINDOW_END_MINUTE, -1)
        val intervalMinutes = intent.getIntExtra(EXTRA_INTERVAL_MINUTES, DEFAULT_INTERVAL_MINUTES)
        if (windowStartMinute < 0 || windowEndMinute < 0) {
            return
        }

        val isAwake = isInteractive(context)
        SleepProbeStore.insertProbe(context, isScreenOff = !isAwake, isCharging = isCharging(context))
        val inWindow = isWithinWindow(currentMinuteOfDay(), windowStartMinute, windowEndMinute)

        if (isAwake && inWindow) {
            // Screen-on alone used to be enough to count as "awake", which is
            // wrong for exactly the case that matters most here: someone who
            // fell asleep with a video playing. Playback keeps the screen on
            // and blocks the auto-lock timer, so the phone reads as "in use"
            // for as long as the video runs, whether anyone is watching it or
            // not. A brief accelerometer read (a few hundred milliseconds,
            // registered and unregistered on the spot — no listener kept
            // alive) tells the two apart: a phone actually being held or
            // touched moves; a phone left running video on a nightstand does
            // not.
            readMotionThenDecide(context, windowStartMinute, windowEndMinute, intervalMinutes)
            return
        }

        finishProbeCycle(context, isAwake, inWindow, windowStartMinute, windowEndMinute, intervalMinutes)
    }

    private fun readMotionThenDecide(
        context: Context,
        windowStartMinute: Int,
        windowEndMinute: Int,
        intervalMinutes: Int,
    ) {
        val pendingResult = goAsync()
        MotionSampler.sample(context) { isMoving ->
            if (isMoving) {
                // The user is awake (screen on, phone moving) during what
                // should be their sleep window -- queue this so the Dart side
                // can decide, next time it runs, whether to fire a full
                // mandatory task or just a small advisory tip (see
                // StorageService.isDailyTaskQuotaMet). Detection granularity
                // is however often this probe fires (intervalMinutes,
                // tightened specifically during the sleep window -- see
                // SleepIntelligenceService) rather than truly instant, since
                // acting on it needs Dart-side business logic this native
                // receiver deliberately doesn't duplicate.
                SleepActivityStore.enqueueActivity(context)
            }
            finishProbeCycle(context, true, true, windowStartMinute, windowEndMinute, intervalMinutes)
            pendingResult.finish()
        }
    }

    private fun finishProbeCycle(
        context: Context,
        isAwake: Boolean,
        inWindow: Boolean,
        windowStartMinute: Int,
        windowEndMinute: Int,
        intervalMinutes: Int,
    ) {
        // Opt-in, separate from Sleep Intelligence itself (see
        // SnoringProbeStore/SnoringDetectionService) -- only runs while the
        // screen is off (the user is presumably actually asleep, not just
        // in the configured window) and piggybacks on this same alarm tick
        // rather than running its own schedule.
        if (!isAwake &&
            SleepProbeStore.isSnoringDetectionEnabled(context) &&
            inWindow
        ) {
            captureAndAnalyzeSnoring(context)
        }

        if (!inWindow) {
            return
        }
        scheduleFireInMinutes(context, windowStartMinute, windowEndMinute, intervalMinutes, intervalMinutes)
    }

    /// Captures a short (3s) raw audio sample via AudioRecord (not
    /// MediaRecorder -- no file is ever written, the PCM buffer lives only
    /// in memory for the few hundred milliseconds it takes to compute an
    /// energy envelope, then is discarded) and looks for a rhythmic
    /// loud/quiet pattern in the ~0.3-1.5s cycle range typical of snoring.
    /// VOICE_RECOGNITION disables the platform's automatic gain control,
    /// same reasoning as the breath test's acoustic detection: AGC would
    /// otherwise flatten exactly the energy swings this heuristic looks for.
    private fun captureAndAnalyzeSnoring(context: Context) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val sampleRate = 16000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        if (minBufferSize <= 0) {
            return
        }

        var audioRecord: AudioRecord? = null
        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                channelConfig,
                audioFormat,
                minBufferSize * 2,
            )
            if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
                return
            }
            audioRecord.startRecording()

            val windowMs = 100
            val windowSamples = sampleRate * windowMs / 1000
            val windowCount = SNORING_CAPTURE_DURATION_MS / windowMs
            val buffer = ShortArray(windowSamples)
            val energies = DoubleArray(windowCount)

            for (i in 0 until windowCount) {
                val read = audioRecord.read(buffer, 0, windowSamples)
                if (read > 0) {
                    var sumSquares = 0.0
                    for (j in 0 until read) {
                        val normalized = buffer[j] / 32768.0
                        sumSquares += normalized * normalized
                    }
                    energies[i] = sqrt(sumSquares / read)
                }
            }

            audioRecord.stop()
            SnoringProbeStore.insertProbe(context, detectSnorePattern(energies, windowMs))
        } catch (_: Exception) {
            // Best-effort -- a missed capture just skips this probe cycle.
        } finally {
            audioRecord?.release()
        }
    }

    /// Simple rule-based heuristic (energy envelope + periodicity), same
    /// spirit as BreathAcousticEngine: finds windows loud enough relative to
    /// this clip's own median to count as a "burst", collapses adjacent
    /// loud windows into single events, then checks whether consecutive
    /// events repeat at a snore-typical interval.
    private fun detectSnorePattern(energies: DoubleArray, windowMs: Int): Boolean {
        if (energies.isEmpty()) {
            return false
        }
        val sorted = energies.sorted()
        val median = sorted[sorted.size / 2]
        val threshold = median * 2.0 + 0.01

        val events = mutableListOf<Int>()
        var lastEventIndex = -10
        for (i in energies.indices) {
            if (energies[i] > threshold && i - lastEventIndex > 2) {
                events.add(i)
                lastEventIndex = i
            }
        }
        if (events.size < 2) {
            return false
        }

        for (i in 1 until events.size) {
            val gapMs = (events[i] - events[i - 1]) * windowMs
            if (gapMs in SNORE_MIN_CYCLE_MS..SNORE_MAX_CYCLE_MS) {
                return true
            }
        }
        return false
    }

    private fun isInteractive(context: Context): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        return powerManager?.isInteractive ?: true
    }

    private fun isCharging(context: Context): Boolean {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val status = batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS) ?: -1
        return status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
    }

    private fun currentMinuteOfDay(): Int {
        val calendar = Calendar.getInstance()
        return calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
    }

    companion object {
        const val ACTION_PROBE = "com.example.no_smoke.sleepprobe.PROBE"
        const val EXTRA_WINDOW_START_MINUTE = "extra_window_start_minute"
        const val EXTRA_WINDOW_END_MINUTE = "extra_window_end_minute"
        const val EXTRA_INTERVAL_MINUTES = "extra_interval_minutes"
        // Was 45 -- tightened so a user waking up and using their phone
        // mid-sleep-window gets noticed within a few minutes instead of
        // up to 45. Each wake only reads two already-cached OS properties
        // (see onReceive), so the extra wake frequency costs negligible
        // battery despite firing ~15x more often overnight.
        const val DEFAULT_INTERVAL_MINUTES = 5

        fun isWithinWindow(nowMinute: Int, startMinute: Int, endMinute: Int): Boolean {
            return if (startMinute <= endMinute) {
                nowMinute in startMinute..endMinute
            } else {
                // Window crosses midnight, e.g. 22:30-08:00.
                nowMinute >= startMinute || nowMinute <= endMinute
            }
        }

        /// Arms (or re-arms after boot) the next probe: soon if we're
        /// currently inside the window, otherwise at the window's next
        /// start. Used for the initial schedule call and boot recovery.
        fun scheduleWindowAware(context: Context, windowStartMinute: Int, windowEndMinute: Int, intervalMinutes: Int) {
            val calendar = Calendar.getInstance()
            val nowMinute = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
            val delayMinutes = if (isWithinWindow(nowMinute, windowStartMinute, windowEndMinute)) {
                1
            } else {
                val diff = windowStartMinute - nowMinute
                if (diff <= 0) diff + 24 * 60 else diff
            }
            scheduleFireInMinutes(context, windowStartMinute, windowEndMinute, intervalMinutes, delayMinutes)
        }

        private fun scheduleFireInMinutes(
            context: Context,
            windowStartMinute: Int,
            windowEndMinute: Int,
            intervalMinutes: Int,
            delayMinutes: Int,
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val fireAt = System.currentTimeMillis() + delayMinutes * 60_000L
            val pending = pendingIntent(context, windowStartMinute, windowEndMinute, intervalMinutes)
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pending)
        }

        fun cancel(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent(context, 0, 0, DEFAULT_INTERVAL_MINUTES))
        }

        private fun pendingIntent(
            context: Context,
            windowStartMinute: Int,
            windowEndMinute: Int,
            intervalMinutes: Int,
        ): PendingIntent {
            val intent = Intent(context, SleepProbeReceiver::class.java).apply {
                action = ACTION_PROBE
                putExtra(EXTRA_WINDOW_START_MINUTE, windowStartMinute)
                putExtra(EXTRA_WINDOW_END_MINUTE, windowEndMinute)
                putExtra(EXTRA_INTERVAL_MINUTES, intervalMinutes)
            }
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private const val REQUEST_CODE = 84001
        private const val SNORING_CAPTURE_DURATION_MS = 3000
        private const val SNORE_MIN_CYCLE_MS = 300
        private const val SNORE_MAX_CYCLE_MS = 1500
    }
}

/// Shared SharedPreferences-backed schedule config, read by the boot
/// receiver to re-arm probing without needing the Dart side to run first.
/// A brief, one-shot accelerometer read used only to tell "phone actually
/// being held" apart from "phone lying still with the screen kept on by
/// video playback" — the two situations `PowerManager.isInteractive` alone
/// cannot distinguish, since both report the screen as on.
///
/// Registered and unregistered within one probe tick; no listener is ever
/// left running, so this costs nothing between sleep-window probes.
object MotionSampler {
    private const val SAMPLE_DURATION_MS = 600L
    private const val TIMEOUT_MS = 1500L

    /// A phone resting on a nightstand still picks up gravity's ~9.8 m/s² and
    /// a little sensor noise; this threshold is comfortably above that noise
    /// floor but well below what a hand holding or a screen tap produces.
    private const val MOVEMENT_THRESHOLD = 1.2f

    fun sample(context: Context, callback: (Boolean) -> Unit) {
        val sensorManager =
            context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (sensorManager == null || sensor == null) {
            // No accelerometer to read — fail toward the old behaviour
            // (treat screen-on as awake) rather than silently going quiet
            // for a whole night on a device that can't support this check.
            callback(true)
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var finished = false
        var maxDeviation = 0f

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val x = event.values.getOrNull(0) ?: return
                val y = event.values.getOrNull(1) ?: return
                val z = event.values.getOrNull(2) ?: return
                val magnitude = kotlin.math.sqrt(x * x + y * y + z * z)
                val deviation = kotlin.math.abs(magnitude - SensorManager.GRAVITY_EARTH)
                if (deviation > maxDeviation) {
                    maxDeviation = deviation
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        fun finish() {
            if (finished) return
            finished = true
            sensorManager.unregisterListener(listener)
            handler.removeCallbacksAndMessages(null)
            callback(maxDeviation > MOVEMENT_THRESHOLD)
        }

        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_GAME)
        handler.postDelayed(::finish, SAMPLE_DURATION_MS)
        // Belt-and-suspenders timeout in case the sensor never delivers an
        // event on some OEM's power-saving profile.
        handler.postDelayed(::finish, TIMEOUT_MS)
    }
}

object SleepProbeStore {
    private const val PREFS = "no_smoke_sleep_probe"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_WINDOW_START = "window_start_minute"
    private const val KEY_WINDOW_END = "window_end_minute"
    private const val KEY_INTERVAL = "interval_minutes"
    private const val KEY_SNORING_ENABLED = "snoring_detection_enabled"
    private const val TABLE = "sleep_probe_events"
    private const val RETENTION_DAYS = 14

    fun setSnoringDetectionEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_SNORING_ENABLED, enabled)
            .apply()
    }

    fun isSnoringDetectionEnabled(context: Context): Boolean {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_SNORING_ENABLED, false)
    }

    fun saveSchedule(context: Context, windowStartMinute: Int, windowEndMinute: Int, intervalMinutes: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, true)
            .putInt(KEY_WINDOW_START, windowStartMinute)
            .putInt(KEY_WINDOW_END, windowEndMinute)
            .putInt(KEY_INTERVAL, intervalMinutes)
            .apply()
    }

    fun clearSchedule(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, false)
            .apply()
    }

    fun readSchedule(context: Context): Triple<Int, Int, Int>? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) {
            return null
        }
        val start = prefs.getInt(KEY_WINDOW_START, -1)
        val end = prefs.getInt(KEY_WINDOW_END, -1)
        val interval = prefs.getInt(KEY_INTERVAL, SleepProbeReceiver.DEFAULT_INTERVAL_MINUTES)
        if (start < 0 || end < 0) {
            return null
        }
        return Triple(start, end, interval)
    }

    fun insertProbe(context: Context, isScreenOff: Boolean, isCharging: Boolean) {
        val dbFile = File(File(context.applicationInfo.dataDir, "app_flutter"), "no_smoke.db")
        if (!dbFile.exists()) {
            return
        }
        try {
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                val now = System.currentTimeMillis()
                val values = ContentValues().apply {
                    put("id", "sleepprobe_${now}")
                    put("createdAt", formatIsoUtc(now))
                    put("screenOff", if (isScreenOff) 1 else 0)
                    put("charging", if (isCharging) 1 else 0)
                }
                db.insert(TABLE, null, values)

                val cutoff = now - RETENTION_DAYS * 24 * 60 * 60 * 1000L
                db.delete(TABLE, "createdAt < ?", arrayOf(formatIsoUtc(cutoff)))
            }
        } catch (_: Throwable) {
            // Best-effort: a missed probe just lowers this night's coverage,
            // which SleepIntelligenceEngine already treats as "no estimate".
        }
    }

    private fun formatIsoUtc(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(millis)
    }
}

/// Queues "user was awake during their sleep window" events for the Dart
/// side to drain and act on (see NotificationService._syncSleepActivityFromNative
/// -- decides full mandatory task vs. small advisory tip based on whether
/// today's task quota is already met, business logic this native receiver
/// deliberately doesn't duplicate). Same drain-on-next-run pattern as
/// WatchdogStore/TaskOverlayOutcomeStore.
object SleepActivityStore {
    private const val PREFS = "no_smoke_sleep_activity"
    private const val KEY_EVENTS = "queued_events"

    fun enqueueActivity(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = prefs.getStringSet(KEY_EVENTS, emptySet())?.toMutableSet() ?: mutableSetOf()
        current.add("${System.currentTimeMillis()}")
        prefs.edit().putStringSet(KEY_EVENTS, current).apply()
    }

    fun drain(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY_EVENTS, emptySet())?.toList() ?: emptyList()
        prefs.edit().remove(KEY_EVENTS).apply()
        return items
    }
}

/// Writes each snoring probe's boolean result straight to SQLite, same
/// direct-write pattern as SleepProbeStore.insertProbe -- Dart only ever
/// reads this table back (StorageService.countRecentSnoreLikelyEvents),
/// never writes to it, since the whole point is the analysis running
/// natively without needing the Flutter engine alive overnight.
object SnoringProbeStore {
    private const val TABLE = "snoring_probe_events"
    private const val RETENTION_DAYS = 14

    fun insertProbe(context: Context, snoreLikely: Boolean) {
        val dbFile = File(File(context.applicationInfo.dataDir, "app_flutter"), "no_smoke.db")
        if (!dbFile.exists()) {
            return
        }
        try {
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                val now = System.currentTimeMillis()
                val values = ContentValues().apply {
                    put("id", "snoreprobe_${now}")
                    put("createdAt", formatIsoUtc(now))
                    put("snoreLikely", if (snoreLikely) 1 else 0)
                }
                db.insert(TABLE, null, values)

                val cutoff = now - RETENTION_DAYS * 24 * 60 * 60 * 1000L
                db.delete(TABLE, "createdAt < ?", arrayOf(formatIsoUtc(cutoff)))
            }
        } catch (_: Throwable) {
            // Best-effort: a missed write just costs one data point.
        }
    }

    private fun formatIsoUtc(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(millis)
    }
}
