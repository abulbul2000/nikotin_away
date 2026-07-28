package com.example.no_smoke

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Queues quick-log presses for Dart to pick up.
///
/// Writes to SharedPreferences rather than straight into the database on
/// purpose. The button runs with no Flutter engine alive, and the app's own
/// isolate may be running at the same moment; two writers on one SQLite file
/// is the kind of race that shows up as a corrupt row months later. Every
/// other native→Dart path here works the same way (WatchdogStore,
/// TaskOverlayOutcomeStore, SleepActivityStore) — Dart drains on next run and
/// remains the only writer.
object SmokedLogStore {
    private const val PREFS = "no_smoke_smoked_log"
    private const val KEY_PENDING = "pending_events"

    fun enqueue(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = prefs.getStringSet(KEY_PENDING, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        // Millisecond timestamps double as the entry's identity, so a set
        // can't silently collapse two presses into one.
        current.add(System.currentTimeMillis().toString())
        prefs.edit().putStringSet(KEY_PENDING, current).apply()
    }

    fun drain(context: Context): List<Long> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY_PENDING, emptySet())?.toList() ?: emptyList()
        prefs.edit().remove(KEY_PENDING).apply()
        return items.mapNotNull { it.toLongOrNull() }.sorted()
    }
}

/// The lock-screen half of the quick log.
///
/// An overlay cannot be drawn over the keyguard — that surface belongs to the
/// system — so the ongoing notification's action is the only way to reach the
/// button there. Notification actions are a single tap with no way to require
/// a hold, so the accidental-press guard moves to an undo window offered once
/// the app next runs.
class SmokedLogActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_LOG) return
        SmokedLogStore.enqueue(context)
    }

    companion object {
        const val ACTION_LOG = "com.example.no_smoke.smokedlog.LOG"
    }
}
