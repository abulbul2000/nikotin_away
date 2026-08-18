package com.nikotinaway.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Re-arms every still-pending task alarm after a reboot or app update, both
/// of which wipe AlarmManager entirely. Without this, a plan set up the
/// evening before a phone reboots overnight (an OS update, say) delivers
/// nothing at all the next day until the user happens to open the app —
/// TaskTriggerReceiver is the product's core delivery mechanism, so losing
/// it silently is the most damaging instance of the gap this closes.
/// Mirrors SleepProbeBootReceiver/SmokedLogBootReceiver/StepProbeBootReceiver,
/// which already do this for their own alarms.
class TaskTriggerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val now = System.currentTimeMillis()
        for (snapshot in TaskTriggerStore.loadAll(context)) {
            if (snapshot.triggerAtMillis <= now) {
                // The task's moment already passed while the phone was off.
                // Firing it late (possibly hours late, well past what the
                // overdue-grace window on the Dart side tolerates) is worse
                // than not firing it — drop it the same way an
                // indefinitely-deferred task is dropped in
                // TaskTriggerReceiver.requeue.
                TaskTriggerStore.remove(context, snapshot.watchdogId)
                continue
            }
            TaskTriggerReceiver.rearm(context, snapshot)
        }
    }
}
