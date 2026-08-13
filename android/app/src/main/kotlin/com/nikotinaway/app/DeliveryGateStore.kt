package com.nikotinaway.app

import android.content.Context

/// Queues "a task was held back, and why" for Dart to pick up.
///
/// The gate runs in a broadcast receiver with no Flutter engine alive, so it
/// can't touch the database directly — same constraint, and same solution, as
/// every other native→Dart path here. Dart drains this on next run and writes
/// the deferral onto the task row, which is what makes gateDeferCount and
/// gateReason mean anything.
object DeliveryGateStore {
    private const val PREFS = "no_smoke_delivery_gate"
    private const val KEY_DEFERRALS = "pending_deferrals"

    fun noteDeferral(context: Context, reason: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = prefs.getStringSet(KEY_DEFERRALS, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        // Timestamped so two deferrals for the same reason can't collapse
        // into one set entry.
        current.add("$reason|${System.currentTimeMillis()}")
        prefs.edit().putStringSet(KEY_DEFERRALS, current).apply()
    }

    fun drain(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY_DEFERRALS, emptySet())?.toList() ?: emptyList()
        prefs.edit().remove(KEY_DEFERRALS).apply()
        return items
    }
}
