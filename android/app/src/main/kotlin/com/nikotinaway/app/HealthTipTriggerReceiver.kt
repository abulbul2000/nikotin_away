package com.nikotinaway.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.provider.Settings

/// Fires at the moment a scheduled health tip, breath-test reminder or
/// weekly-survey reminder is due and, if the user has granted "display over
/// other apps", shows it as an overlay so it reaches them regardless of what
/// app is in the foreground — the same gap TaskTriggerReceiver closes for
/// mandatory tasks. Falls back to doing nothing when the overlay permission
/// isn't granted; the scheduled notification (already posted by the Dart
/// side) remains the user-facing prompt in that case.
///
/// [EXTRA_ROUTE] being present distinguishes a reminder (breath test, weekly
/// survey — something to act on, shown with Open/Postpone via
/// TaskOverlayService.showReminder) from a plain health tip (nothing to act
/// on, shown with a single dismiss via TaskOverlayService.showInfo). A
/// reminder that's postponed re-arms itself an hour out; a health tip that's
/// gated is simply dropped — it isn't owed to the user the way a reminder is.
///
/// Every trigger, reminder or tip, is gated by the same DeliveryGateEvaluator
/// signals (DND, in-call, a known game/video/social app in front, or the
/// immersion heuristic) that already gate mandatory tasks.
class HealthTipTriggerReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_TRIGGER) {
            return
        }
        if (!Settings.canDrawOverlays(context)) {
            return
        }
        if (DeliveryGateEvaluator.blockingReason(context) != DeliveryGateEvaluator.REASON_NONE) {
            return
        }
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
        if (body.isBlank()) {
            return
        }
        val route = intent.getStringExtra(EXTRA_ROUTE)
        if (route.isNullOrBlank()) {
            val dismissLabel = intent.getStringExtra(EXTRA_DISMISS_LABEL).orEmpty()
            TaskOverlayService.showInfo(context, title, body, dismissLabel)
            return
        }
        val reminderId = intent.getStringExtra(EXTRA_REMINDER_ID).orEmpty()
        val openLabel = intent.getStringExtra(EXTRA_OPEN_LABEL).orEmpty()
        val postponeLabel = intent.getStringExtra(EXTRA_POSTPONE_LABEL).orEmpty()
        TaskOverlayService.showReminder(
            context,
            title,
            body,
            openLabel,
            postponeLabel,
            route,
            reminderId,
        )
    }

    companion object {
        const val ACTION_TRIGGER = "com.nikotinaway.app.healthtip.TRIGGER"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_DISMISS_LABEL = "extra_dismiss_label"
        const val EXTRA_ROUTE = "extra_route"
        const val EXTRA_REMINDER_ID = "extra_reminder_id"
        const val EXTRA_OPEN_LABEL = "extra_open_label"
        const val EXTRA_POSTPONE_LABEL = "extra_postpone_label"

        private const val PREFS = "no_smoke_health_tip_trigger"
        private const val POSTPONE_DELAY_MS = 60L * 60L * 1000L

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        private fun pendingIntent(context: Context, slot: Int, extras: Intent.() -> Unit = {}): PendingIntent {
            val intent = Intent(context, HealthTipTriggerReceiver::class.java).apply {
                action = ACTION_TRIGGER
                extras()
            }
            return PendingIntent.getBroadcast(
                context,
                BASE_REQUEST_CODE + slot,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun arm(context: Context, slot: Int, pending: PendingIntent, triggerAtMillis: Long) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarmManager.canScheduleExactAlarms()
            if (canScheduleExact) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            } else {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
            }
        }

        /// A plain health tip — no route, shown with a single dismiss button.
        fun schedule(
            context: Context,
            slot: Int,
            title: String,
            body: String,
            dismissLabel: String,
            triggerAtMillis: Long,
        ) {
            val pending = pendingIntent(context, slot) {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_DISMISS_LABEL, dismissLabel)
            }
            arm(context, slot, pending, triggerAtMillis)
        }

        /// A reminder the user should act on (breath test, weekly survey) —
        /// shown with Open/Postpone. All the fields postpone needs to
        /// reschedule itself are cached under [reminderId] so
        /// [reschedule] can re-arm without Dart being involved.
        fun scheduleReminder(
            context: Context,
            slot: Int,
            reminderId: String,
            title: String,
            body: String,
            route: String,
            openLabel: String,
            postponeLabel: String,
            triggerAtMillis: Long,
        ) {
            prefs(context).edit()
                .putInt("$KEY_SLOT_PREFIX$reminderId", slot)
                .putString("$KEY_TITLE_PREFIX$reminderId", title)
                .putString("$KEY_BODY_PREFIX$reminderId", body)
                .putString("$KEY_ROUTE_PREFIX$reminderId", route)
                .putString("$KEY_OPEN_LABEL_PREFIX$reminderId", openLabel)
                .putString("$KEY_POSTPONE_LABEL_PREFIX$reminderId", postponeLabel)
                .apply()

            val pending = pendingIntent(context, slot) {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_ROUTE, route)
                putExtra(EXTRA_REMINDER_ID, reminderId)
                putExtra(EXTRA_OPEN_LABEL, openLabel)
                putExtra(EXTRA_POSTPONE_LABEL, postponeLabel)
            }
            arm(context, slot, pending, triggerAtMillis)
        }

        /// Re-arms [reminderId]'s alarm an hour from now, using the fields
        /// cached by [scheduleReminder]. A no-op if the cache is missing
        /// (e.g. the app's data was cleared between scheduling and postpone).
        fun reschedule(context: Context, reminderId: String) {
            val store = prefs(context)
            val slot = store.getInt("$KEY_SLOT_PREFIX$reminderId", -1)
            val title = store.getString("$KEY_TITLE_PREFIX$reminderId", null)
            val body = store.getString("$KEY_BODY_PREFIX$reminderId", null)
            val route = store.getString("$KEY_ROUTE_PREFIX$reminderId", null)
            val openLabel = store.getString("$KEY_OPEN_LABEL_PREFIX$reminderId", null)
            val postponeLabel = store.getString("$KEY_POSTPONE_LABEL_PREFIX$reminderId", null)
            if (slot < 0 || title == null || body == null || route == null ||
                openLabel == null || postponeLabel == null
            ) {
                return
            }
            scheduleReminder(
                context,
                slot,
                reminderId,
                title,
                body,
                route,
                openLabel,
                postponeLabel,
                System.currentTimeMillis() + POSTPONE_DELAY_MS,
            )
        }

        fun cancel(context: Context, slot: Int) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent(context, slot))
        }

        private const val BASE_REQUEST_CODE = 87001
        private const val KEY_SLOT_PREFIX = "slot_"
        private const val KEY_TITLE_PREFIX = "title_"
        private const val KEY_BODY_PREFIX = "body_"
        private const val KEY_ROUTE_PREFIX = "route_"
        private const val KEY_OPEN_LABEL_PREFIX = "open_label_"
        private const val KEY_POSTPONE_LABEL_PREFIX = "postpone_label_"
    }
}
