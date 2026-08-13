package com.nikotinaway.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class WatchdogTimeoutReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_TIMEOUT) {
            return
        }
        val watchdogId = intent.getStringExtra(NoResponseWatchdogService.EXTRA_WATCHDOG_ID).orEmpty()
        if (watchdogId.isBlank()) {
            return
        }

        val state = WatchdogStore.loadActive(context, watchdogId) ?: return
        if (state.acknowledged) {
            WatchdogStore.clearActive(context, watchdogId)
            return
        }
        if (System.currentTimeMillis() < state.dueAtMillis) {
            return
        }
        if (state.attemptCount >= WatchdogStore.MAX_ATTEMPTS) {
            WatchdogViolationNotifier.triggerNoResponseViolation(context, state)
            WatchdogStore.clearActive(context, watchdogId)
            return
        }
        // Not the final attempt yet — advance the counter, re-arm the backup
        // alarm for the next interval, and nudge the foreground service
        // awake in case it was killed while the app was backgrounded
        // (NoResponseWatchdogService.resumeIfActive re-reads the
        // already-updated state rather than resetting it, unlike
        // ACTION_START, which is for genuinely new watchdogs only).
        WatchdogStore.recordUnansweredAttempt(context, state)
        WatchdogAlarms.schedule(
            context,
            watchdogId,
            state.dueAtMillis + WatchdogStore.RETRY_INTERVAL_MILLIS,
        )
        NoResponseWatchdogService.resumeIfActive(context)
    }

    companion object {
        const val ACTION_TIMEOUT = "com.nikotinaway.app.watchdog.TIMEOUT"
    }
}
