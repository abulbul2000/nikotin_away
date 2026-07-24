package com.example.no_smoke

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.BatteryManager
import android.os.PowerManager
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/// Wakes briefly on an AlarmManager tick to record two free, already-cached
/// OS signals (screen-interactive state, charging state) as one row, then
/// reschedules itself for as long as the current time stays inside the
/// configured window. No sensor listener is ever registered — reading
/// PowerManager/BatteryManager state costs no measurable battery, unlike
/// keeping an accelerometer or the app process alive all night. Stops once
/// past the window end; SleepProbeBootReceiver re-arms after a reboot, and
/// SleepIntelligenceEngine (Dart side) treats a night with too few rows as
/// "insufficient coverage" and falls back to the user's static survey sleep
/// time rather than guessing.
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

        // The user is awake (screen on) during what should be their sleep
        // window -- queue this so the Dart side can decide, next time it
        // runs, whether to fire a full mandatory task or just a small
        // advisory tip (see StorageService.isDailyTaskQuotaMet). Detection
        // granularity is however often this probe fires (intervalMinutes,
        // tightened specifically during the sleep window -- see
        // SleepIntelligenceService) rather than truly instant, since acting
        // on it needs Dart-side business logic this native receiver
        // deliberately doesn't duplicate.
        if (isAwake && isWithinWindow(currentMinuteOfDay(), windowStartMinute, windowEndMinute)) {
            SleepActivityStore.enqueueActivity(context)
        }

        if (!isWithinWindow(currentMinuteOfDay(), windowStartMinute, windowEndMinute)) {
            return
        }
        scheduleFireInMinutes(context, windowStartMinute, windowEndMinute, intervalMinutes, intervalMinutes)
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
    }
}

/// Shared SharedPreferences-backed schedule config, read by the boot
/// receiver to re-arm probing without needing the Dart side to run first.
object SleepProbeStore {
    private const val PREFS = "no_smoke_sleep_probe"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_WINDOW_START = "window_start_minute"
    private const val KEY_WINDOW_END = "window_end_minute"
    private const val KEY_INTERVAL = "interval_minutes"
    private const val TABLE = "sleep_probe_events"
    private const val RETENTION_DAYS = 14

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
