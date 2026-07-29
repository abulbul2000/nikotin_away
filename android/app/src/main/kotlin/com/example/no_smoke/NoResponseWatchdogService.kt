package com.example.no_smoke

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class NoResponseWatchdogService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val checker = object : Runnable {
        override fun run() {
            val state = WatchdogStore.loadActive(this@NoResponseWatchdogService)
            if (state != null && !state.acknowledged && System.currentTimeMillis() >= state.dueAtMillis) {
                WatchdogViolationNotifier.triggerNoResponseViolation(this@NoResponseWatchdogService, state)
                WatchdogStore.clearActive(this@NoResponseWatchdogService)
                stopSelf()
                return
            }
            handler.postDelayed(this, 15000)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE).orEmpty()
                val watchdogId = intent.getStringExtra(EXTRA_WATCHDOG_ID).orEmpty()
                val dueAtMillis = intent.getLongExtra(EXTRA_DUE_AT_MILLIS, 0L)
                if (taskTitle.isNotBlank() && watchdogId.isNotBlank() && dueAtMillis > 0L) {
                    WatchdogStore.saveActive(
                        context = this,
                        state = WatchdogState(
                            watchdogId = watchdogId,
                            taskTitle = taskTitle,
                            dueAtMillis = dueAtMillis,
                            acknowledged = false,
                        ),
                    )
                    scheduleAlarmBackup(watchdogId, dueAtMillis)
                    ensureForeground(taskTitle)
                    handler.removeCallbacks(checker)
                    handler.post(checker)
                }
            }
            ACTION_ACK -> {
                val watchdogId = intent.getStringExtra(EXTRA_WATCHDOG_ID).orEmpty()
                val state = WatchdogStore.loadActive(this)
                if (state != null && state.watchdogId == watchdogId) {
                    WatchdogStore.markAcknowledged(this)
                }
                WatchdogStore.clearActive(this)
                handler.removeCallbacks(checker)
                stopSelf()
            }
            else -> {
                val state = WatchdogStore.loadActive(this)
                if (state != null && !state.acknowledged) {
                    ensureForeground(state.taskTitle)
                    handler.removeCallbacks(checker)
                    handler.post(checker)
                }
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(checker)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /// Android requires any foreground service to show a notification for as
    /// long as it runs — this cannot be turned off, only made as quiet as the
    /// platform allows. The task alert with its full-screen intent is the
    /// user-facing prompt; this exists purely so the OS does not kill the
    /// timer counting down to it. Silent, minimum priority, marked as a
    /// service notification (Android groups those separately from alerts and
    /// collapses them in the shade), and worded as bookkeeping rather than as
    /// a second thing asking for attention — a user seeing "Watchdog" and a
    /// countdown right next to a full-screen command read it as two
    /// unrelated things firing at once.
    private fun ensureForeground(taskTitle: String) {
        createChannelIfNeeded()
        val notification = NotificationCompat.Builder(this, FOREGROUND_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Nikotin Away")
            .setContentText("Görev yanıtı bekleniyor")
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    private fun scheduleAlarmBackup(watchdogId: String, dueAtMillis: Long) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val receiverIntent = Intent(this, WatchdogTimeoutReceiver::class.java).apply {
            action = WatchdogTimeoutReceiver.ACTION_TIMEOUT
            putExtra(EXTRA_WATCHDOG_ID, watchdogId)
        }
        val pending = PendingIntent.getBroadcast(
            this,
            watchdogId.hashCode(),
            receiverIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, dueAtMillis, pending)
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(FOREGROUND_CHANNEL_ID)
        if (existing != null) {
            return
        }
        // MIN, not LOW: on API 26+ the channel's importance overrides
        // whatever the builder sets per-notification, and this one only
        // exists to satisfy the foreground-service requirement, never to ask
        // for attention on its own.
        val channel = NotificationChannel(
            FOREGROUND_CHANNEL_ID,
            "Arka plan servisi",
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "No response 10-minute watchdog foreground service"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.example.no_smoke.watchdog.START"
        const val ACTION_ACK = "com.example.no_smoke.watchdog.ACK"
        const val EXTRA_TASK_TITLE = "extra_task_title"
        const val EXTRA_WATCHDOG_ID = "extra_watchdog_id"
        const val EXTRA_DUE_AT_MILLIS = "extra_due_at_millis"

        const val FOREGROUND_CHANNEL_ID = "watchdog_foreground_channel"
        const val VIOLATION_CHANNEL_ID = "watchdog_violation_channel"
        const val FOREGROUND_NOTIFICATION_ID = 73001

        fun start(context: Context, taskTitle: String, watchdogId: String, dueAtMillis: Long) {
            val intent = Intent(context, NoResponseWatchdogService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_WATCHDOG_ID, watchdogId)
                putExtra(EXTRA_DUE_AT_MILLIS, dueAtMillis)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun acknowledge(context: Context, watchdogId: String) {
            val intent = Intent(context, NoResponseWatchdogService::class.java).apply {
                action = ACTION_ACK
                putExtra(EXTRA_WATCHDOG_ID, watchdogId)
            }
            context.startService(intent)
        }
    }
}

data class WatchdogState(
    val watchdogId: String,
    val taskTitle: String,
    val dueAtMillis: Long,
    val acknowledged: Boolean,
)

object WatchdogStore {
    private const val PREFS = "no_smoke_watchdog"
    private const val KEY_ID = "active_id"
    private const val KEY_TITLE = "active_title"
    private const val KEY_DUE_AT = "active_due_at"
    private const val KEY_ACK = "active_ack"
    private const val KEY_VIOLATIONS = "queued_violations"

    fun saveActive(context: Context, state: WatchdogState) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ID, state.watchdogId)
            .putString(KEY_TITLE, state.taskTitle)
            .putLong(KEY_DUE_AT, state.dueAtMillis)
            .putBoolean(KEY_ACK, state.acknowledged)
            .apply()
    }

    fun markAcknowledged(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ACK, true)
            .apply()
    }

    fun loadActive(context: Context): WatchdogState? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val id = prefs.getString(KEY_ID, null) ?: return null
        val title = prefs.getString(KEY_TITLE, null) ?: return null
        val due = prefs.getLong(KEY_DUE_AT, 0L)
        if (due <= 0L) {
            return null
        }
        val ack = prefs.getBoolean(KEY_ACK, false)
        return WatchdogState(id, title, due, ack)
    }

    fun clearActive(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_ID)
            .remove(KEY_TITLE)
            .remove(KEY_DUE_AT)
            .remove(KEY_ACK)
            .apply()
    }

    fun enqueueViolation(context: Context, payload: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = prefs.getStringSet(KEY_VIOLATIONS, emptySet())?.toMutableSet() ?: mutableSetOf()
        current.add(payload)
        prefs.edit().putStringSet(KEY_VIOLATIONS, current).apply()
    }

    fun drainViolations(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY_VIOLATIONS, emptySet())?.toList() ?: emptyList()
        prefs.edit().remove(KEY_VIOLATIONS).apply()
        return items
    }
}

object WatchdogViolationNotifier {
    fun triggerNoResponseViolation(context: Context, state: WatchdogState) {
        createViolationChannelIfNeeded(context)

        val inserted = NativeViolationStore.tryInsertNoResponseViolation(context, state)
        if (!inserted) {
            val payload = "no_response_10_min|${state.taskTitle}|${System.currentTimeMillis()}"
            WatchdogStore.enqueueViolation(context, payload)
        }

        val id = state.watchdogId.hashCode().let { if (it < 0) -it else it }
        val notification = NotificationCompat.Builder(context, NoResponseWatchdogService.VIOLATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Nikotin Away Ihlal")
            .setContentText("10 dakika yanit yok. Gorev ihlali kaydedildi: ${state.taskTitle}")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(id, notification)
    }

    private fun createViolationChannelIfNeeded(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(NoResponseWatchdogService.VIOLATION_CHANNEL_ID)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            NoResponseWatchdogService.VIOLATION_CHANNEL_ID,
            "Nikotin Away Ihlal Uyarilari",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "10 dakika yanitsiz gorev ihlali"
        }
        manager.createNotificationChannel(channel)
    }
}

object NativeViolationStore {
    private const val TABLE = "protocol_violations"

    fun tryInsertNoResponseViolation(context: Context, state: WatchdogState): Boolean {
        val dbFile = File(File(context.applicationInfo.dataDir, "app_flutter"), "no_smoke.db")
        if (!dbFile.exists()) {
            return false
        }

        return try {
            SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE,
            ).use { db ->
                val now = System.currentTimeMillis()
                val values = ContentValues().apply {
                    put("id", "vio_native_${now}_${state.watchdogId}")
                    put("type", "no_response_10_min")
                    put("severity", "high")
                    put("source", "native_direct")
                    put("taskTitle", state.taskTitle)
                    put("details", "10 minutes passed with no response to task notification.")
                    put("createdAt", formatIsoUtc(now))
                    put("resolved", 0)
                }

                db.insert(TABLE, null, values)
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun formatIsoUtc(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(millis)
    }
}
