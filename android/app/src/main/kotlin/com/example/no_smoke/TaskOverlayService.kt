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
                showOverlay(
                    title = intent.getStringExtra(EXTRA_TITLE).orEmpty(),
                    body = intent.getStringExtra(EXTRA_BODY).orEmpty(),
                    acceptLabel = intent.getStringExtra(EXTRA_DONE_LABEL).orEmpty(),
                    postponeLabel = intent.getStringExtra(EXTRA_DECLINE_LABEL).orEmpty(),
                    declineLabel = intent.getStringExtra(EXTRA_DECLINE_ONLY_LABEL).orEmpty(),
                    sosLabel = intent.getStringExtra(EXTRA_SOS_LABEL).orEmpty(),
                    watchdogId = intent.getStringExtra(EXTRA_WATCHDOG_ID).orEmpty(),
                    taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE).orEmpty(),
                )
            }
            ACTION_SHOW_INFO -> {
                ensureForeground()
                showInfoOverlay(
                    title = intent.getStringExtra(EXTRA_TITLE).orEmpty(),
                    body = intent.getStringExtra(EXTRA_BODY).orEmpty(),
                    dismissLabel = intent.getStringExtra(EXTRA_DONE_LABEL).orEmpty(),
                )
            }
            ACTION_SHOW_REMINDER -> {
                ensureForeground()
                showReminderOverlay(
                    title = intent.getStringExtra(EXTRA_TITLE).orEmpty(),
                    body = intent.getStringExtra(EXTRA_BODY).orEmpty(),
                    openLabel = intent.getStringExtra(EXTRA_DONE_LABEL).orEmpty(),
                    postponeLabel = intent.getStringExtra(EXTRA_DECLINE_LABEL).orEmpty(),
                    route = intent.getStringExtra(EXTRA_ROUTE).orEmpty(),
                    reminderId = intent.getStringExtra(EXTRA_REMINDER_ID).orEmpty(),
                )
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
        val texts = TaskOverlayStore.loadChannelInfo(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        texts.channelName,
                        NotificationManager.IMPORTANCE_LOW,
                    ).apply { description = texts.channelDescription },
                )
            }
        }
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Nikotin Away")
            .setContentText(texts.foregroundBody)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    private fun showOverlay(
        title: String,
        body: String,
        acceptLabel: String,
        postponeLabel: String,
        declineLabel: String,
        sosLabel: String,
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

        // Same four answers the notification offers, so the overlay isn't a
        // reduced version of the same prompt — whichever surface the user
        // happens to be looking at should let them say the same things.
        // Outcome strings are matched in NotificationService's drain.
        fun answerButton(label: String, outcome: String) = Button(this).apply {
            text = label
            minHeight = dp(56)
            setPadding(dp(16), dp(12), dp(16), dp(12))
            setOnClickListener { finish(outcome) }
        }

        container.addView(titleView)
        container.addView(bodyView)
        container.addView(answerButton(acceptLabel, OUTCOME_ACCEPTED))
        if (postponeLabel.isNotBlank()) {
            container.addView(answerButton(postponeLabel, OUTCOME_POSTPONED))
        }
        container.addView(answerButton(declineLabel, OUTCOME_DECLINED))
        if (sosLabel.isNotBlank()) {
            container.addView(answerButton(sosLabel, OUTCOME_SOS))
        }

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

    // Read-only variant for content that isn't a task the user must answer
    // (e.g. a health tip) — one "Kapat" button, no watchdog/outcome plumbing,
    // since nothing here needs to be reported back to Dart.
    private fun showInfoOverlay(title: String, body: String, dismissLabel: String) {
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

        val dismissButton = Button(this).apply {
            text = dismissLabel
            minHeight = dp(56)
            setPadding(dp(16), dp(12), dp(16), dp(12))
            setOnClickListener {
                removeOverlay()
                stopSelf()
            }
        }

        container.addView(titleView)
        container.addView(bodyView)
        container.addView(dismissButton)

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

    // Two-button variant for a reminder the user should act on (breath test,
    // weekly survey) rather than just read. "Open" launches MainActivity and
    // leaves a route for Dart to pick up on resume (see ReminderOverlayStore
    // / _syncReminderOverlayRouteFromNative). "Postpone" just re-arms the
    // same alarm an hour out — HealthTipTriggerReceiver.reschedule — no
    // round-trip to Dart needed for that half.
    private fun showReminderOverlay(
        title: String,
        body: String,
        openLabel: String,
        postponeLabel: String,
        route: String,
        reminderId: String,
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

        val openButton = Button(this).apply {
            text = openLabel
            minHeight = dp(56)
            setPadding(dp(16), dp(12), dp(16), dp(12))
            setOnClickListener {
                ReminderOverlayStore.enqueueRoute(this@TaskOverlayService, route)
                val launchIntent =
                    packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
                if (launchIntent != null) {
                    startActivity(launchIntent)
                }
                removeOverlay()
                stopSelf()
            }
        }
        val postponeButton = Button(this).apply {
            text = postponeLabel
            minHeight = dp(56)
            setPadding(dp(16), dp(12), dp(16), dp(12))
            setOnClickListener {
                HealthTipTriggerReceiver.reschedule(this@TaskOverlayService, reminderId)
                removeOverlay()
                stopSelf()
            }
        }

        container.addView(titleView)
        container.addView(bodyView)
        container.addView(openButton)
        container.addView(postponeButton)

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
        const val ACTION_SHOW_INFO = "com.example.no_smoke.overlay.SHOW_INFO"
        const val ACTION_SHOW_REMINDER = "com.example.no_smoke.overlay.SHOW_REMINDER"
        const val ACTION_DISMISS = "com.example.no_smoke.overlay.DISMISS"
        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_BODY = "extra_body"
        const val EXTRA_DONE_LABEL = "extra_done_label"
        const val EXTRA_DECLINE_LABEL = "extra_decline_label"
        const val EXTRA_DECLINE_ONLY_LABEL = "extra_decline_only_label"
        const val EXTRA_SOS_LABEL = "extra_sos_label"
        const val EXTRA_ROUTE = "extra_route"
        const val EXTRA_REMINDER_ID = "extra_reminder_id"

        /// Kept in sync with NotificationService's overlay-outcome drain.
        /// "done" is unchanged so an overlay raised by an older build still
        /// resolves after an update.
        const val OUTCOME_ACCEPTED = "done"
        const val OUTCOME_POSTPONED = "postponed"
        const val OUTCOME_DECLINED = "declined"
        const val OUTCOME_SOS = "sos"
        const val EXTRA_WATCHDOG_ID = "extra_watchdog_id"
        const val EXTRA_TASK_TITLE = "extra_task_title"
        const val CHANNEL_ID = "task_overlay_foreground_channel"
        const val FOREGROUND_NOTIFICATION_ID = 73101

        /// [postponeLabel] and [sosLabel] may be blank, which hides those
        /// buttons — the flow caps postpone and SOS at two uses per task, and
        /// a button whose answer is "no, not any more" is worse than no
        /// button.
        fun show(
            context: Context,
            title: String,
            body: String,
            acceptLabel: String,
            postponeLabel: String,
            declineLabel: String,
            sosLabel: String,
            watchdogId: String,
            taskTitle: String,
        ) {
            val intent = Intent(context, TaskOverlayService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_DONE_LABEL, acceptLabel)
                putExtra(EXTRA_DECLINE_LABEL, postponeLabel)
                putExtra(EXTRA_DECLINE_ONLY_LABEL, declineLabel)
                putExtra(EXTRA_SOS_LABEL, sosLabel)
                putExtra(EXTRA_WATCHDOG_ID, watchdogId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /// Read-only info overlay (e.g. a health tip) — one dismiss button,
        /// no watchdog/outcome tracking.
        fun showInfo(
            context: Context,
            title: String,
            body: String,
            dismissLabel: String,
        ) {
            val intent = Intent(context, TaskOverlayService::class.java).apply {
                action = ACTION_SHOW_INFO
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_DONE_LABEL, dismissLabel)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /// Two-button reminder overlay (breath test, weekly survey): "Open"
        /// launches the app to [route], "Postpone" re-arms the same alarm an
        /// hour out. [reminderId] must match the id HealthTipTriggerReceiver
        /// scheduled this alarm under, so postpone knows what to reschedule.
        fun showReminder(
            context: Context,
            title: String,
            body: String,
            openLabel: String,
            postponeLabel: String,
            route: String,
            reminderId: String,
        ) {
            val intent = Intent(context, TaskOverlayService::class.java).apply {
                action = ACTION_SHOW_REMINDER
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_DONE_LABEL, openLabel)
                putExtra(EXTRA_DECLINE_LABEL, postponeLabel)
                putExtra(EXTRA_ROUTE, route)
                putExtra(EXTRA_REMINDER_ID, reminderId)
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

data class TaskOverlayChannelInfo(
    val channelName: String,
    val channelDescription: String,
    val foregroundBody: String,
)

object TaskOverlayStore {
    private const val PREFS = "no_smoke_task_overlay"
    private const val KEY_CHANNEL_NAME = "channel_name"
    private const val KEY_CHANNEL_DESCRIPTION = "channel_description"
    private const val KEY_FOREGROUND_BODY = "foreground_body"

    fun saveChannelInfo(context: Context, channelName: String, channelDescription: String, foregroundBody: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_CHANNEL_NAME, channelName)
            .putString(KEY_CHANNEL_DESCRIPTION, channelDescription)
            .putString(KEY_FOREGROUND_BODY, foregroundBody)
            .apply()
    }

    fun loadChannelInfo(context: Context): TaskOverlayChannelInfo {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return TaskOverlayChannelInfo(
            channelName = prefs.getString(KEY_CHANNEL_NAME, null)
                ?.takeIf { it.isNotBlank() } ?: "Nikotin Away Task Screen",
            channelDescription = prefs.getString(KEY_CHANNEL_DESCRIPTION, null)
                ?.takeIf { it.isNotBlank() } ?: "Active while the mandatory task screen is showing",
            foregroundBody = prefs.getString(KEY_FOREGROUND_BODY, null)
                ?.takeIf { it.isNotBlank() } ?: "Task screen showing",
        )
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

/// Holds the route a reminder overlay's "Open" button wants shown next,
/// until Dart picks it up on resume — same producer/consumer shape as
/// [TaskOverlayOutcomeStore], but for navigation rather than a task outcome.
object ReminderOverlayStore {
    private const val PREFS = "no_smoke_reminder_overlay"
    private const val KEY_ROUTE = "pending_route"

    fun enqueueRoute(context: Context, route: String) {
        if (route.isBlank()) {
            return
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ROUTE, route)
            .apply()
    }

    fun drainRoute(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val route = prefs.getString(KEY_ROUTE, null)
        if (route != null) {
            prefs.edit().remove(KEY_ROUTE).apply()
        }
        return route
    }
}
