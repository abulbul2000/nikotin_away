package com.nikotinaway.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Re-arms the daily step probe after a reboot or app update, which both
/// kill any pending alarms.
class StepProbeBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }
        if (!StepProbeStore.isEnabled(context)) {
            return
        }
        StepProbeReceiver.scheduleNext(context)
    }
}
