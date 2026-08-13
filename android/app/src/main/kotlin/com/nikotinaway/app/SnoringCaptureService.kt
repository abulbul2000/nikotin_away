package com.nikotinaway.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlin.concurrent.thread
import kotlin.math.sqrt

/// Short-lived foreground service that captures and analyzes one snoring
/// probe's audio sample. Android 11+ blocks microphone access from a plain
/// BroadcastReceiver once the app isn't in the foreground, and Android 14+
/// additionally requires any microphone-capturing foreground service to
/// declare foregroundServiceType="microphone" (see AndroidManifest.xml) and
/// show a notification for as long as it runs -- both are why this used to
/// silently fail to capture anything overnight on recent Android versions
/// when run straight from SleepProbeReceiver.onReceive (see git history:
/// captureAndAnalyzeSnoring used to live there).
///
/// SleepProbeReceiver starts this, it runs the capture on a background
/// thread (never the main thread -- AudioRecord.read blocks), reports the
/// result back via ContentValues the same direct-SQLite-write SnoringProbeStore
/// always used, and stops itself. Never binds, never lingers.
class SnoringCaptureService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureForeground()
        thread(name = "snoring-capture") {
            try {
                val result = captureAndAnalyze()
                SnoringProbeStore.insertProbe(this, result, captureSucceeded = result != null)
            } finally {
                stopSelf(startId)
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /// Notification text is honest about what's happening -- the user should
    /// be able to see the microphone turned on overnight, not just infer it
    /// from a generic "background service" line. Localized strings are
    /// pushed from Dart (see AndroidWatchdogService.setSnoringCaptureChannelInfo)
    /// the same way TaskOverlayService's channel info is, with an
    /// English-default fallback for the same reason (docs/TRANSLATION_GAP.md).
    private fun ensureForeground() {
        val texts = SnoringCaptureTextStore.load(this)
        createChannelIfNeeded(texts.channelName)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(texts.title)
            .setContentText(texts.body)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
        startForeground(FOREGROUND_NOTIFICATION_ID, notification)
    }

    private fun createChannelIfNeeded(channelName: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            channelName.ifBlank { "Sleep intelligence" },
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "Brief overnight microphone sample for snoring detection"
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    /// Captures a short (3s) raw audio sample via AudioRecord (not
    /// MediaRecorder -- no file is ever written, the PCM buffer lives only
    /// in memory for the few hundred milliseconds it takes to compute an
    /// energy envelope, then is discarded) and looks for a rhythmic
    /// loud/quiet pattern in the ~0.3-1.5s cycle range typical of snoring.
    /// VOICE_RECOGNITION disables the platform's automatic gain control,
    /// same reasoning as the breath test's acoustic detection: AGC would
    /// otherwise flatten exactly the energy swings this heuristic looks for.
    /// Returns null on any failure to start/read (permission revoked mid-call,
    /// device busy, etc.) -- the caller records that as a failed capture
    /// rather than silently treating it as "no snoring", which is what an
    /// empty severity result used to be indistinguishable from.
    private fun captureAndAnalyze(): SnoreDetectionResult? {
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return null
        }

        val sampleRate = 16000
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        if (minBufferSize <= 0) {
            return null
        }

        var audioRecord: AudioRecord? = null
        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                channelConfig,
                audioFormat,
                minBufferSize * 2,
            )
            if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
                return null
            }
            audioRecord.startRecording()

            val windowMs = 100
            val windowSamples = sampleRate * windowMs / 1000
            val windowCount = SNORING_CAPTURE_DURATION_MS / windowMs
            val buffer = ShortArray(windowSamples)
            val energies = DoubleArray(windowCount)

            for (i in 0 until windowCount) {
                val read = audioRecord.read(buffer, 0, windowSamples)
                if (read > 0) {
                    var sumSquares = 0.0
                    for (j in 0 until read) {
                        val normalized = buffer[j] / 32768.0
                        sumSquares += normalized * normalized
                    }
                    energies[i] = sqrt(sumSquares / read)
                }
            }

            audioRecord.stop()
            return detectSnoreSeverity(energies, windowMs)
        } catch (_: Exception) {
            return null
        } finally {
            audioRecord?.release()
        }
    }

    /// Simple rule-based heuristic (energy envelope + periodicity), same
    /// spirit as BreathAcousticEngine: finds windows loud enough relative to
    /// this clip's own median to count as a "burst", collapses adjacent
    /// loud windows into single events, then checks whether consecutive
    /// events repeat at a snore-typical interval.
    ///
    /// Beyond the plain detected/not-detected call, also scores how
    /// pronounced this probe's pattern was -- combining how far events
    /// cleared the threshold (intensity) with how consistently consecutive
    /// events landed inside the snore-cycle window (continuity), same
    /// two-component-weighted-sum shape as WheezeDetectionEngine's severity
    /// score on the Dart side. Not device-calibrated -- see this file's
    /// other detection heuristics for the same caveat.
    private fun detectSnoreSeverity(energies: DoubleArray, windowMs: Int): SnoreDetectionResult {
        if (energies.isEmpty()) {
            return SnoreDetectionResult(snoreLikely = false, severityScore = 0, severityLevel = "none")
        }
        val sorted = energies.sorted()
        val median = sorted[sorted.size / 2]
        val threshold = median * 2.0 + 0.01

        val events = mutableListOf<Int>()
        var lastEventIndex = -10
        for (i in energies.indices) {
            if (energies[i] > threshold && i - lastEventIndex > 2) {
                events.add(i)
                lastEventIndex = i
            }
        }
        if (events.size < 2) {
            return SnoreDetectionResult(snoreLikely = false, severityScore = 0, severityLevel = "none")
        }

        var inCycleGapCount = 0
        var intensityRatioSum = 0.0
        for (i in 1 until events.size) {
            val gapMs = (events[i] - events[i - 1]) * windowMs
            if (gapMs in SNORE_MIN_CYCLE_MS..SNORE_MAX_CYCLE_MS) {
                inCycleGapCount++
            }
        }
        for (index in events) {
            intensityRatioSum += energies[index] / threshold
        }

        val snoreLikely = inCycleGapCount > 0
        if (!snoreLikely) {
            return SnoreDetectionResult(snoreLikely = false, severityScore = 0, severityLevel = "none")
        }

        // Continuity: what fraction of consecutive event pairs actually fell
        // inside the snore-cycle window -- a single lucky pair among many
        // unrelated bursts scores low, a clip that's snore-cycle end to end
        // scores near 1.
        val continuityScore = (inCycleGapCount.toDouble() / (events.size - 1)).coerceIn(0.0, 1.0)
        // Intensity: how far above the threshold events cleared, on
        // average, anchored the same way WheezeDetectionEngine anchors its
        // ratio score (a event right at the threshold scores 0, one at 2x+
        // the threshold scores 1).
        val averageIntensityRatio = intensityRatioSum / events.size
        val intensityScore = ((averageIntensityRatio - 1.0) / 1.0).coerceIn(0.0, 1.0)

        val combined = intensityScore * 0.5 + continuityScore * 0.5
        val score = (combined * 100).toInt().coerceIn(0, 100)
        val level = when {
            score <= 0 -> "none"
            score < 35 -> "mild"
            score < 65 -> "moderate"
            else -> "severe"
        }
        return SnoreDetectionResult(snoreLikely = true, severityScore = score, severityLevel = level)
    }

    companion object {
        const val CHANNEL_ID = "snoring_capture_channel"
        const val FOREGROUND_NOTIFICATION_ID = 84101
        private const val SNORING_CAPTURE_DURATION_MS = 3000
        private const val SNORE_MIN_CYCLE_MS = 300
        private const val SNORE_MAX_CYCLE_MS = 1500

        fun start(context: Context) {
            val intent = Intent(context, SnoringCaptureService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}

/// Localized notification text for [SnoringCaptureService]'s required
/// foreground-service notification -- pushed from Dart the same way
/// WatchdogStore.saveLocalizedText/loadLocalizedText is, English-default
/// fallback for the same reason (docs/TRANSLATION_GAP.md).
data class SnoringCaptureTexts(
    val title: String,
    val body: String,
    val channelName: String,
)

object SnoringCaptureTextStore {
    private const val PREFS = "no_smoke_snoring_capture"
    private const val KEY_TITLE = "title"
    private const val KEY_BODY = "body"
    private const val KEY_CHANNEL_NAME = "channel_name"

    fun save(context: Context, title: String, body: String, channelName: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TITLE, title)
            .putString(KEY_BODY, body)
            .putString(KEY_CHANNEL_NAME, channelName)
            .apply()
    }

    fun load(context: Context): SnoringCaptureTexts {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return SnoringCaptureTexts(
            title = prefs.getString(KEY_TITLE, null)?.takeIf { it.isNotBlank() }
                ?: "Nikotin Away",
            body = prefs.getString(KEY_BODY, null)?.takeIf { it.isNotBlank() }
                ?: "Taking a brief sound sample to check for snoring",
            channelName = prefs.getString(KEY_CHANNEL_NAME, null)?.takeIf { it.isNotBlank() }
                ?: "Sleep intelligence",
        )
    }
}
