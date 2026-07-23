package com.example.no_smoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Re-arms nightly sleep probing after a reboot (or app update, which also
/// kills any pending alarms). Mirrors flutter_local_notifications' own boot
/// receiver, which only re-arms its own notifications, not this feature.
class SleepProbeBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val schedule = SleepProbeStore.readSchedule(context) ?: return
        val (windowStartMinute, windowEndMinute, intervalMinutes) = schedule
        SleepProbeReceiver.scheduleWindowAware(context, windowStartMinute, windowEndMinute, intervalMinutes)
    }
}
