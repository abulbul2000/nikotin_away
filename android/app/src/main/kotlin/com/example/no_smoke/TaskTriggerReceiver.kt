package com.example.no_smoke

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings

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
            requeue(context, intent, deferredForMs, blockedBy)
            return
        }

        val watchdogWindowMillis =
            intent.getLongExtra(EXTRA_WATCHDOG_WINDOW_MILLIS, DEFAULT_WATCHDOG_WINDOW_MILLIS)
        NoResponseWatchdogService.start(
            context,
            taskTitle,
            watchdogId,
            System.currentTimeMillis() + watchdogWindowMillis,
        )

        // Best effort: without the "display over other apps" permission the
        // scheduled notification (with its full-screen intent) is still the
        // user-facing prompt, so a missing overlay degrades rather than
        // losing the task.
        if (canDrawOverlays(context)) {
            TaskOverlayService.show(
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

    private fun canDrawOverlays(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            Settings.canDrawOverlays(context)
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
