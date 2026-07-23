package com.example.no_smoke

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/// Handles Play Services geofence transition broadcasts. Fires even when the
/// Flutter engine/Dart isolate isn't running — same "native writes straight
/// to SQLite" posture as NoResponseWatchdogService and SleepProbeReceiver,
/// so no background isolate/headless Dart callback plumbing is needed. Only
/// ever persists {placeId, transitionType, timestamp} — never a raw
/// coordinate — the significant place's actual lat/lng lives solely in the
/// small (<=8 row) place table the Dart side manages and Play Services'
/// own geofence registration, not in this event log.
class GeofenceTransitionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val geofencingEvent = GeofencingEvent.fromIntent(intent) ?: return
        if (geofencingEvent.hasError()) {
            return
        }

        val transitionType = geofencingEvent.geofenceTransition
        val triggeringGeofences = geofencingEvent.triggeringGeofences ?: return
        if (transitionType != Geofence.GEOFENCE_TRANSITION_ENTER &&
            transitionType != Geofence.GEOFENCE_TRANSITION_EXIT
        ) {
            return
        }

        val transitionLabel = if (transitionType == Geofence.GEOFENCE_TRANSITION_ENTER) "enter" else "exit"
        for (geofence in triggeringGeofences) {
            GeofenceStore.insertVisitEvent(context, placeId = geofence.requestId, transitionType = transitionLabel)
        }

        if (transitionType == Geofence.GEOFENCE_TRANSITION_ENTER) {
            showArrivalNotification(context)
        }
    }

    private fun showArrivalNotification(context: Context) {
        createChannelIfNeeded(context)
        val title = GeofenceStore.readNotificationTitle(context) ?: return
        val body = GeofenceStore.readNotificationBody(context) ?: ""

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    private fun createChannelIfNeeded(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "No Smoke Konum Hatirlatici",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Sik gidilen bir yere varildiginda gosterilen hatirlatma"
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "geofence_arrival_channel"
        private const val NOTIFICATION_ID = 85001
    }
}

/// SharedPreferences (for the notification text, refreshed by Dart whenever
/// the place list or language changes) + a small direct-SQLite event log —
/// mirrors WatchdogStore/SleepProbeStore's existing pattern.
object GeofenceStore {
    private const val PREFS = "no_smoke_geofencing"
    private const val KEY_TITLE = "notification_title"
    private const val KEY_BODY = "notification_body"
    private const val TABLE = "location_visit_events"
    private const val RETENTION_DAYS = 60

    fun saveNotificationText(context: Context, title: String, body: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TITLE, title)
            .putString(KEY_BODY, body)
            .apply()
    }

    fun readNotificationTitle(context: Context): String? {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_TITLE, null)
    }

    fun readNotificationBody(context: Context): String? {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_BODY, null)
    }

    fun insertVisitEvent(context: Context, placeId: String, transitionType: String) {
        val dbFile = File(File(context.applicationInfo.dataDir, "app_flutter"), "no_smoke.db")
        if (!dbFile.exists()) {
            return
        }
        try {
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                val now = System.currentTimeMillis()
                val values = ContentValues().apply {
                    put("id", "visit_${now}_$placeId")
                    put("placeId", placeId)
                    put("transitionType", transitionType)
                    put("createdAt", formatIsoUtc(now))
                }
                db.insert(TABLE, null, values)

                val cutoff = now - RETENTION_DAYS * 24 * 60 * 60 * 1000L
                db.delete(TABLE, "createdAt < ?", arrayOf(formatIsoUtc(cutoff)))
            }
        } catch (_: Throwable) {
            // Best-effort, same posture as the other native writers.
        }
    }

    private fun formatIsoUtc(millis: Long): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        formatter.timeZone = TimeZone.getTimeZone("UTC")
        return formatter.format(millis)
    }
}
