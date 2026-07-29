package com.example.no_smoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

/// Brings the floating quick-log button back after a reboot or an app update.
///
/// Android does not restart an overlay service on its own, and the Dart side
/// can only re-arm it once someone opens the app — so without this the button
/// silently disappeared until the next launch while the switch in settings
/// still read "on". The button is the app's only record of when the user
/// actually smokes, so the days it is missing are days the barrier and the
/// risky-hour ranking are aimed at nothing.
class SmokedLogBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val prefs = context.getSharedPreferences(
            SmokedLogOverlayService.PREFS,
            Context.MODE_PRIVATE,
        )
        if (!prefs.getBoolean(SmokedLogOverlayService.KEY_ENABLED, false)) {
            return
        }

        // The permission can be withdrawn while the phone is off. Starting a
        // foreground service that immediately fails to add its window would
        // leave a notification for a button nobody can see.
        if (!canDrawOverlays(context)) {
            return
        }

        runCatching { SmokedLogOverlayService.start(context) }
    }

    private fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
}
