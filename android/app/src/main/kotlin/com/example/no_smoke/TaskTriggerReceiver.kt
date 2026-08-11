package com.example.no_smoke

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
        val blockedBy = DeliveryGateEvaluator.blockingReason(context)
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

        // The native full-screen overlay (phone-call-style Ertele/Kabul Et)
        // is intentionally not shown here anymore — the scheduled
        // notification's full-screen intent already surfaces
        // MandatoryTaskPage in Dart, and showing both stacked two
        // differently-styled task prompts on top of each other.
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

        DeliveryGateStore.noteDeferral(context, reason)

        val extras = Bundle(original.extras ?: Bundle()).apply {
            putLong(EXTRA_DEFERRED_FOR_MILLIS, alreadyDeferredMs + waitMs)
        }
        val intent = Intent(context, TaskTriggerReceiver::class.java).apply {
            action = ACTION_TRIGGER
            putExtras(extras)
        }
        val watchdogId = original.getStringExtra(EXTRA_WATCHDOG_ID).orEmpty()
        val pending = PendingIntent.getBroadcast(
            context,
            watchdogId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + waitMs,
            pending,
        )
    }

    companion object {
        const val ACTION_TRIGGER = "com.example.no_smoke.task.TRIGGER"
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
        }

        fun cancel(context: Context, watchdogId: String) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent(context, watchdogId))
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
