package com.example.no_smoke

import android.app.NotificationManager
import android.content.Context
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager

/// Decides whether now is a reasonable moment to put a task in front of the
/// user.
///
/// Deliberately built only from signals that cost nothing and need no
/// permission. An `AccessibilityService` would answer "is the user in a
/// fullscreen game" far better than any of this, and is explicitly **not**
/// used: Play's policy limits that API to genuine accessibility purposes and
/// using it for this would put the whole app at risk of removal.
///
/// What's left is one reliable signal and a heuristic. Do Not Disturb is
/// exact — the user has said, at the OS level, not to interrupt them. The
/// gaming/video guess is not exact, and is treated accordingly: a wrong guess
/// only ever delays a task (capped, see TaskTriggerReceiver), never drops it.
object DeliveryGateEvaluator {

    /// Why delivery was held back, matching TaskGateReason on the Dart side.
    const val REASON_DND = "dnd"
    const val REASON_GAMING = "gaming"
    const val REASON_NONE = ""

    /// Minimum uninterrupted screen-on time before the landscape+audio
    /// combination is read as "immersed in something".
    ///
    /// Without it, simply rotating the phone for a moment while music plays
    /// would postpone a task. Ten minutes is long enough that the user is
    /// genuinely in the middle of something.
    private const val IMMERSION_MIN_SCREEN_ON_MS = 10L * 60L * 1000L

    private const val PREFS = "no_smoke_delivery_gate"
    private const val KEY_SCREEN_ON_SINCE = "screen_on_since"

    fun blockingReason(context: Context): String {
        if (isDoNotDisturbActive(context)) {
            return REASON_DND
        }
        if (looksImmersed(context)) {
            return REASON_GAMING
        }
        return REASON_NONE
    }

    /// The user has told the OS not to interrupt them. Treated as absolute:
    /// this is an explicit instruction, not an inference.
    private fun isDoNotDisturbActive(context: Context): Boolean {
        return try {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
        } catch (e: Exception) {
            // Reading the filter needs no permission, but a manufacturer ROM
            // throwing here shouldn't stop a task from being delivered.
            false
        }
    }

    /// Landscape + audio playing + the screen on for a while: most likely a
    /// game or a full-screen video.
    ///
    /// All three are required because each alone is far too common — plenty
    /// of people read in landscape, and audio plays while a phone sits in a
    /// pocket.
    private fun looksImmersed(context: Context): Boolean {
        return try {
            val landscape = context.resources.configuration.orientation ==
                Configuration.ORIENTATION_LANDSCAPE
            if (!landscape) return false

            val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (!audio.isMusicActive) return false

            screenOnDurationMs(context) >= IMMERSION_MIN_SCREEN_ON_MS
        } catch (e: Exception) {
            false
        }
    }

    /// How long the screen has been continuously on.
    ///
    /// Tracked here rather than asked of the system because Android exposes
    /// no such counter. [noteScreenOn]/[noteScreenOff] keep it current from
    /// the quick-log overlay's screen receiver, which is already listening
    /// for those broadcasts.
    private fun screenOnDurationMs(context: Context): Long {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return 0

        val since = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_SCREEN_ON_SINCE, 0L)
        if (since <= 0L) {
            // Screen is on but we never saw it turn on — the app wasn't
            // running then. Can't claim immersion we haven't observed.
            return 0
        }
        return System.currentTimeMillis() - since
    }

    fun noteScreenOn(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_SCREEN_ON_SINCE, System.currentTimeMillis())
            .apply()
    }

    fun noteScreenOff(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_SCREEN_ON_SINCE, 0L)
            .apply()
    }

    /// Android 7+ everywhere this app runs, but keep the guard explicit.
    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
}
