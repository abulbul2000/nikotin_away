package com.example.no_smoke

import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.telecom.TelecomManager
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant

class MainActivity : FlutterActivity() {
	private val channelName = "no_smoke/watchdog"
	private val devicePermissionsChannelName = "no_smoke/device_permissions"
	private val sleepProbeChannelName = "no_smoke/sleep_probe"
	private val geofencingChannelName = "no_smoke/geofencing"
	private val stepsChannelName = "no_smoke/steps"
	private val healthConnectChannelName = "no_smoke/health_connect"

	// Phase 9 wearable spike: reads heart-rate/sleep data Health Connect
	// already has on-device (from Wear OS/Galaxy Watch/Fitbit/Garmin
	// companion apps syncing into it) — this app never talks to a wearable
	// directly. Read-only permission set; requesting write access would
	// need a very different consent story.
	private val healthConnectPermissions = setOf(
		HealthPermission.getReadPermission(HeartRateRecord::class),
		HealthPermission.getReadPermission(SleepSessionRecord::class),
	)
	private val healthConnectScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
	private var pendingHealthConnectPermissionResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, sleepProbeChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"scheduleNightlyProbing" -> {
						val windowStartMinute = call.argument<Int>("windowStartMinute") ?: -1
						val windowEndMinute = call.argument<Int>("windowEndMinute") ?: -1
						val intervalMinutes = call.argument<Int>("intervalMinutes")
							?: SleepProbeReceiver.DEFAULT_INTERVAL_MINUTES
						if (windowStartMinute < 0 || windowEndMinute < 0) {
							result.error("invalid_args", "windowStartMinute/windowEndMinute required", null)
							return@setMethodCallHandler
						}
						SleepProbeStore.saveSchedule(this, windowStartMinute, windowEndMinute, intervalMinutes)
						SleepProbeReceiver.scheduleWindowAware(this, windowStartMinute, windowEndMinute, intervalMinutes)
						result.success(true)
					}

					"cancelNightlyProbing" -> {
						SleepProbeStore.clearSchedule(this)
						SleepProbeReceiver.cancel(this)
						result.success(true)
					}

					"consumeSleepActivityEvents" -> {
						val events = SleepActivityStore.drain(this)
						result.success(events)
					}

					"setSnoringDetectionEnabled" -> {
						val enabled = call.argument<Boolean>("enabled") ?: false
						SleepProbeStore.setSnoringDetectionEnabled(this, enabled)
						result.success(true)
					}

					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, stepsChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"readCurrentStepCount" -> {
						StepCounterReader.readOnce(this) { steps ->
							result.success(steps)
						}
					}

					"scheduleDailyStepProbe" -> {
						StepProbeStore.setEnabled(this, true)
						StepProbeReceiver.scheduleNext(this)
						result.success(true)
					}

					"cancelDailyStepProbe" -> {
						StepProbeStore.setEnabled(this, false)
						StepProbeReceiver.cancel(this)
						result.success(true)
					}

					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, geofencingChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"registerGeofences" -> {
						@Suppress("UNCHECKED_CAST")
						val places = call.argument<List<Map<String, Any>>>("places") ?: emptyList()
						val notificationTitle = call.argument<String>("notificationTitle").orEmpty()
						val notificationBody = call.argument<String>("notificationBody").orEmpty()
						registerGeofences(places, notificationTitle, notificationBody)
						result.success(true)
					}

					"clearGeofences" -> {
						clearGeofences()
						result.success(true)
					}

					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, devicePermissionsChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"isMiuiDevice" -> result.success(Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true))
					"openMiuiPermissionEditor" -> result.success(openMiuiPermissionEditor())
					"isInPhoneCall" -> result.success(isInPhoneCall())
					"getManufacturer" -> result.success(Build.MANUFACTURER)
					"openAutostartSettings" -> result.success(openAutostartSettings())
					"hasOverlayPermission" -> result.success(hasOverlayPermission())
					"requestOverlayPermission" -> result.success(requestOverlayPermission())
					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, healthConnectChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"isAvailable" -> {
						result.success(
							HealthConnectClient.getSdkStatus(this) == HealthConnectClient.SDK_AVAILABLE
						)
					}

					"installHealthConnect" -> {
						try {
							startActivity(
								Intent(Intent.ACTION_VIEW).apply {
									setPackage("com.android.vending")
									data = Uri.parse(
										"market://details?id=com.google.android.apps.healthdata" +
											"&url=healthconnect%3A%2F%2Fonboarding"
									)
									addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
								}
							)
							result.success(true)
						} catch (e: ActivityNotFoundException) {
							result.success(false)
						}
					}

					"hasPermissions" -> {
						val client = healthConnectClientOrNull()
						if (client == null) {
							result.success(false)
							return@setMethodCallHandler
						}
						healthConnectScope.launch {
							try {
								val granted = client.permissionController.getGrantedPermissions()
								result.success(granted.containsAll(healthConnectPermissions))
							} catch (e: Exception) {
								result.success(false)
							}
						}
					}

					"requestPermissions" -> {
						val client = healthConnectClientOrNull()
						if (client == null) {
							result.success(false)
							return@setMethodCallHandler
						}
						pendingHealthConnectPermissionResult = result
						val contract = PermissionController.createRequestPermissionResultContract()
						val intent = contract.createIntent(this, healthConnectPermissions)
						try {
							startActivityForResult(intent, HEALTH_CONNECT_PERMISSION_REQUEST_CODE)
						} catch (e: ActivityNotFoundException) {
							pendingHealthConnectPermissionResult = null
							result.success(false)
						}
					}

					"getHeartRateRecords" -> {
						val client = healthConnectClientOrNull()
						if (client == null) {
							result.success(emptyList<Map<String, Any>>())
							return@setMethodCallHandler
						}
						val startMillis = call.argument<Number>("startTimeMillis")?.toLong() ?: 0L
						val endMillis = call.argument<Number>("endTimeMillis")?.toLong()
							?: System.currentTimeMillis()
						healthConnectScope.launch {
							try {
								val response = client.readRecords(
									ReadRecordsRequest(
										recordType = HeartRateRecord::class,
										timeRangeFilter = TimeRangeFilter.between(
											Instant.ofEpochMilli(startMillis),
											Instant.ofEpochMilli(endMillis),
										),
									)
								)
								val samples = response.records.flatMap { record ->
									record.samples.map { sample ->
										mapOf(
											"timeMillis" to sample.time.toEpochMilli(),
											"bpm" to sample.beatsPerMinute,
										)
									}
								}
								result.success(samples)
							} catch (e: Exception) {
								result.success(emptyList<Map<String, Any>>())
							}
						}
					}

					"getSleepSessions" -> {
						val client = healthConnectClientOrNull()
						if (client == null) {
							result.success(emptyList<Map<String, Any>>())
							return@setMethodCallHandler
						}
						val startMillis = call.argument<Number>("startTimeMillis")?.toLong() ?: 0L
						val endMillis = call.argument<Number>("endTimeMillis")?.toLong()
							?: System.currentTimeMillis()
						healthConnectScope.launch {
							try {
								val response = client.readRecords(
									ReadRecordsRequest(
										recordType = SleepSessionRecord::class,
										timeRangeFilter = TimeRangeFilter.between(
											Instant.ofEpochMilli(startMillis),
											Instant.ofEpochMilli(endMillis),
										),
									)
								)
								val sessions = response.records.map { record ->
									mapOf(
										"startTimeMillis" to record.startTime.toEpochMilli(),
										"endTimeMillis" to record.endTime.toEpochMilli(),
									)
								}
								result.success(sessions)
							} catch (e: Exception) {
								result.success(emptyList<Map<String, Any>>())
							}
						}
					}

					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"startWatchdog" -> {
						val taskTitle = call.argument<String>("taskTitle").orEmpty()
						val watchdogId = call.argument<String>("watchdogId").orEmpty()
						val dueAtMillis = call.argument<Number>("dueAtMillis")?.toLong() ?: 0L
						if (taskTitle.isBlank() || watchdogId.isBlank() || dueAtMillis <= 0L) {
							result.error("invalid_args", "taskTitle/watchdogId/dueAtMillis required", null)
							return@setMethodCallHandler
						}
						NoResponseWatchdogService.start(this, taskTitle, watchdogId, dueAtMillis)
						result.success(true)
					}

					"ackWatchdog" -> {
						val watchdogId = call.argument<String>("watchdogId").orEmpty()
						if (watchdogId.isNotBlank()) {
							NoResponseWatchdogService.acknowledge(this, watchdogId)
						}
						result.success(true)
					}

					"consumeWatchdogViolations" -> {
						val rows = WatchdogStore.drainViolations(this)
						val mapped = rows.mapNotNull { row ->
							val parts = row.split("|")
							if (parts.size < 3) {
								return@mapNotNull null
							}
							mapOf(
								"type" to parts[0],
								"taskTitle" to parts[1],
								"createdAtMillis" to (parts[2].toLongOrNull() ?: System.currentTimeMillis()),
							)
						}
						result.success(mapped)
					}

					"showTaskOverlay" -> {
						val title = call.argument<String>("title").orEmpty()
						val body = call.argument<String>("body").orEmpty()
						val doneLabel = call.argument<String>("doneLabel").orEmpty()
						val declineLabel = call.argument<String>("declineLabel").orEmpty()
						val watchdogId = call.argument<String>("watchdogId").orEmpty()
						val taskTitle = call.argument<String>("taskTitle").orEmpty()
						if (hasOverlayPermission() && title.isNotBlank() && watchdogId.isNotBlank()) {
							TaskOverlayService.show(
								context = this,
								title = title,
								body = body,
								acceptLabel = doneLabel,
								postponeLabel = call.argument<String>("postponeLabel").orEmpty(),
								declineLabel = declineLabel,
								sosLabel = call.argument<String>("sosLabel").orEmpty(),
								watchdogId = watchdogId,
								taskTitle = taskTitle,
							)
							result.success(true)
						} else {
							result.success(false)
						}
					}

					"scheduleTaskTrigger" -> {
						val watchdogId = call.argument<String>("watchdogId").orEmpty()
						val taskTitle = call.argument<String>("taskTitle").orEmpty()
						val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
						if (watchdogId.isBlank() || taskTitle.isBlank() || triggerAtMillis <= 0L) {
							result.error("invalid_args", "watchdogId/taskTitle/triggerAtMillis required", null)
							return@setMethodCallHandler
						}
						TaskTriggerReceiver.schedule(
							context = this,
							title = call.argument<String>("title").orEmpty(),
							body = call.argument<String>("body").orEmpty(),
							acceptLabel = call.argument<String>("doneLabel").orEmpty(),
							postponeLabel = call.argument<String>("postponeLabel").orEmpty(),
							declineLabel = call.argument<String>("declineLabel").orEmpty(),
							sosLabel = call.argument<String>("sosLabel").orEmpty(),
							watchdogId = watchdogId,
							taskTitle = taskTitle,
							triggerAtMillis = triggerAtMillis,
							watchdogWindowMillis = call.argument<Number>("watchdogWindowMillis")?.toLong()
								?: TaskTriggerReceiver.DEFAULT_WATCHDOG_WINDOW_MILLIS,
						)
						result.success(true)
					}

					"cancelTaskTrigger" -> {
						val watchdogId = call.argument<String>("watchdogId").orEmpty()
						if (watchdogId.isNotBlank()) {
							TaskTriggerReceiver.cancel(this, watchdogId)
						}
						result.success(true)
					}

					"setSmokedLogButtonEnabled" -> {
						val enabled = call.argument<Boolean>("enabled") ?: false
						if (enabled) {
							if (!hasOverlayPermission()) {
								result.success(false)
								return@setMethodCallHandler
							}
							// Labels come from Dart so the ongoing notification
							// follows the user's chosen language like everything
							// else; the service has no access to AppTexts.
							getSharedPreferences(SmokedLogOverlayService.PREFS, MODE_PRIVATE)
								.edit()
								.putString(
									SmokedLogOverlayService.KEY_NOTIF_TITLE,
									call.argument<String>("notificationTitle"),
								)
								.putString(
									SmokedLogOverlayService.KEY_NOTIF_BODY,
									call.argument<String>("notificationBody"),
								)
								.putString(
									SmokedLogOverlayService.KEY_NOTIF_ACTION,
									call.argument<String>("actionLabel"),
								)
								.apply()
							SmokedLogOverlayService.start(this)
						} else {
							SmokedLogOverlayService.stop(this)
						}
						result.success(true)
					}

					"consumeSmokedLogEvents" -> {
						result.success(SmokedLogStore.drain(this))
					}

					"consumeDeliveryDeferrals" -> {
						result.success(DeliveryGateStore.drain(this))
					}

					"dismissTaskOverlay" -> {
						TaskOverlayService.dismiss(this)
						result.success(true)
					}

					"consumeTaskOverlayOutcomes" -> {
						val rows = TaskOverlayOutcomeStore.drain(this)
						val mapped = rows.mapNotNull { row ->
							val parts = row.split("|")
							if (parts.size < 4) {
								return@mapNotNull null
							}
							mapOf(
								"watchdogId" to parts[0],
								"taskTitle" to parts[1],
								"outcome" to parts[2],
								"createdAtMillis" to (parts[3].toLongOrNull() ?: System.currentTimeMillis()),
							)
						}
						result.success(mapped)
					}

					else -> result.notImplemented()
				}
			}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)
		if (requestCode == HEALTH_CONNECT_PERMISSION_REQUEST_CODE) {
			val pendingResult = pendingHealthConnectPermissionResult
			pendingHealthConnectPermissionResult = null
			healthConnectScope.launch {
				val client = healthConnectClientOrNull()
				val granted = try {
					client?.permissionController?.getGrantedPermissions()
						?.containsAll(healthConnectPermissions) ?: false
				} catch (e: Exception) {
					false
				}
				pendingResult?.success(granted)
			}
		}
	}

	private fun healthConnectClientOrNull(): HealthConnectClient? {
		return try {
			if (HealthConnectClient.getSdkStatus(this) != HealthConnectClient.SDK_AVAILABLE) {
				null
			} else {
				HealthConnectClient.getOrCreate(this)
			}
		} catch (e: Exception) {
			null
		}
	}

	// MIUI hides "display pop-up windows while running in the background" and
	// "show on Lock screen" — required for the fake-call barrier's full-screen
	// intent to actually take over the lock screen — behind its own permission
	// editor rather than the standard Android app-info screen. Android itself
	// has no API to grant these programmatically (nor should it — that would
	// defeat the point of the permission); the best available UX is a direct
	// deep link into the exact MIUI screen so the user only needs one tap
	// instead of hunting through nested settings menus. Component names vary
	// across MIUI versions, so every known variant is tried in turn. Returns
	// false (caller falls back to the generic app-settings screen) if none
	// resolve, which is also simply what happens on any non-MIUI device.
	private fun openMiuiPermissionEditor(): Boolean {
		val candidates = listOf(
			"com.miui.securitycenter" to "com.miui.permcenter.permissions.PermissionsEditorActivity",
			"com.miui.securitycenter" to "com.miui.permcenter.permissions.AppPermissionsEditorActivity",
			"com.miui.securitycenter" to "com.miui.permcenter.permissions.PermissionMainActivity"
		)
		for ((pkg, cls) in candidates) {
			try {
				val intent = Intent("miui.intent.action.APP_PERM_EDITOR")
				intent.setClassName(pkg, cls)
				intent.putExtra("extra_pkgname", packageName)
				intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				startActivity(intent)
				return true
			} catch (e: ActivityNotFoundException) {
				// Try the next known component name.
			} catch (e: SecurityException) {
				// Try the next known component name.
			}
		}
		return false
	}

	// Several Android OEMs (not just Xiaomi) run their own aggressive
	// background-process killer on top of stock Android and require the
	// user to separately allow this specific app to "autostart" / run in
	// the background, or AlarmManager-driven features (sleep/location/step
	// probes, the fake-call barrier) can be silently killed regardless of
	// how correctly they're implemented against the standard Android APIs.
	// This deep-links straight to the known autostart/protected-apps screen
	// for the device's manufacturer; every component name is best-effort
	// (undocumented, varies by OEM skin version) so each candidate is tried
	// in turn, same defensive pattern as openMiuiPermissionEditor. Returns
	// false for manufacturers with no known screen (or if every candidate
	// fails), in which case the Dart-side caller falls back to the generic
	// app-details settings screen — a universal Android intent that exists
	// on every device regardless of manufacturer — so every phone ends up
	// with a usable button, not just the ones listed here.
	private fun openAutostartSettings(): Boolean {
		val manufacturer = Build.MANUFACTURER.lowercase()
		val candidates = when {
			manufacturer.contains("xiaomi") -> listOf(
				"com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
			)
			manufacturer.contains("huawei") || manufacturer.contains("honor") -> listOf(
				"com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
				"com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
				"com.huawei.systemmanager" to "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
			)
			manufacturer.contains("oppo") -> listOf(
				"com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
				"com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
				"com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
			)
			manufacturer.contains("vivo") -> listOf(
				"com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
				"com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
			)
			manufacturer.contains("oneplus") -> listOf(
				"com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
			)
			manufacturer.contains("samsung") -> listOf(
				// One UI's equivalent is "Battery" > per-app unrestricted setting
				// rather than a single autostart list; component names have
				// shifted across One UI versions (Device Care -> Battery), so
				// several are tried before falling back to the generic screen.
				"com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
				"com.samsung.android.lool" to "com.samsung.android.sm.ui.battery.BatteryActivity",
				"com.samsung.android.sm" to "com.samsung.android.sm.ui.battery.BatteryActivity",
			)
			manufacturer.contains("meizu") -> listOf(
				"com.meizu.safe" to "com.meizu.safe.permission.PermissionMainActivity",
			)
			manufacturer.contains("asus") -> listOf(
				"com.asus.mobilemanager" to "com.asus.mobilemanager.autostart.AutoStartActivity",
				"com.asus.mobilemanager" to "com.asus.mobilemanager.entry.FunctionActivity",
			)
			else -> emptyList()
		}

		for ((pkg, cls) in candidates) {
			try {
				val intent = Intent()
				intent.setClassName(pkg, cls)
				intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				startActivity(intent)
				return true
			} catch (e: ActivityNotFoundException) {
				// Try the next known component name.
			} catch (e: SecurityException) {
				// Try the next known component name.
			}
		}
		return false
	}

	// "Display over other apps" -- required for TaskOverlayService to draw the
	// mandatory task screen over whatever app is currently in the foreground
	// (fullScreenIntent notifications only auto-launch on a locked screen, not
	// over another running app). Android has no runtime-dialog path for this
	// permission; the only way to grant it is this dedicated Settings screen.
	private fun hasOverlayPermission(): Boolean {
		return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)
	}

	private fun requestOverlayPermission(): Boolean {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
			return true
		}
		return try {
			val intent = Intent(
				Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
				Uri.parse("package:$packageName"),
			).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
			startActivity(intent)
			true
		} catch (e: ActivityNotFoundException) {
			false
		}
	}

	// Used to keep the fake-call barrier from ringing over a genuine phone
	// call -- see NotificationService.scheduleFakeCallBarrier and
	// FakeCallBarrierService, which push the scheduled/rescheduled time out
	// when this returns true. Only the coarse in-call/not-in-call state is
	// read -- never the number or call content -- and READ_PHONE_STATE not
	// being granted is treated the same as "not in a call" (best-effort,
	// same posture as the app's other optional sensor permissions) rather
	// than surfacing an error to the caller.
	private fun isInPhoneCall(): Boolean {
		if (checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE)
				!= PackageManager.PERMISSION_GRANTED) {
			return false
		}
		return try {
			val telecomManager = getSystemService(TELECOM_SERVICE) as? TelecomManager
			telecomManager?.isInCall ?: false
		} catch (e: SecurityException) {
			false
		}
	}

	// Replaces the entire geofence set on every call (Dart re-syncs whenever
	// the learned place list or app language changes) rather than diffing —
	// at most 8 geofences, so a full remove+add is cheap and avoids stale
	// entries lingering if a place ever drops out of the top 8.
	private fun registerGeofences(
		places: List<Map<String, Any>>,
		notificationTitle: String,
		notificationBody: String,
	) {
		if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION)
				!= PackageManager.PERMISSION_GRANTED &&
			checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION)
				!= PackageManager.PERMISSION_GRANTED
		) {
			return
		}

		GeofenceStore.saveNotificationText(this, notificationTitle, notificationBody)

		val geofencingClient = LocationServices.getGeofencingClient(this)
		val pendingIntent = geofencePendingIntent()
		geofencingClient.removeGeofences(pendingIntent)

		if (places.isEmpty()) {
			return
		}

		val geofences = places.mapNotNull { place ->
			val id = place["id"] as? String ?: return@mapNotNull null
			val lat = (place["latitude"] as? Number)?.toDouble() ?: return@mapNotNull null
			val lng = (place["longitude"] as? Number)?.toDouble() ?: return@mapNotNull null
			Geofence.Builder()
				.setRequestId(id)
				.setCircularRegion(lat, lng, GEOFENCE_RADIUS_METERS)
				.setExpirationDuration(Geofence.NEVER_EXPIRE)
				.setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
				.build()
		}
		if (geofences.isEmpty()) {
			return
		}

		val request = GeofencingRequest.Builder()
			.setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
			.addGeofences(geofences)
			.build()

		try {
			geofencingClient.addGeofences(request, pendingIntent)
		} catch (e: SecurityException) {
			// Background location not (yet) granted — Dart-side state already
			// reflects permission status, this just no-ops the native call.
		}
	}

	private fun clearGeofences() {
		val geofencingClient = LocationServices.getGeofencingClient(this)
		geofencingClient.removeGeofences(geofencePendingIntent())
	}

	private fun geofencePendingIntent(): PendingIntent {
		val intent = Intent(this, GeofenceTransitionReceiver::class.java)
		// Geofencing PendingIntents must be mutable -- Play Services writes
		// the triggering GeofencingEvent into the intent's extras itself.
		return PendingIntent.getBroadcast(
			this,
			GEOFENCE_REQUEST_CODE,
			intent,
			PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
		)
	}

	companion object {
		private const val GEOFENCE_REQUEST_CODE = 86001
		private const val GEOFENCE_RADIUS_METERS = 150f
		private const val HEALTH_CONNECT_PERMISSION_REQUEST_CODE = 86002
	}
}
