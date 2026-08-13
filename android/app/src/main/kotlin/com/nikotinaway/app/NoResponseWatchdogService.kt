package com.nikotinaway.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NoResponseWatchdogService : Service() {
    private val handler = Handler(Looper.getMainLooper())

    /// Walks every currently-registered watchdog (up to
    /// [WatchdogStore.MAX_ACTIVE_WATCHDOGS]) each tick. A watchdog past its
    /// current [WatchdogState.dueAtMillis] either advances to its next
    /// attempt (re-arming the backup alarm [WatchdogStore.RETRY_INTERVAL_MILLIS]
    /// out) or, once [WatchdogState.attemptCount] reaches
    /// [WatchdogStore.MAX_ATTEMPTS], is reported as a violation and cleared.
    /// The service stops only once nothing is left active.
    private val checker = object : Runnable {
        override fun run() {
            val service = this@NoResponseWatchdogService
            val active = WatchdogStore.loadAllActive(service)
            for (state in active) {
                if (state.acknowledged || System.currentTimeMillis() < state.dueAtMillis) {
                    continue
                }
                if (state.attemptCount >= WatchdogStore.MAX_ATTEMPTS) {
                    WatchdogViolationNotifier.triggerNoResponseViolation(service, state)
                    WatchdogStore.clearActive(service, state.watchdogId)
                } else {
                    WatchdogStore.recordUnansweredAttempt(service, state)
                    scheduleAlarmBackup(state.watchdogId, state.dueAtMillis + WatchdogStore.RETRY_INTERVAL_MILLIS)
                }
            }
            val remaining = WatchdogStore.loadAllActive(service)
            if (remaining.isEmpty()) {
                stopSelf()
                return
            }
            ensureForeground(remaining)
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
                    // The first of MAX_ATTEMPTS check-ins happens after one
                    // RETRY_INTERVAL_MILLIS, not at the full window's end —
                    // dueAtMillis coming in is already the *final* deadline
                    // (see TaskTriggerReceiver.schedule), so the first attempt
                    // boundary is the window's start plus one interval.
                    val totalWindowMillis = dueAtMillis - System.currentTimeMillis()
                    val firstAttemptDueAtMillis = if (totalWindowMillis > WatchdogStore.RETRY_INTERVAL_MILLIS) {
                        dueAtMillis - (WatchdogStore.RETRY_INTERVAL_MILLIS * (WatchdogStore.MAX_ATTEMPTS - 1))
                    } else {
                        dueAtMillis
                    }
                    val evicted = WatchdogStore.registerActive(this, watchdogId)
                    if (evicted != null) {
                        cancelAlarmBackup(evicted)
                    }
                    WatchdogStore.saveActive(
                        context = this,
                        state = WatchdogState(
                            watchdogId = watchdogId,
                            taskTitle = taskTitle,
                            dueAtMillis = firstAttemptDueAtMillis,
                            acknowledged = false,
                            attemptCount = 1,
                        ),
                    )
                    WatchdogStore.saveLocalizedText(
                        context = this,
                        foregroundBody = intent.getStringExtra(EXTRA_FOREGROUND_BODY).orEmpty(),
                        violationTitle = intent.getStringExtra(EXTRA_VIOLATION_TITLE).orEmpty(),
                        violationBody = intent.getStringExtra(EXTRA_VIOLATION_BODY).orEmpty(),
                        foregroundChannelName = intent.getStringExtra(EXTRA_FOREGROUND_CHANNEL_NAME).orEmpty(),
                        violationChannelName = intent.getStringExtra(EXTRA_VIOLATION_CHANNEL_NAME).orEmpty(),
                    )
                    scheduleAlarmBackup(watchdogId, firstAttemptDueAtMillis)
                    ensureForeground(WatchdogStore.loadAllActive(this))
                    handler.removeCallbacks(checker)
                    handler.post(checker)
                }
            }
            ACTION_ACK -> {
                val watchdogId = intent.getStringExtra(EXTRA_WATCHDOG_ID).orEmpty()
                if (watchdogId.isNotBlank()) {
                    WatchdogStore.markAcknowledged(this, watchdogId)
                    WatchdogStore.clearActive(this, watchdogId)
                    cancelAlarmBackup(watchdogId)
                }
                val remaining = WatchdogStore.loadAllActive(this)
                if (remaining.isEmpty()) {
                    handler.removeCallbacks(checker)
                    stopSelf()
                } else {
                    ensureForeground(remaining)
                }
            }
            else -> {
                val active = WatchdogStore.loadAllActive(this)
                if (active.isNotEmpty()) {
                    ensureForeground(active)
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
    ///
    /// [active] can now hold up to [WatchdogStore.MAX_ACTIVE_WATCHDOGS]
    /// watchdogs at once — the body names the single task when there is
    /// exactly one, and falls back to a count otherwise, since the
    /// per-task [WatchdogLocalizedText.foregroundBody] template has nowhere
    /// to put a second title.
    ///
    /// Tapping this notification must open the app: HomePage already checks
    /// for a due mandatory task on every resume (_presentMandatoryTaskIfNeeded),
    /// so simply bringing MainActivity to the front is enough to surface the
    /// task overlay — no separate route/payload needs threading through.
    private fun ensureForeground(active: List<WatchdogState>) {
        val texts = WatchdogStore.loadLocalizedText(this)
        createChannelIfNeeded(texts.foregroundChannelName)
        val body = if (active.size <= 1) {
            texts.foregroundBody
        } else {
            "${texts.foregroundBody} (${active.size})"
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                FOREGROUND_NOTIFICATION_ID,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val notification = NotificationCompat.Builder(this, FOREGROUND_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Nikotin Away")
            .setContentText(body)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .apply { contentIntent?.let { setContentIntent(it) } }
            .build()
        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    private fun scheduleAlarmBackup(watchdogId: String, dueAtMillis: Long) {
        WatchdogAlarms.schedule(this, watchdogId, dueAtMillis)
    }

    /// Cancels a watchdog's backup alarm — needed when [WatchdogStore.registerActive]
    /// evicts a slot, so the evicted watchdogId's alarm doesn't fire later
    /// and find no matching state (the exact silent-loss bug the eviction
    /// itself exists to fix).
    private fun cancelAlarmBackup(watchdogId: String) {
        WatchdogAlarms.cancel(this, watchdogId)
    }

    private fun createChannelIfNeeded(channelName: String) {
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
            channelName.ifBlank { "Background service" },
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "No response 10-minute watchdog foreground service"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.nikotinaway.app.watchdog.START"
        const val ACTION_ACK = "com.nikotinaway.app.watchdog.ACK"
        const val EXTRA_TASK_TITLE = "extra_task_title"
        const val EXTRA_WATCHDOG_ID = "extra_watchdog_id"
        const val EXTRA_DUE_AT_MILLIS = "extra_due_at_millis"
        const val EXTRA_FOREGROUND_BODY = "extra_foreground_body"
        const val EXTRA_VIOLATION_TITLE = "extra_violation_title"
        const val EXTRA_VIOLATION_BODY = "extra_violation_body"
        const val EXTRA_FOREGROUND_CHANNEL_NAME = "extra_foreground_channel_name"
        const val EXTRA_VIOLATION_CHANNEL_NAME = "extra_violation_channel_name"

        const val FOREGROUND_CHANNEL_ID = "watchdog_foreground_channel"
        const val VIOLATION_CHANNEL_ID = "watchdog_violation_channel"
        const val FOREGROUND_NOTIFICATION_ID = 73001

        fun start(
            context: Context,
            taskTitle: String,
            watchdogId: String,
            dueAtMillis: Long,
            foregroundBody: String,
            violationTitle: String,
            violationBody: String,
            foregroundChannelName: String,
            violationChannelName: String,
        ) {
            val intent = Intent(context, NoResponseWatchdogService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_WATCHDOG_ID, watchdogId)
                putExtra(EXTRA_DUE_AT_MILLIS, dueAtMillis)
                putExtra(EXTRA_FOREGROUND_BODY, foregroundBody)
                putExtra(EXTRA_VIOLATION_TITLE, violationTitle)
                putExtra(EXTRA_VIOLATION_BODY, violationBody)
                putExtra(EXTRA_FOREGROUND_CHANNEL_NAME, foregroundChannelName)
                putExtra(EXTRA_VIOLATION_CHANNEL_NAME, violationChannelName)
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

        /// Wakes the service to resume polling already-registered watchdogs
        /// without touching their stored state — unlike [start], which
        /// always (re)registers [EXTRA_WATCHDOG_ID] as a fresh, first-attempt
        /// entry. Used by [WatchdogTimeoutReceiver] after it advances a
        /// watchdog's own attempt counter, in case the process was killed
        /// while the app was backgrounded and nothing is polling it.
        fun resumeIfActive(context: Context) {
            val intent = Intent(context, NoResponseWatchdogService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}

/// The backup alarm that fires [WatchdogTimeoutReceiver] even if
/// [NoResponseWatchdogService]'s own foreground-service checker got killed —
/// shared between the service (which arms it for each attempt) and the
/// receiver (which re-arms it for the next attempt when not yet at
/// [WatchdogStore.MAX_ATTEMPTS]).
object WatchdogAlarms {
    private fun pendingIntent(context: Context, watchdogId: String): PendingIntent {
        val receiverIntent = Intent(context, WatchdogTimeoutReceiver::class.java).apply {
            action = WatchdogTimeoutReceiver.ACTION_TIMEOUT
            putExtra(NoResponseWatchdogService.EXTRA_WATCHDOG_ID, watchdogId)
        }
        return PendingIntent.getBroadcast(
            context,
            watchdogId.hashCode(),
            receiverIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun schedule(context: Context, watchdogId: String, dueAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            dueAtMillis,
            pendingIntent(context, watchdogId),
        )
    }

    fun cancel(context: Context, watchdogId: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent(context, watchdogId))
    }
}

data class WatchdogState(
    val watchdogId: String,
    val taskTitle: String,
    /// The final, third-attempt deadline — the moment a still-unanswered
    /// task is reported as a violation. Individual attempts are spaced
    /// [WatchdogStore.RETRY_INTERVAL_MILLIS] apart, ending here.
    val dueAtMillis: Long,
    val acknowledged: Boolean,
    /// 1 to [WatchdogStore.MAX_ATTEMPTS]. Every [WatchdogStore.RETRY_INTERVAL_MILLIS]
    /// without an ack advances this by one; only reaching the max past
    /// [dueAtMillis] actually reports a violation.
    val attemptCount: Int = 1,
)

data class WatchdogLocalizedText(
    val foregroundBody: String,
    val violationTitle: String,
    val violationBody: String,
    val foregroundChannelName: String,
    val violationChannelName: String,
)

object WatchdogStore {
    private const val PREFS = "no_smoke_watchdog"
    private const val KEY_ACTIVE_IDS = "active_ids"
    private const val KEY_VIOLATIONS = "queued_violations"
    private const val KEY_TEXT_FOREGROUND_BODY = "text_foreground_body"
    private const val KEY_TEXT_VIOLATION_TITLE = "text_violation_title"
    private const val KEY_TEXT_VIOLATION_BODY = "text_violation_body"
    private const val KEY_TEXT_FOREGROUND_CHANNEL = "text_foreground_channel"
    private const val KEY_TEXT_VIOLATION_CHANNEL = "text_violation_channel"

    /// Past this many concurrently-active watchdogs, starting one more
    /// expires the oldest rather than silently overwriting its slot — this
    /// is what used to happen when the store was a single global entry: a
    /// second task's watchdog would overwrite the first's, but the first's
    /// own backup alarm was still armed and would later find no matching
    /// state and silently do nothing, losing the violation entirely.
    const val MAX_ACTIVE_WATCHDOGS = 2

    /// How often an unanswered task's watchdog re-checks before reporting a
    /// violation. Three checks spaced this far apart span the same total
    /// window TaskTriggerReceiver's [WatchdogState.dueAtMillis] already
    /// represents (15 minutes = 3 x 5).
    const val RETRY_INTERVAL_MILLIS = 5L * 60L * 1000L
    const val MAX_ATTEMPTS = 3

    private fun keyId(watchdogId: String) = "wdg_${watchdogId}_id"
    private fun keyTitle(watchdogId: String) = "wdg_${watchdogId}_title"
    private fun keyDueAt(watchdogId: String) = "wdg_${watchdogId}_due_at"
    private fun keyAck(watchdogId: String) = "wdg_${watchdogId}_ack"
    private fun keyAttempt(watchdogId: String) = "wdg_${watchdogId}_attempt"

    private fun loadActiveIds(prefs: android.content.SharedPreferences): List<String> {
        return prefs.getStringSet(KEY_ACTIVE_IDS, emptySet())?.toList() ?: emptyList()
    }

    /// Registers [watchdogId] as active, evicting the oldest-registered
    /// watchdog if this would push the count past [MAX_ACTIVE_WATCHDOGS].
    /// Returns the watchdogId evicted, if any — the caller is responsible
    /// for clearing its native alarm and reporting it to Dart as expired.
    fun registerActive(context: Context, watchdogId: String): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = loadActiveIds(prefs).toMutableList()
        ids.remove(watchdogId)
        ids.add(watchdogId)
        var evicted: String? = null
        while (ids.size > MAX_ACTIVE_WATCHDOGS) {
            evicted = ids.removeAt(0)
        }
        prefs.edit().putStringSet(KEY_ACTIVE_IDS, ids.toSet()).apply()
        if (evicted != null) {
            clearActive(context, evicted)
        }
        return evicted
    }

    fun saveActive(context: Context, state: WatchdogState) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(keyId(state.watchdogId), state.watchdogId)
            .putString(keyTitle(state.watchdogId), state.taskTitle)
            .putLong(keyDueAt(state.watchdogId), state.dueAtMillis)
            .putBoolean(keyAck(state.watchdogId), state.acknowledged)
            .putInt(keyAttempt(state.watchdogId), state.attemptCount)
            .apply()
    }

    // Same fallback contract as every other native surface fed by Dart
    // (SmokedLogOverlayService, TaskTriggerReceiver): missing text falls back
    // to English, never to hardcoded Turkish -- see docs/TRANSLATION_GAP.md.
    fun saveLocalizedText(
        context: Context,
        foregroundBody: String,
        violationTitle: String,
        violationBody: String,
        foregroundChannelName: String,
        violationChannelName: String,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TEXT_FOREGROUND_BODY, foregroundBody)
            .putString(KEY_TEXT_VIOLATION_TITLE, violationTitle)
            .putString(KEY_TEXT_VIOLATION_BODY, violationBody)
            .putString(KEY_TEXT_FOREGROUND_CHANNEL, foregroundChannelName)
            .putString(KEY_TEXT_VIOLATION_CHANNEL, violationChannelName)
            .apply()
    }

    fun loadLocalizedText(context: Context): WatchdogLocalizedText {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return WatchdogLocalizedText(
            foregroundBody = prefs.getString(KEY_TEXT_FOREGROUND_BODY, null)
                ?.takeIf { it.isNotBlank() } ?: "Waiting for task response",
            violationTitle = prefs.getString(KEY_TEXT_VIOLATION_TITLE, null)
                ?.takeIf { it.isNotBlank() } ?: "Nikotin Away Violation",
            violationBody = prefs.getString(KEY_TEXT_VIOLATION_BODY, null)
                ?.takeIf { it.isNotBlank() } ?: "No response for 10 minutes. Task violation recorded: {taskTitle}",
            foregroundChannelName = prefs.getString(KEY_TEXT_FOREGROUND_CHANNEL, null)
                ?.takeIf { it.isNotBlank() } ?: "Background service",
            violationChannelName = prefs.getString(KEY_TEXT_VIOLATION_CHANNEL, null)
                ?.takeIf { it.isNotBlank() } ?: "Nikotin Away Violation Alerts",
        )
    }

    fun markAcknowledged(context: Context, watchdogId: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(keyAck(watchdogId), true)
            .apply()
    }

    /// Advances [watchdogId]'s attempt counter by one and pushes its next
    /// check-in [RETRY_INTERVAL_MILLIS] out — called when a periodic check
    /// finds the watchdog still unacknowledged but not yet at [MAX_ATTEMPTS].
    fun recordUnansweredAttempt(context: Context, state: WatchdogState) {
        saveActive(
            context,
            state.copy(
                attemptCount = state.attemptCount + 1,
                dueAtMillis = state.dueAtMillis + RETRY_INTERVAL_MILLIS,
            ),
        )
    }

    fun loadActive(context: Context, watchdogId: String): WatchdogState? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val id = prefs.getString(keyId(watchdogId), null) ?: return null
        val title = prefs.getString(keyTitle(watchdogId), null) ?: return null
        val due = prefs.getLong(keyDueAt(watchdogId), 0L)
        if (due <= 0L) {
            return null
        }
        val ack = prefs.getBoolean(keyAck(watchdogId), false)
        val attempt = prefs.getInt(keyAttempt(watchdogId), 1)
        return WatchdogState(id, title, due, ack, attempt)
    }

    /// Every watchdog currently registered active, oldest first — same
    /// order [registerActive] evicts from.
    fun loadAllActive(context: Context): List<WatchdogState> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return loadActiveIds(prefs).mapNotNull { loadActive(context, it) }
    }

    fun clearActive(context: Context, watchdogId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = loadActiveIds(prefs).toMutableList()
        ids.remove(watchdogId)
        prefs.edit()
            .putStringSet(KEY_ACTIVE_IDS, ids.toSet())
            .remove(keyId(watchdogId))
            .remove(keyTitle(watchdogId))
            .remove(keyDueAt(watchdogId))
            .remove(keyAck(watchdogId))
            .remove(keyAttempt(watchdogId))
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
    /// Always queues (never writes protocol_violations directly): the
    /// SQLite row alone used to leave the matching task_assignments row
    /// stuck in accepted/delivered forever, because nothing else ever
    /// transitioned it — the already-scheduled "did you smoke?" prompt kept
    /// firing on schedule regardless, so the user saw a violation notice
    /// and a "did you complete it?" question for the same task. Routing
    /// through the queue means Dart's own drain
    /// (NotificationService.syncWatchdogViolationsFromNative) is the single
    /// place that both records the violation AND closes the task/cancels
    /// the stale prompt.
    fun triggerNoResponseViolation(context: Context, state: WatchdogState) {
        val texts = WatchdogStore.loadLocalizedText(context)
        createViolationChannelIfNeeded(context, texts.violationChannelName)

        val payload = "no_response_10_min|${state.taskTitle}|${System.currentTimeMillis()}"
        WatchdogStore.enqueueViolation(context, payload)

        val id = state.watchdogId.hashCode().let { if (it < 0) -it else it }
        val notification = NotificationCompat.Builder(context, NoResponseWatchdogService.VIOLATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(texts.violationTitle)
            .setContentText(texts.violationBody.replace("{taskTitle}", state.taskTitle))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(id, notification)
    }

    private fun createViolationChannelIfNeeded(context: Context, channelName: String) {
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
            channelName.ifBlank { "Nikotin Away Violation Alerts" },
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "10-minute unanswered task violation"
        }
        manager.createNotificationChannel(channel)
    }
}
