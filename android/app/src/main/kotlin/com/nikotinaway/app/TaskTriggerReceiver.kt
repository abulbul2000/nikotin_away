package com.nikotinaway.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle

/// Fires at the moment a planned task is actually due.
///
/// The scheduled notification alone was never enough: `TaskOverlayService`
/// has to be started from code running at fire time, and when the app is
/// closed there is no Dart running then to start it. Scheduling this
/// receiver alongside the notification gives the overlay (and the watchdog)
/// a native wake-up that works with the app dead and the phone in Doze.
///
/// This is also what makes per-task watchdogs correct: the watchdog is
/// started here, when the task fires, rather than at schedule time — so its
/// timeout window is the 15 minutes after the user was actually asked, and
/// two tasks scheduled hours apart no longer overwrite each other's state.
class TaskTriggerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_TRIGGER) {
            return
        }
        val taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE).orEmpty()
        val watchdogId = intent.getStringExtra(EXTRA_WATCHDOG_ID).orEmpty()
        if (taskTitle.isBlank() || watchdogId.isBlank()) {
            return
        }

        // Is now a sensible moment to interrupt? If not the task is pushed
        // back rather than dropped — see requeue below.
        val deferredForMs = intent.getLongExtra(EXTRA_DEFERRED_FOR_MILLIS, 0L)
        val blockedBy = DeliveryGateEvaluator.taskBlockingReason(context)
        if (blockedBy != DeliveryGateEvaluator.REASON_NONE &&
            deferredForMs < MAX_TOTAL_DEFERRAL_MS
        ) {
            // A queue limit alongside the existing per-task 90-minute cap:
            // without it, every task whose moment falls during one long DND/
            // gaming stretch waits independently, and a user re-opening the
            // app hours later gets hit with all of them stacked at once —
            // the exact overlap this queue exists to prevent. Only the two
            // most recently blocked survive; anything older is closed out
            // as expired (never scored) rather than left to also queue.
            val evicted = PendingDeliveryQueue.registerBlocked(context, watchdogId)
            for (evictedWatchdogId in evicted) {
                cancel(context, evictedWatchdogId)
                PendingDeliveryQueue.enqueueExpired(context, evictedWatchdogId)
            }
            requeue(context, intent, deferredForMs, blockedBy)
            return
        }
        PendingDeliveryQueue.clearBlocked(context, watchdogId)
        // This one-shot alarm has now done its job — nothing left to re-arm
        // on a future reboot for this watchdogId.
        TaskTriggerStore.remove(context, watchdogId)

        val watchdogWindowMillis =
            intent.getLongExtra(EXTRA_WATCHDOG_WINDOW_MILLIS, DEFAULT_WATCHDOG_WINDOW_MILLIS)
        NoResponseWatchdogService.start(
            context = context,
            taskTitle = taskTitle,
            watchdogId = watchdogId,
            dueAtMillis = System.currentTimeMillis() + watchdogWindowMillis,
            foregroundBody = intent.getStringExtra(EXTRA_WATCHDOG_FOREGROUND_BODY).orEmpty(),
            violationTitle = intent.getStringExtra(EXTRA_WATCHDOG_VIOLATION_TITLE).orEmpty(),
            violationBody = intent.getStringExtra(EXTRA_WATCHDOG_VIOLATION_BODY).orEmpty(),
            foregroundChannelName = intent.getStringExtra(EXTRA_WATCHDOG_FOREGROUND_CHANNEL_NAME).orEmpty(),
            violationChannelName = intent.getStringExtra(EXTRA_WATCHDOG_VIOLATION_CHANNEL_NAME).orEmpty(),
        )

        // Deliver the task outside the app as soon as it is due. The native
        // overlay is only gated by the phone-call check above; video, games,
        // social apps and the home screen do not defer it. The notification
        // remains as the system fallback when overlay permission is unavailable.
        if (android.provider.Settings.canDrawOverlays(context)) {
            TaskOverlayService.showTask(
                context = context,
                title = intent.getStringExtra(EXTRA_TITLE).orEmpty(),
                body = intent.getStringExtra(EXTRA_BODY).orEmpty(),
                acceptLabel = intent.getStringExtra(EXTRA_DONE_LABEL).orEmpty(),
                postponeLabel = intent.getStringExtra(EXTRA_POSTPONE_LABEL).orEmpty(),
                declineLabel = intent.getStringExtra(EXTRA_DECLINE_LABEL).orEmpty(),
                sosLabel = intent.getStringExtra(EXTRA_SOS_LABEL).orEmpty(),
                watchdogId = watchdogId,
                taskTitle = taskTitle,
            )
        }
    }

    /// Pushes the task back and remembers how long it has been waiting.
    ///
    /// Re-arms the same alarm with the same extras, so nothing about the task
    /// is lost — only its timing moves. Once the accumulated deferral passes
    /// [MAX_TOTAL_DEFERRAL_MS] the gate is ignored and the task is delivered
    /// anyway: a user who games all evening should still hear from the app
    /// that evening, and an indefinitely-deferred task is the same as no task.
    private fun requeue(
        context: Context,
        original: Intent,
        alreadyDeferredMs: Long,
        reason: String,
    ) {
        // Small jitter so a blocked task doesn't come back on a clock the
        // user could set their watch by.
        val jitterMs = ((Math.random() * 2 - 1) * RETRY_JITTER_MS).toLong()
        val waitMs = (RETRY_INTERVAL_MS + jitterMs).coerceAtLeast(60_000L)
        val watchdogId = original.getStringExtra(EXTRA_WATCHDOG_ID).orEmpty()

        DeliveryGateStore.noteDeferral(context, watchdogId, reason)

        val extras = Bundle(original.extras ?: Bundle()).apply {
            putLong(EXTRA_DEFERRED_FOR_MILLIS, alreadyDeferredMs + waitMs)
        }
        val intent = Intent(context, TaskTriggerReceiver::class.java).apply {
            action = ACTION_TRIGGER
            putExtras(extras)
        }
        val pending = PendingIntent.getBroadcast(
            context,
            watchdogId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val newTriggerAtMillis = System.currentTimeMillis() + waitMs
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            newTriggerAtMillis,
            pending,
        )
        // Keep the boot-recovery snapshot's triggerAtMillis current — a
        // reboot mid-requeue should resume waiting for the new time, not
        // fire immediately against the original (already-past) one.
        TaskTriggerStore.updateTriggerAtMillis(context, watchdogId, newTriggerAtMillis)
    }

    companion object {
        const val ACTION_TRIGGER = "com.nikotinaway.app.task.TRIGGER"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_DONE_LABEL = "extra_done_label"
        const val EXTRA_POSTPONE_LABEL = "extra_postpone_label"
        const val EXTRA_DECLINE_LABEL = "extra_decline_label"
        const val EXTRA_SOS_LABEL = "extra_sos_label"
        const val EXTRA_WATCHDOG_ID = "extra_watchdog_id"
        const val EXTRA_TASK_TITLE = "extra_task_title"
        const val EXTRA_WATCHDOG_WINDOW_MILLIS = "extra_watchdog_window_millis"
        const val EXTRA_DEFERRED_FOR_MILLIS = "extra_deferred_for_millis"
        const val EXTRA_WATCHDOG_FOREGROUND_BODY = "extra_watchdog_foreground_body"
        const val EXTRA_WATCHDOG_VIOLATION_TITLE = "extra_watchdog_violation_title"
        const val EXTRA_WATCHDOG_VIOLATION_BODY = "extra_watchdog_violation_body"
        const val EXTRA_WATCHDOG_FOREGROUND_CHANNEL_NAME = "extra_watchdog_foreground_channel_name"
        const val EXTRA_WATCHDOG_VIOLATION_CHANNEL_NAME = "extra_watchdog_violation_channel_name"

        /// How long to wait before trying a blocked task again, and how much
        /// random slack to add so the retry isn't on a predictable clock.
        private const val RETRY_INTERVAL_MS = 10L * 60L * 1000L
        private const val RETRY_JITTER_MS = 3L * 60L * 1000L

        /// Past this the gate is ignored and the task goes out regardless.
        /// A task deferred forever is the same as no task at all.
        private const val MAX_TOTAL_DEFERRAL_MS = 90L * 60L * 1000L

        /// 3 retry attempts, 5 minutes apart — kept in sync with
        /// NotificationService's _unansweredReminderDelay * _maxTaskAttempts.
        const val DEFAULT_WATCHDOG_WINDOW_MILLIS = 15L * 60L * 1000L

        private fun pendingIntent(
            context: Context,
            watchdogId: String,
            extras: Intent.() -> Unit = {},
        ): PendingIntent {
            val intent = Intent(context, TaskTriggerReceiver::class.java).apply {
                action = ACTION_TRIGGER
                extras()
            }
            return PendingIntent.getBroadcast(
                context,
                watchdogId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun schedule(
            context: Context,
            title: String,
            body: String,
            acceptLabel: String,
            postponeLabel: String,
            declineLabel: String,
            sosLabel: String,
            watchdogId: String,
            taskTitle: String,
            triggerAtMillis: Long,
            watchdogWindowMillis: Long,
            watchdogForegroundBody: String,
            watchdogViolationTitle: String,
            watchdogViolationBody: String,
            watchdogForegroundChannelName: String,
            watchdogViolationChannelName: String,
        ) {
            val pending = pendingIntent(context, watchdogId) {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_DONE_LABEL, acceptLabel)
                putExtra(EXTRA_POSTPONE_LABEL, postponeLabel)
                putExtra(EXTRA_DECLINE_LABEL, declineLabel)
                putExtra(EXTRA_SOS_LABEL, sosLabel)
                putExtra(EXTRA_WATCHDOG_ID, watchdogId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_WATCHDOG_WINDOW_MILLIS, watchdogWindowMillis)
                putExtra(EXTRA_WATCHDOG_FOREGROUND_BODY, watchdogForegroundBody)
                putExtra(EXTRA_WATCHDOG_VIOLATION_TITLE, watchdogViolationTitle)
                putExtra(EXTRA_WATCHDOG_VIOLATION_BODY, watchdogViolationBody)
                putExtra(EXTRA_WATCHDOG_FOREGROUND_CHANNEL_NAME, watchdogForegroundChannelName)
                putExtra(EXTRA_WATCHDOG_VIOLATION_CHANNEL_NAME, watchdogViolationChannelName)
            }
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // Android 12+ can revoke exact-alarm scheduling. An inexact
            // wake-up still fires (just with OS-chosen slack), which is far
            // better than dropping the task entirely.
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

            // Reboot wipes every AlarmManager entry (see
            // TaskTriggerBootReceiver), so the full set of extras this alarm
            // needs to re-arm itself is cached here too, keyed by watchdogId.
            TaskTriggerStore.save(
                context,
                watchdogId,
                TaskTriggerSnapshot(
                    title = title,
                    body = body,
                    acceptLabel = acceptLabel,
                    postponeLabel = postponeLabel,
                    declineLabel = declineLabel,
                    sosLabel = sosLabel,
                    watchdogId = watchdogId,
                    taskTitle = taskTitle,
                    triggerAtMillis = triggerAtMillis,
                    watchdogWindowMillis = watchdogWindowMillis,
                    watchdogForegroundBody = watchdogForegroundBody,
                    watchdogViolationTitle = watchdogViolationTitle,
                    watchdogViolationBody = watchdogViolationBody,
                    watchdogForegroundChannelName = watchdogForegroundChannelName,
                    watchdogViolationChannelName = watchdogViolationChannelName,
                ),
            )
        }

        fun cancel(context: Context, watchdogId: String) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent(context, watchdogId))
            TaskTriggerStore.remove(context, watchdogId)
        }

        /// Re-arms [snapshot]'s alarm without touching the persisted cache —
        /// used by [TaskTriggerBootReceiver], which is re-arming from that
        /// same cache and would otherwise just rewrite what it already read.
        fun rearm(context: Context, snapshot: TaskTriggerSnapshot) {
            val pending = pendingIntent(context, snapshot.watchdogId) {
                putExtra(EXTRA_TITLE, snapshot.title)
                putExtra(EXTRA_BODY, snapshot.body)
                putExtra(EXTRA_DONE_LABEL, snapshot.acceptLabel)
                putExtra(EXTRA_POSTPONE_LABEL, snapshot.postponeLabel)
                putExtra(EXTRA_DECLINE_LABEL, snapshot.declineLabel)
                putExtra(EXTRA_SOS_LABEL, snapshot.sosLabel)
                putExtra(EXTRA_WATCHDOG_ID, snapshot.watchdogId)
                putExtra(EXTRA_TASK_TITLE, snapshot.taskTitle)
                putExtra(EXTRA_WATCHDOG_WINDOW_MILLIS, snapshot.watchdogWindowMillis)
                putExtra(EXTRA_WATCHDOG_FOREGROUND_BODY, snapshot.watchdogForegroundBody)
                putExtra(EXTRA_WATCHDOG_VIOLATION_TITLE, snapshot.watchdogViolationTitle)
                putExtra(EXTRA_WATCHDOG_VIOLATION_BODY, snapshot.watchdogViolationBody)
                putExtra(
                    EXTRA_WATCHDOG_FOREGROUND_CHANNEL_NAME,
                    snapshot.watchdogForegroundChannelName,
                )
                putExtra(
                    EXTRA_WATCHDOG_VIOLATION_CHANNEL_NAME,
                    snapshot.watchdogViolationChannelName,
                )
            }
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarmManager.canScheduleExactAlarms()
            if (canScheduleExact) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    snapshot.triggerAtMillis,
                    pending,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    snapshot.triggerAtMillis,
                    pending,
                )
            }
        }
    }
}

/// Tracks tasks currently stuck waiting on [DeliveryGateEvaluator] (DND,
/// gaming, a call) — the "not yet delivered" half of the two-task queue
/// limit. The other half (already-delivered, awaiting an answer) is
/// [WatchdogStore]'s own [WatchdogStore.MAX_ACTIVE_WATCHDOGS] limit; this
/// object exists because a task can spend its entire life in this state
/// without [NoResponseWatchdogService] ever seeing it, so that store alone
/// can't catch a backlog of blocked-but-undelivered tasks.
object PendingDeliveryQueue {
    private const val PREFS = "no_smoke_pending_delivery_queue"
    private const val KEY_BLOCKED_IDS = "blocked_watchdog_ids"
    private const val KEY_EXPIRED = "queued_expired"

    /// Same limit as [WatchdogStore.MAX_ACTIVE_WATCHDOGS] — one shared
    /// budget across "blocked" and "delivered, awaiting answer" would need
    /// the two objects to coordinate on every write, which is more coupling
    /// than the two-task rule is worth; a task only ever occupies one of the
    /// two queues at a time; in practice a blocked task also being an active
    /// watchdog never happens; keeping the constant duplicated locally is
    /// simpler than exporting it.
    private const val MAX_BLOCKED = 2

    /// Registers [watchdogId] as currently blocked, evicting the
    /// oldest-registered blocked watchdogId(s) if this pushes the count past
    /// [MAX_BLOCKED]. Returns everything evicted — the caller cancels each
    /// one's alarm and reports it to Dart as expired.
    fun registerBlocked(context: Context, watchdogId: String): List<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = (prefs.getStringSet(KEY_BLOCKED_IDS, emptySet())?.toList() ?: emptyList())
            .toMutableList()
        ids.remove(watchdogId)
        ids.add(watchdogId)
        val evicted = mutableListOf<String>()
        while (ids.size > MAX_BLOCKED) {
            evicted.add(ids.removeAt(0))
        }
        prefs.edit().putStringSet(KEY_BLOCKED_IDS, ids.toSet()).apply()
        return evicted
    }

    /// A task that made it past the gate (delivered, or answered before that
    /// could happen) is no longer "blocked" — remove it so it can't later be
    /// counted as a stale entry against the queue limit.
    fun clearBlocked(context: Context, watchdogId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val ids = (prefs.getStringSet(KEY_BLOCKED_IDS, emptySet())?.toList() ?: emptyList())
            .toMutableList()
        if (ids.remove(watchdogId)) {
            prefs.edit().putStringSet(KEY_BLOCKED_IDS, ids.toSet()).apply()
        }
    }

    /// Queues [watchdogId] for Dart to transition to `expired` on next
    /// drain — same SharedPreferences-queue-then-drain shape as
    /// [WatchdogStore.enqueueViolation]/[WatchdogStore.drainViolations],
    /// since this receiver has no Flutter engine to call back into directly.
    fun enqueueExpired(context: Context, watchdogId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = prefs.getStringSet(KEY_EXPIRED, emptySet())?.toMutableSet() ?: mutableSetOf()
        current.add("$watchdogId|${System.currentTimeMillis()}")
        prefs.edit().putStringSet(KEY_EXPIRED, current).apply()
    }

    fun drainExpired(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY_EXPIRED, emptySet())?.toList() ?: emptyList()
        prefs.edit().remove(KEY_EXPIRED).apply()
        return items
    }
}

/// Everything [TaskTriggerReceiver.rearm] needs to re-arm one alarm —
/// exactly the same fields [TaskTriggerReceiver.schedule] puts on the
/// PendingIntent's extras, cached alongside it so a reboot (which wipes
/// AlarmManager entirely) can rebuild the alarm without Dart's involvement.
data class TaskTriggerSnapshot(
    val title: String,
    val body: String,
    val acceptLabel: String,
    val postponeLabel: String,
    val declineLabel: String,
    val sosLabel: String,
    val watchdogId: String,
    val taskTitle: String,
    val triggerAtMillis: Long,
    val watchdogWindowMillis: Long,
    val watchdogForegroundBody: String,
    val watchdogViolationTitle: String,
    val watchdogViolationBody: String,
    val watchdogForegroundChannelName: String,
    val watchdogViolationChannelName: String,
)

/// Persists one [TaskTriggerSnapshot] per live watchdogId so
/// [TaskTriggerBootReceiver] can re-arm every still-pending task alarm after
/// a reboot or app update — see the class doc on [TaskTriggerReceiver] for
/// why the alarm alone isn't enough. Entries are removed once their alarm
/// either fires ([TaskTriggerReceiver.onReceive]) or is explicitly cancelled
/// ([TaskTriggerReceiver.cancel]), so this only ever holds tasks still
/// waiting to be delivered.
object TaskTriggerStore {
    private const val PREFS = "no_smoke_task_trigger_store"
    private const val KEY_IDS = "watchdog_ids"
    private const val F_TITLE = "title_"
    private const val F_BODY = "body_"
    private const val F_ACCEPT_LABEL = "accept_label_"
    private const val F_POSTPONE_LABEL = "postpone_label_"
    private const val F_DECLINE_LABEL = "decline_label_"
    private const val F_SOS_LABEL = "sos_label_"
    private const val F_TASK_TITLE = "task_title_"
    private const val F_TRIGGER_AT = "trigger_at_"
    private const val F_WATCHDOG_WINDOW = "watchdog_window_"
    private const val F_WATCHDOG_FG_BODY = "watchdog_fg_body_"
    private const val F_WATCHDOG_VIOLATION_TITLE = "watchdog_violation_title_"
    private const val F_WATCHDOG_VIOLATION_BODY = "watchdog_violation_body_"
    private const val F_WATCHDOG_FG_CHANNEL = "watchdog_fg_channel_"
    private const val F_WATCHDOG_VIOLATION_CHANNEL = "watchdog_violation_channel_"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(context: Context, watchdogId: String, snapshot: TaskTriggerSnapshot) {
        val store = prefs(context)
        val ids = (store.getStringSet(KEY_IDS, emptySet()) ?: emptySet()).toMutableSet()
        ids.add(watchdogId)
        store.edit()
            .putStringSet(KEY_IDS, ids)
            .putString("$F_TITLE$watchdogId", snapshot.title)
            .putString("$F_BODY$watchdogId", snapshot.body)
            .putString("$F_ACCEPT_LABEL$watchdogId", snapshot.acceptLabel)
            .putString("$F_POSTPONE_LABEL$watchdogId", snapshot.postponeLabel)
            .putString("$F_DECLINE_LABEL$watchdogId", snapshot.declineLabel)
            .putString("$F_SOS_LABEL$watchdogId", snapshot.sosLabel)
            .putString("$F_TASK_TITLE$watchdogId", snapshot.taskTitle)
            .putLong("$F_TRIGGER_AT$watchdogId", snapshot.triggerAtMillis)
            .putLong("$F_WATCHDOG_WINDOW$watchdogId", snapshot.watchdogWindowMillis)
            .putString("$F_WATCHDOG_FG_BODY$watchdogId", snapshot.watchdogForegroundBody)
            .putString("$F_WATCHDOG_VIOLATION_TITLE$watchdogId", snapshot.watchdogViolationTitle)
            .putString("$F_WATCHDOG_VIOLATION_BODY$watchdogId", snapshot.watchdogViolationBody)
            .putString("$F_WATCHDOG_FG_CHANNEL$watchdogId", snapshot.watchdogForegroundChannelName)
            .putString(
                "$F_WATCHDOG_VIOLATION_CHANNEL$watchdogId",
                snapshot.watchdogViolationChannelName,
            )
            .apply()
    }

    /// Rewrites just the cached firing time — used when [TaskTriggerReceiver]
    /// requeues a delivery-gate-blocked task, so a reboot mid-wait resumes
    /// waiting for the new time instead of firing immediately against the
    /// stale original one. A no-op if [watchdogId] isn't cached (e.g. it was
    /// already cancelled elsewhere in the same instant).
    fun updateTriggerAtMillis(context: Context, watchdogId: String, triggerAtMillis: Long) {
        val store = prefs(context)
        val ids = store.getStringSet(KEY_IDS, emptySet()) ?: emptySet()
        if (watchdogId !in ids) return
        store.edit().putLong("$F_TRIGGER_AT$watchdogId", triggerAtMillis).apply()
    }

    fun remove(context: Context, watchdogId: String) {
        val store = prefs(context)
        val ids = (store.getStringSet(KEY_IDS, emptySet()) ?: emptySet()).toMutableSet()
        if (!ids.remove(watchdogId)) return
        store.edit()
            .putStringSet(KEY_IDS, ids)
            .remove("$F_TITLE$watchdogId")
            .remove("$F_BODY$watchdogId")
            .remove("$F_ACCEPT_LABEL$watchdogId")
            .remove("$F_POSTPONE_LABEL$watchdogId")
            .remove("$F_DECLINE_LABEL$watchdogId")
            .remove("$F_SOS_LABEL$watchdogId")
            .remove("$F_TASK_TITLE$watchdogId")
            .remove("$F_TRIGGER_AT$watchdogId")
            .remove("$F_WATCHDOG_WINDOW$watchdogId")
            .remove("$F_WATCHDOG_FG_BODY$watchdogId")
            .remove("$F_WATCHDOG_VIOLATION_TITLE$watchdogId")
            .remove("$F_WATCHDOG_VIOLATION_BODY$watchdogId")
            .remove("$F_WATCHDOG_FG_CHANNEL$watchdogId")
            .remove("$F_WATCHDOG_VIOLATION_CHANNEL$watchdogId")
            .apply()
    }

    /// All still-pending snapshots — [TaskTriggerBootReceiver] re-arms each.
    fun loadAll(context: Context): List<TaskTriggerSnapshot> {
        val store = prefs(context)
        val ids = store.getStringSet(KEY_IDS, emptySet()) ?: emptySet()
        return ids.mapNotNull { watchdogId ->
            val title = store.getString("$F_TITLE$watchdogId", null) ?: return@mapNotNull null
            val body = store.getString("$F_BODY$watchdogId", null) ?: return@mapNotNull null
            val taskTitle =
                store.getString("$F_TASK_TITLE$watchdogId", null) ?: return@mapNotNull null
            val triggerAtMillis = store.getLong("$F_TRIGGER_AT$watchdogId", -1L)
            if (triggerAtMillis < 0) return@mapNotNull null
            TaskTriggerSnapshot(
                title = title,
                body = body,
                acceptLabel = store.getString("$F_ACCEPT_LABEL$watchdogId", "").orEmpty(),
                postponeLabel = store.getString("$F_POSTPONE_LABEL$watchdogId", "").orEmpty(),
                declineLabel = store.getString("$F_DECLINE_LABEL$watchdogId", "").orEmpty(),
                sosLabel = store.getString("$F_SOS_LABEL$watchdogId", "").orEmpty(),
                watchdogId = watchdogId,
                taskTitle = taskTitle,
                triggerAtMillis = triggerAtMillis,
                watchdogWindowMillis = store.getLong(
                    "$F_WATCHDOG_WINDOW$watchdogId",
                    TaskTriggerReceiver.DEFAULT_WATCHDOG_WINDOW_MILLIS,
                ),
                watchdogForegroundBody =
                    store.getString("$F_WATCHDOG_FG_BODY$watchdogId", "").orEmpty(),
                watchdogViolationTitle =
                    store.getString("$F_WATCHDOG_VIOLATION_TITLE$watchdogId", "").orEmpty(),
                watchdogViolationBody =
                    store.getString("$F_WATCHDOG_VIOLATION_BODY$watchdogId", "").orEmpty(),
                watchdogForegroundChannelName =
                    store.getString("$F_WATCHDOG_FG_CHANNEL$watchdogId", "").orEmpty(),
                watchdogViolationChannelName =
                    store.getString("$F_WATCHDOG_VIOLATION_CHANNEL$watchdogId", "").orEmpty(),
            )
        }
    }
}
