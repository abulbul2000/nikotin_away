package com.example.no_smoke

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import androidx.core.app.NotificationCompat

/// Keeps the quick-log button on screen.
///
/// Tied to the screen turning on rather than to a time of day: an overlay is
/// only ever visible while the screen is on anyway, so a "daytime only"
/// schedule would save nothing on visibility while still refusing to record
/// the 3am cigarette of someone who was awake for it. Tearing the view down
/// on SCREEN_OFF means the service costs nothing with the phone in a pocket.
class SmokedLogOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var buttonView: SmokedLogButtonView? = null
    private var params: WindowManager.LayoutParams? = null
    private var screenReceiver: BroadcastReceiver? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }

        ensureForeground()
        registerScreenReceiver()
        if (isScreenOn()) {
            attachButton()
        }
        // Sticky: the button is meant to be a standing offer, so an OEM
        // reclaiming memory shouldn't quietly retire it.
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        screenReceiver?.let { runCatching { unregisterReceiver(it) } }
        screenReceiver = null
        detachButton()
        super.onDestroy()
    }

    private fun isScreenOn(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        return pm.isInteractive
    }

    private fun registerScreenReceiver() {
        if (screenReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_ON -> attachButton()
                    Intent.ACTION_SCREEN_OFF -> detachButton()
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(receiver, filter)
        screenReceiver = receiver
    }

    private fun prefs(): SharedPreferences =
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun attachButton() {
        if (buttonView != null) return
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val density = resources.displayMetrics.density
        val size = (SIZE_DP * density).toInt()

        val view = SmokedLogButtonView(
            context = this,
            onHoldCompleted = { recordSmokedEvent() },
            onDragged = { dx, dy -> moveBy(dx, dy) },
            onDragFinished = { persistPosition() },
        )

        val layout = WindowManager.LayoutParams(
            size,
            size,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            // NOT_FOCUSABLE so typing, scrolling and every other interaction
            // underneath carries on untouched — the button takes only the
            // touches that land on itself.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs().getInt(KEY_X, (density * DEFAULT_X_DP).toInt())
            y = prefs().getInt(KEY_Y, (density * DEFAULT_Y_DP).toInt())
        }

        runCatching {
            wm.addView(view, layout)
            buttonView = view
            params = layout
        }
    }

    private fun detachButton() {
        val view = buttonView ?: return
        runCatching { windowManager?.removeView(view) }
        buttonView = null
        params = null
    }

    private fun moveBy(dx: Float, dy: Float) {
        val layout = params ?: return
        val view = buttonView ?: return
        layout.x += dx.toInt()
        layout.y += dy.toInt()
        runCatching { windowManager?.updateViewLayout(view, layout) }
    }

    private fun persistPosition() {
        val layout = params ?: return
        prefs().edit().putInt(KEY_X, layout.x).putInt(KEY_Y, layout.y).apply()
    }

    private fun recordSmokedEvent() {
        SmokedLogStore.enqueue(this)
        vibrate()
    }

    private fun vibrate() {
        runCatching {
            val effect = VibrationEffect.createOneShot(40, VibrationEffect.DEFAULT_AMPLITUDE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager =
                    getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                manager.defaultVibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).vibrate(effect)
            }
        }
    }

    private fun ensureForeground() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Nikotin Away Hizli Kayit",
                    NotificationManager.IMPORTANCE_MIN,
                ).apply {
                    description = "Sigara ictim butonu ekranda dururken aktif"
                    setShowBadge(false)
                },
            )
        }

        // Also the lock-screen route: an overlay cannot draw over the keyguard,
        // so this action is how the button is reachable there at all. One tap
        // rather than a hold, with an undo window on the Dart side instead.
        val logIntent = Intent(this, SmokedLogActionReceiver::class.java).apply {
            action = SmokedLogActionReceiver.ACTION_LOG
        }
        val pending = android.app.PendingIntent.getBroadcast(
            this,
            0,
            logIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                android.app.PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentTitle(prefs().getString(KEY_NOTIF_TITLE, "Nikotin Away"))
            .setContentText(prefs().getString(KEY_NOTIF_BODY, "Sigara ictiyseniz kaydedin"))
            .addAction(
                0,
                prefs().getString(KEY_NOTIF_ACTION, "Sigara Ictim"),
                pending,
            )
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    companion object {
        const val ACTION_STOP = "com.example.no_smoke.smokedlog.STOP"
        const val CHANNEL_ID = "smoked_log_overlay_channel"
        const val FOREGROUND_NOTIFICATION_ID = 74201

        const val PREFS = "no_smoke_smoked_log"
        private const val KEY_X = "button_x"
        private const val KEY_Y = "button_y"
        const val KEY_NOTIF_TITLE = "notif_title"
        const val KEY_NOTIF_BODY = "notif_body"
        const val KEY_NOTIF_ACTION = "notif_action"

        private const val SIZE_DP = 64f
        private const val DEFAULT_X_DP = 16f
        private const val DEFAULT_Y_DP = 220f

        fun start(context: Context) {
            val intent = Intent(context, SmokedLogOverlayService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, SmokedLogOverlayService::class.java).apply {
                    action = ACTION_STOP
                },
            )
        }
    }
}
