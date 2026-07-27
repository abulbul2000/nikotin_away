package com.example.no_smoke

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

// Draws the mandatory task prompt as a real system overlay (TYPE_APPLICATION_OVERLAY)
// so it appears over whatever app is in the foreground, not just on the lock screen the
// way a fullScreenIntent notification does. Only runs when the user has separately
// granted "display over other apps" (Settings.canDrawOverlays) -- there is no way to
// request that permission through a normal runtime dialog, only by sending the user to
// its dedicated Settings screen (see DevicePermissionService/MainActivity).
class TaskOverlayService : Service() {
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW -> {
                ensureForeground()
                val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
                val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
                val doneLabel = intent.getStringExtra(EXTRA_DONE_LABEL).orEmpty()
                val declineLabel = intent.getStringExtra(EXTRA_DECLINE_LABEL).orEmpty()
                val watchdogId = intent.getStringExtra(EXTRA_WATCHDOG_ID).orEmpty()
                val taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE).orEmpty()
                showOverlay(title, body, doneLabel, declineLabel, watchdogId, taskTitle)
            }
            ACTION_DISMISS -> {
                removeOverlay()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }

    private fun ensureForeground() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Nikotin Away Gorev Ekrani",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { description = "Zorunlu gorev ekrani gosterilirken aktif" },
            )
        }
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Nikotin Away")
            .setContentText("Gorev ekrani gosteriliyor")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    private fun showOverlay(
        title: String,
        body: String,
        doneLabel: String,
        declineLabel: String,
        watchdogId: String,
        taskTitle: String,
    ) {
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        removeOverlay()

        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#F20B1F2B"))
            setPadding(dp(32), dp(64), dp(32), dp(48))
            gravity = Gravity.CENTER
        }

        val titleView = TextView(this).apply {
            text = title
            setTextColor(Color.WHITE)
            textSize = 22f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(16))
        }
        val bodyView = TextView(this).apply {
            text = body
            setTextColor(Color.parseColor("#E0E0E0"))
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(40))
        }

        fun finish(outcome: String) {
            TaskOverlayOutcomeStore.enqueue(this@TaskOverlayService, watchdogId, taskTitle, outcome)
            NoResponseWatchdogService.acknowledge(this@TaskOverlayService, watchdogId)
            removeOverlay()
            stopSelf()
        }

        val doneButton = Button(this).apply {
            text = doneLabel
            setOnClickListener { finish("done") }
        }
        val declineButton = Button(this).apply {
            text = declineLabel
            setPadding(0, dp(12), 0, 0)
            setOnClickListener { finish("declined") }
        }

        container.addView(titleView)
        container.addView(bodyView)
        container.addView(doneButton)
        container.addView(declineButton)

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        )

        try {
            wm.addView(container, params)
            overlayView = container
        } catch (e: Exception) {
            stopSelf()
        }
    }

    private fun removeOverlay() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (e: Exception) {
            // Already detached.
        }
        overlayView = null
    }

    companion object {
        const val ACTION_SHOW = "com.example.no_smoke.overlay.SHOW"
        const val ACTION_DISMISS = "com.example.no_smoke.overlay.DISMISS"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_DONE_LABEL = "extra_done_label"
        const val EXTRA_DECLINE_LABEL = "extra_decline_label"
        const val EXTRA_WATCHDOG_ID = "extra_watchdog_id"
        const val EXTRA_TASK_TITLE = "extra_task_title"
        const val CHANNEL_ID = "task_overlay_foreground_channel"
        const val FOREGROUND_NOTIFICATION_ID = 73101

        fun show(
            context: Context,
            title: String,
            body: String,
            doneLabel: String,
            declineLabel: String,
            watchdogId: String,
            taskTitle: String,
        ) {
            val intent = Intent(context, TaskOverlayService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_DONE_LABEL, doneLabel)
                putExtra(EXTRA_DECLINE_LABEL, declineLabel)
                putExtra(EXTRA_WATCHDOG_ID, watchdogId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun dismiss(context: Context) {
            val intent = Intent(context, TaskOverlayService::class.java).apply {
                action = ACTION_DISMISS
            }
            context.startService(intent)
        }
    }
}

object TaskOverlayOutcomeStore {
    private const val PREFS = "no_smoke_task_overlay"
    private const val KEY_OUTCOMES = "queued_outcomes"

    fun enqueue(context: Context, watchdogId: String, taskTitle: String, outcome: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val current = prefs.getStringSet(KEY_OUTCOMES, emptySet())?.toMutableSet() ?: mutableSetOf()
        val safeTaskTitle = taskTitle.replace("|", " ")
        current.add("$watchdogId|$safeTaskTitle|$outcome|${System.currentTimeMillis()}")
        prefs.edit().putStringSet(KEY_OUTCOMES, current).apply()
    }

    fun drain(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val items = prefs.getStringSet(KEY_OUTCOMES, emptySet())?.toList() ?: emptyList()
        prefs.edit().remove(KEY_OUTCOMES).apply()
        return items
    }
}
