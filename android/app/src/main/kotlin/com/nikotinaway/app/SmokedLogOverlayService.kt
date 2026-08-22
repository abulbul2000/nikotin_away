package com.nikotinaway.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
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
    private var menuView: android.view.View? = null

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
        scheduleRestartIfEnabled()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Removing the app from Recents must not remove the standing quick-log
        // button. Android may destroy the service with the task, so schedule a
        // short, permission-safe restart rather than relying only on STICKY.
        scheduleRestartIfEnabled()
        super.onTaskRemoved(rootIntent)
    }

    private fun scheduleRestartIfEnabled() {
        if (!prefs().getBoolean(KEY_ENABLED, false)) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(this)
        ) return

        val restartIntent = Intent(this, SmokedLogOverlayService::class.java).apply {
            action = ACTION_RESTART
        }
        val pendingIntent = PendingIntent.getService(
            this,
            RESTART_REQUEST_CODE,
            restartIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarm = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + RESTART_DELAY_MS,
            pendingIntent,
        )
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
                    Intent.ACTION_SCREEN_ON -> {
                        // The delivery gate needs to know how long the screen
                        // has been on, and Android exposes no such counter.
                        // This receiver is already listening for exactly the
                        // right broadcasts, so it keeps the figure current.
                        DeliveryGateEvaluator.noteScreenOn(context)
                        attachButton()
                    }
                    Intent.ACTION_SCREEN_OFF -> {
                        DeliveryGateEvaluator.noteScreenOff(context)
                        detachButton()
                    }
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
            //
            // The window itself is deliberately kept fully on-screen (no
            // LAYOUT_NO_LIMITS): that flag does let x go negative or past
            // screenWidth, but Android can then only deliver touches to
            // whatever sliver of the view actually overlaps the screen — a
            // button parked half off-screen that way becomes nearly
            // untouchable. The half-off-screen *look* is produced instead in
            // SmokedLogButtonView's onDraw, which draws only the on-screen
            // half of the mark — the window stays put and fully touchable,
            // only the paint is clipped.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // The saved value predates half-off-screen parking (it may be a
            // flush-with-the-edge x from an older build), so it is only
            // trusted to say which side the button was on — snappedXFor
            // recomputes the actual half-off-screen x from that side every
            // time, rather than replaying whatever was persisted.
            val savedX = prefs().getInt(KEY_X, (density * DEFAULT_X_DP).toInt())
            x = snappedXFor(wasOnLeft = savedX + size / 2 < resources.displayMetrics.widthPixels / 2, buttonWidth = size)
            y = prefs().getInt(KEY_Y, (density * DEFAULT_Y_DP).toInt())
        }

        runCatching {
            wm.addView(view, layout)
            buttonView = view
            params = layout
            view.facingRight = isOnLeftEdge(layout.x, size)
        }
    }

    /// True once the button's center has crossed to the left half of the
    /// screen — the same rule [persistPosition] snaps by, so the mark's
    /// facing always matches the edge it is actually resting against, both
    /// right after [attachButton] restores a saved position and after every
    /// drag-and-release.
    private fun isOnLeftEdge(x: Int, buttonWidth: Int): Boolean {
        val screenWidth = resources.displayMetrics.widthPixels
        val centerX = x + buttonWidth / 2
        return centerX < screenWidth / 2
    }

    /// The window's x for whichever side the button belongs on. The window
    /// itself stays flush with the edge (fully on-screen, so it stays fully
    /// touchable) — the half-off-screen look comes from what
    /// SmokedLogButtonView chooses to paint, not from moving the window
    /// past the screen bounds.
    private fun snappedXFor(wasOnLeft: Boolean, buttonWidth: Int): Int {
        val screenWidth = resources.displayMetrics.widthPixels
        return if (wasOnLeft) 0 else screenWidth - buttonWidth
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

    /// Snaps to whichever edge the button was released closer to, same side
    /// DraggableButterflyButton (the in-app equivalent) picks by: the drop
    /// point's distance from screen-center decides left vs. right. Unlike
    /// that in-app control, though, this one is parked half off-screen —
    /// like Android's own accessibility button — so it reads as tucked out
    /// of the way rather than a control floating a few dp inside the edge.
    /// The window's own bounds do the clipping; only the inward half of the
    /// view is ever actually on screen.
    private fun persistPosition() {
        val layout = params ?: return
        val view = buttonView ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        val buttonWidth = if (view.width > 0) view.width else layout.width
        val centerX = layout.x + buttonWidth / 2
        layout.x = snappedXFor(wasOnLeft = centerX < screenWidth / 2, buttonWidth = buttonWidth)
        runCatching { windowManager?.updateViewLayout(view, layout) }
        view.facingRight = isOnLeftEdge(layout.x, buttonWidth)
        prefs().edit().putInt(KEY_X, layout.x).putInt(KEY_Y, layout.y).apply()
    }

    /// Opens the choice panel rather than recording straight away.
    ///
    /// A three-second hold used to log a cigarette on its own. That made the
    /// button a single-purpose control, and put the app's two most urgent
    /// actions — admitting a cigarette and asking for help during a craving —
    /// on completely different surfaces, one of which needs the app open.
    /// The moment someone reaches for this button is exactly the moment they
    /// might need either.
    private fun recordSmokedEvent() {
        vibrate()
        showChoicePanel()
    }

    private fun showChoicePanel() {
        if (menuView != null) return
        val wm = windowManager ?: return
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val prefs = prefs()
        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(android.graphics.Color.parseColor("#F20B1F2B"))
            setPadding(dp(20), dp(20), dp(20), dp(20))
            gravity = Gravity.CENTER
        }

        container.addView(
            android.widget.TextView(this).apply {
                text = prefs.getString(KEY_MENU_TITLE, "What would you like to do?")
                setTextColor(android.graphics.Color.WHITE)
                textSize = 18f
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dp(16))
            },
        )

        fun choice(label: String, onChosen: () -> Unit) =
            android.widget.Button(this).apply {
                text = label
                minHeight = dp(52)
                setPadding(dp(16), dp(10), dp(16), dp(10))
                setOnClickListener {
                    dismissChoicePanel()
                    onChosen()
                }
            }

        container.addView(
            choice(prefs.getString(KEY_NOTIF_ACTION, "I Smoked")!!) {
                dismissChoicePanel()
                showTriggerPanel()
            },
        )
        container.addView(
            choice(prefs.getString(KEY_MENU_SOS, "SOS I'm in Crisis")!!) {
                SmokedLogStore.enqueueRoute(this, SmokedLogStore.ROUTE_SOS)
                launchApp()
            },
        )
        container.addView(
            choice(prefs.getString(KEY_MENU_OPEN, "Open App")!!) {
                launchApp()
            },
        )
        container.addView(
            choice(prefs.getString(KEY_MENU_CANCEL, "Cancel")!!) {},
        )

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val menuParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            // Focusable: the panel has buttons to press. Without this the
            // touches fall through to whatever is underneath.
            0,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
        }

        runCatching {
            wm.addView(container, menuParams)
            menuView = container
        }
    }

    private fun showTriggerPanel() {
        val wm = windowManager ?: return
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()
        val prefs = prefs()
        val panel = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(android.graphics.Color.parseColor("#F20B1F2B"))
            setPadding(dp(20), dp(20), dp(20), dp(20))
            gravity = Gravity.CENTER
        }
        panel.addView(android.widget.TextView(this).apply {
            text = prefs.getString(KEY_TRIGGER_TITLE, "What triggered it?")
            setTextColor(android.graphics.Color.WHITE)
            textSize = 18f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(12))
        })
        val triggers = listOf(
            KEY_TRIGGER_STRESS to "Stres",
            KEY_TRIGGER_COFFEE to "Kahve",
            KEY_TRIGGER_MEAL to "Yemek",
            KEY_TRIGGER_ALCOHOL to "Alkol",
            KEY_TRIGGER_PHONE to "Telefon",
            KEY_TRIGGER_DRIVING to "Arac",
            KEY_TRIGGER_WORK to "Is Molasi",
            KEY_TRIGGER_SOCIAL to "Sosyal Ortam",
            KEY_TRIGGER_BOREDOM to "Can Sikintisi",
            KEY_TRIGGER_HABIT to "Aliskanlik",
            KEY_TRIGGER_UNKNOWN to "unknown",
        )
        triggers.forEach { (labelKey, canonical) ->
            panel.addView(android.widget.Button(this).apply {
                text = prefs.getString(labelKey, canonical)
                minHeight = dp(48)
                setOnClickListener {
                    SmokedLogStore.enqueue(this@SmokedLogOverlayService, canonical)
                    dismissChoicePanel()
                }
            })
        }
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            0,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.CENTER }
        runCatching {
            wm.addView(panel, params)
            menuView = panel
        }
    }

    private fun dismissChoicePanel() {
        val view = menuView ?: return
        runCatching { windowManager?.removeView(view) }
        menuView = null
    }

    private fun launchApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            ?: return
        runCatching { startActivity(intent) }
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
                    prefs().getString(KEY_CHANNEL_NAME, "Nicotine Away Quick Log"),
                    NotificationManager.IMPORTANCE_MIN,
                ).apply {
                    description = prefs().getString(
                        KEY_CHANNEL_DESCRIPTION,
                        "Active while the \"I Smoked\" button is on screen",
                    )
                    setShowBadge(false)
                },
            )
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val contentIntent = launchIntent?.let {
            android.app.PendingIntent.getActivity(
                this,
                FOREGROUND_NOTIFICATION_ID,
                it,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                    android.app.PendingIntent.FLAG_IMMUTABLE,
            )
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentTitle(prefs().getString(KEY_NOTIF_TITLE, "Nicotine Away"))
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .apply { contentIntent?.let { setContentIntent(it) } }
            .build()
        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    companion object {
        const val ACTION_STOP = "com.nikotinaway.app.smokedlog.STOP"
        private const val ACTION_RESTART = "com.nikotinaway.app.smokedlog.RESTART"
        private const val RESTART_REQUEST_CODE = 74202
        private const val RESTART_DELAY_MS = 2_000L
        const val CHANNEL_ID = "smoked_log_overlay_channel"
        const val FOREGROUND_NOTIFICATION_ID = 74201

        const val PREFS = "no_smoke_smoked_log"
        private const val KEY_X = "button_x"
        private const val KEY_Y = "button_y"
        const val KEY_NOTIF_TITLE = "notif_title"
        const val KEY_NOTIF_BODY = "notif_body"
        const val KEY_NOTIF_ACTION = "notif_action"
        const val KEY_MENU_TITLE = "menu_title"
        const val KEY_MENU_SOS = "menu_sos"
        const val KEY_MENU_OPEN = "menu_open"
        const val KEY_MENU_CANCEL = "menu_cancel"
        const val KEY_TRIGGER_TITLE = "trigger_title"
        const val KEY_TRIGGER_STRESS = "trigger_stress"
        const val KEY_TRIGGER_COFFEE = "trigger_coffee"
        const val KEY_TRIGGER_MEAL = "trigger_meal"
        const val KEY_TRIGGER_ALCOHOL = "trigger_alcohol"
        const val KEY_TRIGGER_PHONE = "trigger_phone"
        const val KEY_TRIGGER_DRIVING = "trigger_driving"
        const val KEY_TRIGGER_WORK = "trigger_work"
        const val KEY_TRIGGER_SOCIAL = "trigger_social"
        const val KEY_TRIGGER_BOREDOM = "trigger_boredom"
        const val KEY_TRIGGER_HABIT = "trigger_habit"
        const val KEY_TRIGGER_UNKNOWN = "trigger_unknown"
        const val KEY_CHANNEL_NAME = "channel_name"
        const val KEY_CHANNEL_DESCRIPTION = "channel_description"

        /// Whether the user has the button switched on.
        ///
        /// Dart keeps the same preference in its own database, but the boot
        /// receiver runs long before any Flutter engine exists — so the
        /// answer has to be readable from native code alone. Without it the
        /// button stayed gone after a restart until the user happened to
        /// open the app.
        const val KEY_ENABLED = "button_enabled"

        // Comfortably above the 48dp minimum touch target while staying
        // small enough at rest not to cover much of whatever is underneath.
        private const val SIZE_DP = 80f
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
