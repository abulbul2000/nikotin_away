package com.nikotinaway.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/// Reads the device's hardware step-counter sensor (TYPE_STEP_COUNTER) --
/// a single cumulative count since last reboot that the OS batches at the
/// hardware level, so registering a listener costs essentially nothing
/// (no continuous polling, no GPS/radio use). Delivers the last-known value
/// near-instantly on registration, which is all callers here ever want.
object StepCounterReader {
    private const val TIMEOUT_MS = 5000L

    fun readOnce(context: Context, callback: (Int?) -> Unit) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensorManager == null || sensor == null) {
            callback(null)
            return
        }

        val handler = Handler(Looper.getMainLooper())
        var finished = false

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (finished) return
                finished = true
                val value = event.values.getOrNull(0)?.toInt()
                sensorManager.unregisterListener(this)
                handler.removeCallbacksAndMessages(null)
                callback(value)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }

        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)

        handler.postDelayed({
            if (!finished) {
                finished = true
                sensorManager.unregisterListener(listener)
                callback(null)
            }
        }, TIMEOUT_MS)
    }
}

/// Wakes once daily, shortly after local midnight, so a day-boundary
/// cumulative-step snapshot exists even on days the app is never opened --
/// StepTrendEngine (Dart) needs one sample near each midnight to compute
/// clean daily deltas from the raw cumulative counter.
class StepProbeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_PROBE) {
            return
        }
        val pendingResult = goAsync()
        StepCounterReader.readOnce(context) { steps ->
            if (steps != null) {
                StepProbeStore.insertSample(context, steps)
            }
            scheduleNext(context)
            pendingResult.finish()
        }
    }

    companion object {
        const val ACTION_PROBE = "com.nikotinaway.app.stepprobe.PROBE"
        private const val REQUEST_CODE = 87001
        private const val PROBE_HOUR = 0
        private const val PROBE_MINUTE = 5

        fun scheduleNext(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAtMillis = nextProbeMillis()
            val pending = pendingIntent(context)
            // A day-boundary step snapshot is not clock-critical. Preserve the
            // sample on Android 12+ even when exact alarms are unavailable.
            val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarmManager.canScheduleExactAlarms()
            if (canScheduleExact) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pending,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pending,
                )
            }
        }

        fun cancel(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent(context))
        }

        private fun nextProbeMillis(): Long {
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, PROBE_HOUR)
            calendar.set(Calendar.MINUTE, PROBE_MINUTE)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            if (calendar.timeInMillis <= System.currentTimeMillis()) {
                calendar.add(Calendar.DAY_OF_YEAR, 1)
            }
            return calendar.timeInMillis
        }

        private fun pendingIntent(context: Context): PendingIntent {
            val intent = Intent(context, StepProbeReceiver::class.java).apply {
                action = ACTION_PROBE
            }
            return PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}

/// SharedPreferences enabled-flag (read by the boot receiver) + a small
/// direct-SQLite sample log -- mirrors SleepProbeStore/WatchdogStore.
object StepProbeStore {
    private const val PREFS = "no_smoke_step_probe"
    private const val KEY_ENABLED = "enabled"
    private const val TABLE = "step_counter_samples"
    private const val RETENTION_DAYS = 400

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, enabled)
            .apply()
    }

    fun isEnabled(context: Context): Boolean {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)
    }

    fun insertSample(context: Context, cumulativeSteps: Int) {
        val dbFile = File(File(context.applicationInfo.dataDir, "app_flutter"), "no_smoke.db")
        if (!dbFile.exists()) {
            return
        }
        try {
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                val now = System.currentTimeMillis()
                val values = ContentValues().apply {
                    put("id", "stepsample_${now}")
                    put("createdAt", formatIsoUtc(now))
                    put("cumulativeSteps", cumulativeSteps)
                }
                db.insert(TABLE, null, values)

                // A little over a year of daily+per-open samples is still
                // small; trimmed mainly so the table doesn't grow forever.
                val cutoff = now - RETENTION_DAYS * 24 * 60 * 60 * 1000L
                db.delete(TABLE, "createdAt < ?", arrayOf(formatIsoUtc(cutoff)))
            }
        } catch (_: Throwable) {
            // Best-effort, same posture as the other native writers.
        }
    }

    private fun formatIsoUtc(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(millis)
    }
}
