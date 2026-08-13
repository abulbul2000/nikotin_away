package com.nikotinaway.app

import android.app.AppOpsManager
import android.app.NotificationManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.telecom.TelecomManager

/// Decides whether now is a reasonable moment to put a task in front of the
/// user.
///
/// Built mostly from signals that cost nothing and need no permission, plus
/// one optional signal (foreground app) the user can grant separately. An
/// `AccessibilityService` would answer "is the user in a fullscreen game" far
/// better than any of this, and is explicitly **not** used: Play's policy
/// limits that API to genuine accessibility purposes and using it for this
/// would put the whole app at risk.
///
/// Do Not Disturb and an in-progress call are exact — the user, or the OS,
/// has already said not to interrupt. The gaming/video guess and the known
/// foreground app list are not exact, and are treated accordingly: a wrong
/// guess only ever delays a task (capped, see TaskTriggerReceiver), never
/// drops it.
object DeliveryGateEvaluator {

    /// Why delivery was held back, matching TaskGateReason on the Dart side.
    const val REASON_DND = "dnd"
    const val REASON_CALL = "call"
    const val REASON_GAMING = "gaming"
    const val REASON_FOREGROUND_APP = "foreground_app"
    const val REASON_TRANSIT = "transit"
    const val REASON_NONE = ""

    /// Package names of well-known games, video and social apps. Not
    /// exhaustive — this only ever adds a delay, so a miss just falls back to
    /// [looksImmersed] or delivers on schedule, never drops the tip/task.
    private val distractingPackages = setOf(
        // Video
        "com.google.android.youtube",
        "com.netflix.mediaclient",
        "com.disney.disneyplus",
        "com.amazon.avod.thirdpartyclient",
        // Social / short video
        "com.instagram.android",
        "com.zhiliaoapp.musically", // TikTok
        "com.ss.android.ugc.trill", // TikTok (some regions)
        "com.facebook.katana",
        "com.twitter.android",
        "com.x.android",
        "com.snapchat.android",
        "com.whatsapp",
        "com.reddit.frontpage",
        // Games (a mix of consistently popular titles across regions)
        "com.supercell.clashofclans",
        "com.supercell.clashroyale",
        "com.king.candycrushsaga",
        "com.dts.freefireth",
        "com.tencent.ig", // PUBG Mobile
        "com.roblox.client",
        "com.mojang.minecraftpe",
        "com.miniclip.eightballpool",
        "com.ea.gp.fifamobile",
        "com.gameloft.android.ANMP.GloftA9HM",
    )

    /// Minimum uninterrupted screen-on time before the landscape+audio
    /// combination is read as "immersed in something".
    private const val IMMERSION_MIN_SCREEN_ON_MS = 10L * 60L * 1000L

    private const val PREFS = "no_smoke_delivery_gate"
    private const val KEY_SCREEN_ON_SINCE = "screen_on_since"

    /// Dart writes this short-lived signal after a fresh PhoneStateService
    /// context check. The timestamp prevents a stale transit result from
    /// blocking tasks indefinitely when the app stops updating context.
    private const val KEY_TRANSIT_LIKELY = "transit_likely"
    private const val KEY_TRANSIT_UPDATED_AT = "transit_updated_at"
    private const val MAX_TRANSIT_CONTEXT_AGE_MS = 15L * 60L * 1000L

    /// How far back to look for the last foreground-app switch. A few
    /// seconds is enough to catch "what's on screen right now" without
    /// querying a large event window every time the gate is checked.
    private const val FOREGROUND_LOOKBACK_MS = 10_000L

    fun blockingReason(context: Context): String {
        if (isDoNotDisturbActive(context)) {
            return REASON_DND
        }
        if (isInPhoneCall(context)) {
            return REASON_CALL
        }
        if (isTransitLikely(context)) {
            return REASON_TRANSIT
        }
        if (isDistractingAppInForeground(context)) {
            return REASON_FOREGROUND_APP
        }
        if (looksImmersed(context)) {
            return REASON_GAMING
        }
        return REASON_NONE
    }

    /// Stores a short-lived transit context received from the Dart sensor
    /// layer. This is intentionally separate from [blockingReason]: the
    /// receiver may run with no Flutter engine alive.
    fun noteTransitContext(context: Context, isLikely: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_TRANSIT_LIKELY, isLikely)
            .putLong(KEY_TRANSIT_UPDATED_AT, System.currentTimeMillis())
            .apply()
    }

    private fun isTransitLikely(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val updatedAt = prefs.getLong(KEY_TRANSIT_UPDATED_AT, 0L)
        if (updatedAt <= 0L ||
            System.currentTimeMillis() - updatedAt > MAX_TRANSIT_CONTEXT_AGE_MS
        ) {
            return false
        }
        return prefs.getBoolean(KEY_TRANSIT_LIKELY, false)
    }

    /// Same coarse in-call check MainActivity uses for the fake-call barrier —
    /// no permission beyond READ_PHONE_STATE, which the app already requests.
    /// Missing permission reads as "not in a call", matching that call site.
    private fun isInPhoneCall(context: Context): Boolean {
        if (context.checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return try {
            val telecomManager =
                context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
            telecomManager?.isInCall ?: false
        } catch (e: SecurityException) {
            false
        }
    }

    /// Whether the user has granted Usage Access — a Settings-only grant,
    /// same shape as the overlay permission (see hasUsageAccessPermission in
    /// MainActivity). Checked defensively here too since a revoked grant
    /// should degrade to the other signals, not crash the gate.
    private fun hasUsageAccessGranted(context: Context): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            false
        }
    }

    /// Whether a known game/video/social app is currently in the foreground.
    /// No-ops (returns false, never blocks) when Usage Access hasn't been
    /// granted — this signal is additive on top of [looksImmersed], not a
    /// replacement for it.
    private fun isDistractingAppInForeground(context: Context): Boolean {
        if (!hasUsageAccessGranted(context)) {
            return false
        }
        return try {
            val usageStatsManager =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val end = System.currentTimeMillis()
            val begin = end - FOREGROUND_LOOKBACK_MS
            val events = usageStatsManager.queryEvents(begin, end)
            var lastForegroundPackage: String? = null
            val event = android.app.usage.UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    lastForegroundPackage = event.packageName
                }
            }
            lastForegroundPackage != null && distractingPackages.contains(lastForegroundPackage)
        } catch (e: Exception) {
            false
        }
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
