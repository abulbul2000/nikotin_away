import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../engines/breath_acoustic_engine.dart';
import '../engines/breath_feedback_engine.dart';
import '../engines/breath_test_engine.dart';
import '../engines/breath_trend_engine.dart';
import '../models/breath_acoustic_sample.dart';
import '../models/breath_attempt_feedback.dart';
import '../models/breath_progress_record.dart';
import '../models/noise_check_result.dart';
import '../services/breath_audio_service.dart';
import '../services/breath_noise_check_service.dart';
import '../services/breath_test_service.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import 'breath_spirometry_result_page.dart';
import 'home_page.dart';
import 'risk_result_page.dart';
import 'weekly_survey_page.dart';

class BreathTestPage extends StatefulWidget {
  final String name;
  final String packsPerDay;
  final bool navigateToHomeOnComplete;
  final bool askWeeklySurveyOnComplete;
  final BreathTestService? breathTestService;
  final BreathAudioService? breathAudioService;
  final BreathNoiseCheckService? breathNoiseCheckService;

  const BreathTestPage({
    super.key,
    this.name = '',
    this.packsPerDay = '1 paketten az',
    this.navigateToHomeOnComplete = false,
    this.askWeeklySurveyOnComplete = false,
    this.breathTestService,
    this.breathAudioService,
    this.breathNoiseCheckService,
  });

  @override
  State<BreathTestPage> createState() => _BreathTestPageState();
}

/// Each attempt walks through these in order: read "sit and relax", tap
/// Devam; read "take a deep breath", tap Devam (this is when the hold
/// actually begins — the stopwatch and mic both start here, listening
/// through the quiet hold for a clean calibration baseline); a fixed
/// 3-second "hold" countdown runs on its own, no tap needed, and advances
/// straight into exhale; then the mic auto-detects the exhale (or the user
/// taps the circle/OK button manually if it doesn't). Steps 1-2 are
/// user-paced (the user reads at their own speed and taps Devam when
/// ready); the hold step is deliberately timer-paced instead, since "hold
/// for 3 seconds" is a specific duration, not a read-at-your-own-pace
/// instruction.
enum _AttemptStep { notStarted, sitRelax, deepBreath, holding, exhale }

class _BreathTestPageState extends State<BreathTestPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Above this, the app was almost certainly backgrounded mid-attempt
  // (Stopwatch keeps advancing in real wall-clock time regardless of
  // whether the app was in the foreground) rather than the user genuinely
  // holding/exhaling for that long — not a plausible breath measurement.
  // (There is deliberately no *minimum* bound here: elapsed time is only
  // tracked at whole-second resolution, so a fast — but real — attempt and
  // an instant double-tap are not reliably distinguishable at that
  // granularity; the app-lifecycle check above is the meaningful guard.)
  static const int _maxPlausibleSeconds = 120;

  // Test skoru 3 denemenin ortancası olarak hesaplanıyor (bkz.
  // BreathTrendEngine) — tek deneme şansa çok bağlı, ortanca daha dürüst.
  // Bu da rest-interval gate'in ve progress indicator'ın saydığı sayı.
  static const int _requiredAttemptCount = 3;

  final Stopwatch _stopwatch = Stopwatch();
  final BreathTestEngine _breathTestEngine = BreathTestEngine();
  final BreathAcousticEngine _breathAcousticEngine = BreathAcousticEngine();
  late final BreathTestService _breathTestService;
  late final BreathAudioService _breathAudioService;
  late final BreathNoiseCheckService _breathNoiseCheckService;
  final BreathTrendEngine _breathTrendEngine = BreathTrendEngine();
  final BreathFeedbackEngine _breathFeedbackEngine = BreathFeedbackEngine();
  // Scores (BreathTrendEngine.computeScore) of completed attempts this
  // session, in order — used so BreathFeedbackEngine can tell attempt N
  // apart from attempt N-1 ("stronger than your last one"). Not persisted;
  // only meaningful within a single test run.
  final List<double> _attemptScores = [];
  BreathAttemptFeedback? _lastAttemptFeedback;
  Timer? _timer;
  int _currentTest = 1;
  final List<int> _attemptSeconds = <int>[];
  final List<BreathAcousticSample> _currentAttemptSamples = [];
  // The most recent attempt's spirometry estimate — only one attempt's
  // energy-time curve is ever shown on the result screen (averaging curves
  // across attempts would produce a shape that never actually happened), so
  // this simply gets overwritten by whichever attempt finishes last rather
  // than accumulating a list like _attemptAcousticResults does.
  SpirometryEstimate? _lastSpirometryEstimate;
  // One entry per completed attempt; null means the microphone wasn't
  // available or no exhale could be confidently detected for that attempt —
  // _navigateToResult falls back to the timing-based proxy unless every
  // attempt has a real reading.
  final List<BreathAcousticAnalysis?> _attemptAcousticResults = [];
  // One entry per completed attempt — true when either the pre-test ambient
  // check or the mid-attempt pre-exhale check flagged this attempt as noisy
  // (NoiseLevel.loud). Never blocks the attempt; only excludes it from
  // BreathTrendEngine's trend statistics and flags it in the progress chart.
  final List<bool> _attemptNoiseFlags = [];
  bool _currentAttemptIsNoisy = false;
  Timer? _noiseCheckTimer;
  bool _isResting = false;
  int _restSecondsLeft = 0;
  bool _isRunning = false;
  bool _wasBackgroundedDuringAttempt = false;
  bool _acousticListeningActive = false;
  bool _autoFinishing = false;
  _AttemptStep _step = _AttemptStep.notStarted;
  // Real spirometry uses a brief pause between maximal inhale and forceful
  // exhale, not a long held breath. Long enough to give
  // BreathAcousticEngine's calibration (15 samples minimum) a quiet window.
  static const int _holdCountdownSeconds = 3;
  int _holdCountdownSecondsLeft = _holdCountdownSeconds;

  int _exhaleStartElapsedSeconds = 0;
  Timer? _acousticGiveUpTimer;

  // Mic sensitivity/AGC behavior varies a lot across phones — if an exhale
  // genuinely hasn't been detected within this long, something about this
  // device/environment isn't cooperating with acoustic detection for this
  // attempt. Rather than leave the user watching a timer that never
  // auto-finishes, give up on the mic for this attempt and fall back to the
  // plain manual tap-to-finish flow that has always been available.
  static const Duration _acousticGiveUpAfter = Duration(seconds: 12);

  // Slow, continuous scale/glow pulse while an attempt is running — a
  // calming "breathing" visual anchor, not a paced inhale/hold/exhale
  // sequence (the test itself is open-ended: the user decides when their
  // hold+exhale is done by tapping "Nefes Aldım", so there's no fixed
  // cycle length to animate against).
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  // Runs once, forward, for the duration of the active exhale step — a
  // slow big-to-small shrink of the inner disc, not a loop. Chosen
  // duration is just a reasonable ceiling for how long a real exhale
  // takes; if the attempt finishes before it completes (the usual case),
  // it's simply reset without ever having reached the end.
  late final AnimationController _exhaleShrinkController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  // Drives the sit-relax/deep-breath steps' breathing circle — a slow
  // grow/shrink loop the user can visually follow along with, since those
  // two steps otherwise had no animation at all (just a static icon and a
  // button). Same controller for both steps; deepBreath just reads a wider
  // scale range off it to read as a bigger, more deliberate breath. Only
  // ever running while one of those two steps is actually active (started
  // in _startCurrentTest, stopped in _advanceFromDeepBreath) — an
  // always-on repeat here would never let widget tests' pumpAndSettle()
  // settle.
  late final AnimationController _stepBreathController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  // Repeating outward "wind" rings during the exhale step, layered with
  // the existing one-shot shrinking disc — a visual echo of air actually
  // moving out toward the microphone, not just a countdown.
  late final AnimationController _exhaleWaveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    _breathTestService = widget.breathTestService ?? BreathTestService();
    _breathAudioService = widget.breathAudioService ?? BreathAudioService();
    _breathNoiseCheckService =
        widget.breathNoiseCheckService ?? BreathNoiseCheckService();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _acousticGiveUpTimer?.cancel();
    _noiseCheckTimer?.cancel();
    _pulseController.dispose();
    _exhaleShrinkController.dispose();
    _stepBreathController.dispose();
    _exhaleWaveController.dispose();
    _breathAudioService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isRunning &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden)) {
      _wasBackgroundedDuringAttempt = true;
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _wasBackgroundedDuringAttempt &&
        _isRunning) {
      _wasBackgroundedDuringAttempt = false;
      _discardCurrentAttempt(context.t('breathAttemptDiscardedBackgrounded'));
    }
  }

  void _discardCurrentAttempt(String message) {
    _stopwatch
      ..stop()
      ..reset();
    _timer?.cancel();
    _acousticGiveUpTimer?.cancel();
    _noiseCheckTimer?.cancel();
    _pulseController.stop();
    _exhaleShrinkController.reset();
    _exhaleWaveController.stop();
    _stepBreathController.stop();
    unawaited(_breathAudioService.stopListening());
    _currentAttemptSamples.clear();
    _acousticListeningActive = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _isRunning = false;
      _step = _AttemptStep.notStarted;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Step 1 of 4: begins an attempt — nothing is measured yet during this
  /// step, the user just reads the instruction and taps Devam when ready.
  ///
  /// The microphone permission is requested right here — the first moment
  /// the user is actually looking at the breath-test screen and can see
  /// why it's needed — rather than in a bulk onboarding prompt with no
  /// context. Declining doesn't block the test: it just means acoustic
  /// exhale detection stays off and the manual tap-to-finish flow is used
  /// instead, same as it always could be.
  void _startCurrentTest() {
    if (_isResting) {
      return;
    }
    SystemSound.play(SystemSoundType.click);
    _autoFinishing = false;
    _currentAttemptIsNoisy = false;
    setState(() {
      _isRunning = true;
      _step = _AttemptStep.sitRelax;
    });
    _stepBreathController.repeat(reverse: true);
    unawaited(_prepareMicrophoneForAttempt());
    _scheduleAmbientNoiseCheck();
  }

  // Product spec: listen to the room for 2-3s before the attempt actually
  // starts. Sit-relax is the one stretch of an attempt where the user is
  // deliberately not breathing hard yet (unlike deep-breath or the hold),
  // which makes it the honest ambient window — so this reads from whatever
  // _currentAttemptSamples has accumulated since the mic started in
  // _prepareMicrophoneForAttempt, rather than opening a second concurrent
  // recording session (BreathAudioService only supports one at a time).
  static const Duration _ambientNoiseCheckWindow = Duration(
    milliseconds: 2500,
  );

  void _scheduleAmbientNoiseCheck() {
    _noiseCheckTimer?.cancel();
    _noiseCheckTimer = Timer(_ambientNoiseCheckWindow, () {
      unawaited(_runAmbientNoiseCheck());
    });
  }

  Future<void> _runAmbientNoiseCheck() async {
    if (!mounted || _step != _AttemptStep.sitRelax) {
      // Already moved on (the user tapped Devam quickly, or the attempt
      // was discarded) — the sit-relax window this check relies on being
      // quiet no longer applies, so skip rather than evaluate stale
      // samples.
      return;
    }
    if (_currentAttemptSamples.isEmpty) {
      // Mic never started (permission denied/platform error) — nothing to
      // check, same as any other best-effort acoustic feature on this page.
      return;
    }

    final result = await _breathNoiseCheckService.evaluatePreTestSamples(
      List.of(_currentAttemptSamples),
    );
    if (!mounted || _step != _AttemptStep.sitRelax) {
      return;
    }

    if (result.level == NoiseLevel.quiet) {
      return;
    }

    if (result.shouldMarkRecordAsNoisy) {
      _currentAttemptIsNoisy = true;
    }

    final keepGoing = await _showNoiseWarningDialog(result);
    if (!mounted || _step != _AttemptStep.sitRelax) {
      return;
    }
    if (keepGoing == false) {
      _discardCurrentAttempt(context.t('breathNoiseRetry'));
    }
  }

  /// Returns true (continue anyway) or false (retry — discards the attempt
  /// so the user can tap start again in a quieter spot). Never blocks: both
  /// buttons let the user proceed one way or the other, per the product
  /// spec's "asla testi engelleme" rule.
  Future<bool?> _showNoiseWarningDialog(NoiseCheckResult result) {
    final isLoud = result.level == NoiseLevel.loud;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.t(isLoud ? 'breathNoiseLoudTitle' : 'breathNoiseWarningTitle'),
        ),
        content: Text(
          context.t(
            isLoud ? 'breathNoiseLoudMessage' : 'breathNoiseWarningMessage',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('breathNoiseRetry')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('breathNoiseContinueAnyway')),
          ),
        ],
      ),
    );
  }

  Future<void> _prepareMicrophoneForAttempt() async {
    await _ensureMicrophonePermissionWithRationale();
    if (!mounted || _step == _AttemptStep.notStarted) {
      return;
    }
    await _startAcousticListeningForAttempt();
  }

  bool _micPermissionRequested = false;

  Future<void> _ensureMicrophonePermissionWithRationale() async {
    if (_micPermissionRequested) {
      return;
    }
    _micPermissionRequested = true;
    if (await _breathAudioService.hasPermission()) {
      return;
    }
    if (!mounted) {
      return;
    }
    final wantsToGrant = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('micRationaleTitle')),
        content: Text(context.t('micRationaleMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('no')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('yes')),
          ),
        ],
      ),
    );
    if (wantsToGrant == true) {
      await PermissionService.ensureMicrophonePermission();
    }
  }

  /// Step 1 -> Step 2: user tapped Devam on the sit-relax instruction —
  /// still nothing measured yet, just moves to "take a deep breath".
  void _advanceFromSitRelax() {
    if (_step != _AttemptStep.sitRelax) {
      return;
    }
    setState(() {
      _step = _AttemptStep.deepBreath;
    });
  }

  /// Step 2 -> Step 3: user tapped Devam on the deep-breath instruction —
  /// this is the real start of the timed measurement, since the user has
  /// just taken their breath and is now holding it. The mic itself has
  /// already been listening since sit-relax (see
  /// _prepareMicrophoneForAttempt) and deliberately isn't restarted here:
  /// restarting would wipe the calibration samples collected during
  /// sit-relax/deep-breath, throwing away the exact head start this was
  /// meant to give attempt 1.
  void _advanceFromDeepBreath() {
    if (_step != _AttemptStep.deepBreath) {
      return;
    }
    _stopwatch.reset();
    _stopwatch.start();
    _pulseController.repeat(reverse: true);
    _stepBreathController.stop();
    setState(() {
      _step = _AttemptStep.holding;
      _holdCountdownSecondsLeft = _holdCountdownSeconds;
    });
    _startHoldCountdown();
  }

  void _startHoldCountdown() {
    // Drop everything captured before the hold. Up to here the attempt has
    // been anything but quiet — the user was told to sit down, then to take a
    // deep breath in, and that inhale is loud. Leaving it in the buffer meant
    // the noise floor was measured off it (so the threshold sat far above any
    // real exhale, and detection never fired) or it was itself read as an
    // exhale onset. The hold is the one stretch where the user is
    // deliberately silent, which makes it the honest baseline.
    _currentAttemptSamples.clear();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _holdCountdownSecondsLeft -= 1;
      });
      if (_holdCountdownSecondsLeft <= 0) {
        timer.cancel();
        _advanceToExhale();
      }
    });
  }

  /// The hold countdown has elapsed — moves straight into the exhale step,
  /// no tap required (the hold's fixed duration already told the user
  /// exactly when this would happen).
  void _advanceToExhale() {
    if (!mounted || _step != _AttemptStep.holding) {
      return;
    }
    // The hold's samples (up to this exact moment) are the one genuinely
    // quiet stretch during the actual measurement — a mid-attempt "did
    // someone start talking" check, mirroring the pre-test ambient check
    // above but without persisting a new baseline from it (see
    // BreathNoiseCheckService.evaluateDuringAttempt's doc comment for why).
    // Fire-and-forget: by the time exhale detection/finish runs, this will
    // long since have resolved into _currentAttemptIsNoisy.
    unawaited(_checkNoiseDuringHold(List.of(_currentAttemptSamples)));
    setState(() {
      _step = _AttemptStep.exhale;
      // The stopwatch itself keeps running continuously from the start of
      // the hold (holdDuration/blowDuration are still derived from that
      // one unbroken measurement, unchanged) — this is purely what's put
      // on screen, so the circle visibly restarts at 0 for the exhale
      // phase instead of confusingly showing several seconds already
      // elapsed.
      _exhaleStartElapsedSeconds = _stopwatch.elapsed.inSeconds;
    });
    _exhaleShrinkController
      ..stop()
      ..forward(from: 0);
    _exhaleWaveController.repeat();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    if (_acousticListeningActive) {
      _acousticGiveUpTimer?.cancel();
      _acousticGiveUpTimer = Timer(_acousticGiveUpAfter, _giveUpOnAcoustic);
    }
  }

  /// Evaluates the hold's quiet-window samples against the device's noise
  /// reference and flags the in-progress attempt if it comes back loud
  /// (someone started talking, a door slammed, etc.) — silent otherwise, on
  /// the same "never block the test" rule the pre-test check follows. Never
  /// shows a dialog here (unlike the pre-test check): interrupting mid-hold
  /// would be far more disruptive than just quietly marking the record.
  Future<void> _checkNoiseDuringHold(
    List<BreathAcousticSample> holdSamples,
  ) async {
    if (holdSamples.isEmpty) {
      return;
    }
    final result = await _breathNoiseCheckService.evaluateDuringAttempt(
      holdSamples,
    );
    if (!mounted || !result.shouldMarkRecordAsNoisy) {
      return;
    }
    _currentAttemptIsNoisy = true;
  }

  /// Best-effort: if the microphone isn't available (permission denied,
  /// platform error), [_acousticListeningActive] just stays false and
  /// every attempt behaves exactly like the manual-tap flow always has.
  Future<void> _startAcousticListeningForAttempt() async {
    _currentAttemptSamples.clear();
    // Guards against back-to-back calls (finishing one attempt's listening
    // session and starting the next one's, e.g. into the rest countdown)
    // racing the recorder plugin's own stop/start handling.
    await _breathAudioService.stopListening();
    final started = await _breathAudioService.startListening(
      _handleAcousticSample,
    );
    if (!mounted) {
      return;
    }
    _acousticListeningActive = started;
    if (started && _step == _AttemptStep.exhale) {
      // Attempt already reached the exhale step by the time the mic
      // finished starting up — start the give-up clock now instead of
      // waiting for _advanceToExhale (which already ran).
      _acousticGiveUpTimer?.cancel();
      _acousticGiveUpTimer = Timer(_acousticGiveUpAfter, _giveUpOnAcoustic);
    }
  }

  /// Called when acoustic detection hasn't found a full exhale within
  /// [_acousticGiveUpAfter] of this attempt starting. Stops the mic (no
  /// point burning battery/CPU on samples nothing is using anymore) and
  /// switches the on-screen hint back to the plain manual tap instruction —
  /// the attempt keeps running exactly as it always could before Phase 8.
  void _giveUpOnAcoustic() {
    if (!mounted ||
        !_isRunning ||
        _autoFinishing ||
        !_acousticListeningActive) {
      return;
    }
    unawaited(_breathAudioService.stopListening());
    setState(() {
      _acousticListeningActive = false;
    });
  }

  /// Runs on every live energy reading while an attempt is in progress.
  /// Samples are collected starting from sit-relax (the mic is listening
  /// that early — see _prepareMicrophoneForAttempt) all the way through,
  /// but an exhale is only ever *acted on* once the exhale step has
  /// actually begun — otherwise a stray noise during an earlier step could
  /// end the attempt before the user was even told to exhale.
  void _handleAcousticSample(BreathAcousticSample sample) {
    // Attempts 2 and 3 skip straight to exhale (see
    // _beginAutoMeasuredAttempt), so the preceding rest countdown is their
    // only quiet window to calibrate a baseline from — samples need to
    // keep accumulating through it or the first real exhale samples end up
    // mistaken for the baseline itself.
    final isCollectingStep =
        _step == _AttemptStep.sitRelax ||
        _step == _AttemptStep.deepBreath ||
        _step == _AttemptStep.holding ||
        _step == _AttemptStep.exhale ||
        _isResting;
    if (!isCollectingStep || _autoFinishing) {
      return;
    }
    _currentAttemptSamples.add(sample);

    if (_step != _AttemptStep.exhale) {
      // Still just building the calibration baseline (hold countdown or
      // inter-attempt rest) — only the real exhale step should ever be
      // allowed to finish the attempt, same as before.
      return;
    }
    final analysis = _breathAcousticEngine.analyze(_currentAttemptSamples);
    if (analysis.exhaleDetected) {
      _autoFinishing = true;
      final totalMs =
          (analysis.holdDurationMs ?? 0) + (analysis.blowDurationMs ?? 0);
      _finishAttempt(seconds: (totalMs / 1000).round(), acoustic: analysis);
    }
  }

  void _handleBreathPressed() {
    if (_step != _AttemptStep.exhale || _autoFinishing) {
      return;
    }
    _autoFinishing = true;
    final seconds = _stopwatch.elapsed.inSeconds;
    final acoustic = _currentAttemptSamples.isEmpty
        ? null
        : _breathAcousticEngine.analyze(_currentAttemptSamples);
    _finishAttempt(seconds: seconds, acoustic: acoustic);
  }

  void _finishAttempt({
    required int seconds,
    required BreathAcousticAnalysis? acoustic,
  }) {
    if (!mounted || !_isRunning) {
      return;
    }

    SystemSound.play(SystemSoundType.click);
    _stopwatch.stop();
    _timer?.cancel();
    _acousticGiveUpTimer?.cancel();
    _pulseController.stop();
    _exhaleShrinkController.reset();
    _exhaleWaveController.stop();
    _stepBreathController.stop();
    unawaited(_breathAudioService.stopListening());
    _acousticListeningActive = false;

    if (seconds > _maxPlausibleSeconds) {
      setState(() {
        _isRunning = false;
        _step = _AttemptStep.notStarted;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.t('breathAttemptImplausible'))),
        );
      return;
    }

    setState(() {
      _isRunning = false;
      _step = _AttemptStep.notStarted;
    });
    _attemptSeconds.add(seconds);
    _attemptAcousticResults.add(
      (acoustic != null && acoustic.exhaleDetected) ? acoustic : null,
    );
    _attemptNoiseFlags.add(_currentAttemptIsNoisy);
    _currentAttemptIsNoisy = false;
    if (acoustic != null &&
        acoustic.exhaleDetected &&
        acoustic.holdDurationMs != null &&
        acoustic.blowDurationMs != null) {
      _lastSpirometryEstimate = _breathAcousticEngine.estimateSpirometry(
        _currentAttemptSamples,
        acoustic.holdDurationMs!,
        acoustic.holdDurationMs! + acoustic.blowDurationMs!,
      );
    }

    _recordAttemptFeedback(
      seconds: seconds,
      stability: acoustic?.blowStability,
      intensity: acoustic?.blowIntensity,
    );

    if (_attemptSeconds.length >= _requiredAttemptCount) {
      unawaited(_navigateToResult());
      return;
    }

    _startRestInterval();
  }

  /// Ürünün istediği "gerçek zamanlı geri bildirim" — her denemenin hemen
  /// ardından, kısa ve cesaretlendirici bir öneri (bkz. BreathFeedbackEngine).
  /// Akustik okuma yoksa (mikrofon yoktu/algılama başarısız oldu)
  /// stability/intensity için BreathTestEngine'in aynı zayıf-sinyal
  /// tahminleri kullanılır — bu, _saveBreathProgressRecord'un zaten
  /// kullandığı fallback ile aynı mantık.
  void _recordAttemptFeedback({
    required int seconds,
    double? stability,
    double? intensity,
  }) {
    final resolvedStability =
        stability ?? _breathTestEngine.estimateBlowStabilityFromAttempts(_attemptSeconds);
    final resolvedIntensity = intensity ??
        _breathTestEngine.estimateBlowIntensity(
          holdDuration: seconds.toDouble(),
          blowDuration: seconds.toDouble(),
        );
    final score = _breathTrendEngine.computeScore(
      blowDurationSeconds: seconds.toDouble(),
      blowStability: resolvedStability,
      blowIntensity: resolvedIntensity,
    );
    final previousScore = _attemptScores.isEmpty ? null : _attemptScores.last;
    _attemptScores.add(score);

    _lastAttemptFeedback = _breathFeedbackEngine.buildFeedback(
      blowDurationSeconds: seconds.toDouble(),
      blowStability: resolvedStability,
      blowIntensity: resolvedIntensity,
      currentScore: score,
      previousScore: previousScore,
    );
  }

  void _startRestInterval() {
    _timer?.cancel();
    setState(() {
      _isResting = true;
      _restSecondsLeft = 20;
    });

    // Mic listens through the entire rest period — plenty of genuine
    // quiet time for calibration well before the next attempt's exhale
    // begins.
    unawaited(_startAcousticListeningForAttempt());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _restSecondsLeft -= 1;
      });

      if (_restSecondsLeft <= 0) {
        timer.cancel();
        _beginNextAttemptAfterRest();
      }
    });
  }

  /// Starts the next attempt the instant the rest countdown reaches zero —
  /// no tap needed. Only the very first attempt needs a deliberate tap to
  /// begin; every attempt after that starts on its own once the rest
  /// period is over, same as before.
  void _beginNextAttemptAfterRest() {
    if (!mounted || _isRunning) {
      return;
    }
    setState(() {
      _isResting = false;
      _currentTest = _attemptSeconds.length + 1;
    });
    _beginAutoMeasuredAttempt();
  }

  /// Attempts 2 and 3 run the same sit-relax → deep-breath → hold → exhale
  /// sequence attempt 1 does.
  ///
  /// They used to jump straight to the exhale. That made the three attempts
  /// measure different things — only attempt 1 included a hold — and it also
  /// meant the on-screen figure and the step instructions, which live in
  /// those earlier steps, simply never appeared after the first attempt. The
  /// only thing still special about attempt 1 is that a tap starts it; the
  /// rest interval starts these on its own.
  void _beginAutoMeasuredAttempt() {
    _autoFinishing = false;
    setState(() {
      _isRunning = true;
      _step = _AttemptStep.sitRelax;
    });
    _stepBreathController.repeat(reverse: true);
  }

  /// Builds the user-facing [BreathProgressRecord] BreathTrendEngine
  /// consumes for the progress/analysis page, and persists it — separate
  /// from [_breathTestService.processBreathTest] above, which saves the
  /// risk engine's own internal [BreathTestResult] representation.
  ///
  /// Per-attempt score uses [BreathTrendEngine.computeScore] on each
  /// attempt's own duration/stability/intensity, then takes the *median*
  /// across all 3 attempts (not the best) — a single lucky attempt
  /// shouldn't set the recorded score. The record's duration/stability/
  /// intensity fields are taken from whichever attempt produced the median
  /// score, so they describe one real attempt rather than an average that
  /// never actually happened.
  Future<void> _saveBreathProgressRecord() async {
    if (_attemptSeconds.isEmpty) {
      return;
    }
    final attempts = <({double score, int seconds, double stability, double intensity})>[];
    for (var i = 0; i < _attemptSeconds.length; i++) {
      final acoustic = i < _attemptAcousticResults.length
          ? _attemptAcousticResults[i]
          : null;
      final stability = (acoustic != null && acoustic.exhaleDetected)
          ? acoustic.blowStability!
          : _breathTestEngine.estimateBlowStabilityFromAttempts(_attemptSeconds);
      final intensity = (acoustic != null && acoustic.exhaleDetected)
          ? acoustic.blowIntensity!
          : _breathTestEngine.estimateBlowIntensity(
              holdDuration: _attemptSeconds[i].toDouble(),
              blowDuration: _attemptSeconds[i].toDouble(),
            );
      final score = _breathTrendEngine.computeScore(
        blowDurationSeconds: _attemptSeconds[i].toDouble(),
        blowStability: stability,
        blowIntensity: intensity,
      );
      attempts.add((
        score: score,
        seconds: _attemptSeconds[i],
        stability: stability,
        intensity: intensity,
      ));
    }

    final sortedByScore = [...attempts]..sort((a, b) => a.score.compareTo(b.score));
    final medianAttempt = sortedByScore[sortedByScore.length ~/ 2];
    final medianScore = _breathTrendEngine.medianOfAttemptScores(
      attempts.map((a) => a.score).toList(),
    );

    final isNoisy = _attemptNoiseFlags.any((flagged) => flagged);
    final now = DateTime.now();

    await StorageService().saveBreathProgressRecord(
      BreathProgressRecord(
        id: 'breath_progress_${now.microsecondsSinceEpoch}',
        completedAt: now,
        breathScore: medianScore,
        blowDurationSeconds: medianAttempt.seconds.toDouble(),
        blowStability: medianAttempt.stability,
        blowIntensity: medianAttempt.intensity,
        isNoisyEnvironment: isNoisy,
      ),
    );
  }

  Future<void> _navigateToResult() async {
    try {
      final sorted = [..._attemptSeconds]..sort((a, b) => b.compareTo(a));
      final bestSeconds = sorted.first;
      final averageSeconds =
          (_attemptSeconds.reduce((a, b) => a + b) / _attemptSeconds.length)
              .round();

      final acousticResults = _attemptAcousticResults;
      final hasFullAcousticReading =
          acousticResults.length == 3 &&
          acousticResults.every((a) => a != null && a.exhaleDetected);

      final double blowStability;
      final double blowIntensity;
      if (hasFullAcousticReading) {
        blowStability =
            acousticResults
                .map((a) => a!.blowStability!)
                .reduce((a, b) => a + b) /
            acousticResults.length;
        blowIntensity =
            acousticResults
                .map((a) => a!.blowIntensity!)
                .reduce((a, b) => a + b) /
            acousticResults.length;
      } else {
        blowStability = _breathTestEngine.estimateBlowStabilityFromAttempts(
          _attemptSeconds,
        );
        blowIntensity = _breathTestEngine.estimateBlowIntensity(
          holdDuration: bestSeconds.toDouble(),
          blowDuration: averageSeconds.toDouble(),
        );
      }

      final spirometry = hasFullAcousticReading ? _lastSpirometryEstimate : null;
      final processed = await _breathTestService.processBreathTest(
        name: widget.name,
        packsPerDay: widget.packsPerDay,
        holdDuration: bestSeconds.toDouble(),
        blowDuration: averageSeconds.toDouble(),
        blowStability: blowStability,
        blowIntensity: blowIntensity,
        spirometry: spirometry,
        title: context.t('breathTestRecordTitle'),
      );

      unawaited(_saveBreathProgressRecord());

      if (!mounted) {
        return;
      }

      if (widget.navigateToHomeOnComplete) {
        await _openHomeOrWeekly(
          finalRiskScore: processed.finalRiskScore,
          finalRiskLevel: processed.finalRiskLevel,
          bestSeconds: bestSeconds,
          averageSeconds: averageSeconds,
        );
        return;
      }

      if (spirometry != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BreathSpirometryResultPage(
              name: widget.name,
              riskScore: processed.finalRiskScore,
              riskLevel: processed.finalRiskLevel,
              spirometry: spirometry,
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RiskResultPage(
            name: widget.name,
            riskScore: processed.finalRiskScore,
            riskLevel: processed.finalRiskLevel,
            packsPerDay: widget.packsPerDay,
            exhaleTestSeconds: bestSeconds,
            inhaleTestSeconds: averageSeconds,
            showBreathDisclaimer: true,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[BreathTestPage] Failed to process breath test: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Nefes testi sonucu kaydedilemedi. Lutfen tekrar deneyin.',
            ),
          ),
        );
    }
  }

  Future<void> _openHomeOrWeekly({
    required int finalRiskScore,
    required String finalRiskLevel,
    required int bestSeconds,
    required int averageSeconds,
  }) async {
    if (!mounted) {
      return;
    }

    // Not just "the caller asked for this" — the weekly survey should only
    // ever be offered here once it's actually due (7+ days since the last
    // weekly-or-initial survey). Without this check it was firing on every
    // single daily/re-entry breath test, including the very first one
    // right after onboarding, when a week obviously hasn't passed yet.
    final weeklySurveyDue =
        widget.askWeeklySurveyOnComplete &&
        await StorageService().isWeeklySurveyOverdue();
    if (!mounted) {
      return;
    }

    if (weeklySurveyDue) {
      final wantsWeeklySurvey = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(context.t('weeklySurvey')),
            content: Text(context.t('weeklySurveyPromptAsk')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.t('no')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.t('yes')),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      if (wantsWeeklySurvey == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WeeklySurveyPage(
              navigateToHomeAfterSave: true,
              nameSeed: widget.name,
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RiskResultPage(
            name: widget.name,
            riskScore: finalRiskScore,
            riskLevel: finalRiskLevel,
            packsPerDay: widget.packsPerDay,
            exhaleTestSeconds: bestSeconds,
            inhaleTestSeconds: averageSeconds,
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(
          name: widget.name,
          riskScore: finalRiskScore,
          riskLevel: finalRiskLevel,
        ),
      ),
    );
  }

  // Rest interval starts at 20s and counts down — the first
  // _feedbackDisplaySeconds of it show the just-finished attempt's
  // BreathFeedbackEngine message instead of the rest instruction, then it
  // switches over. Kept short: this is a quick between-attempts nudge, not
  // something the user needs to read carefully.
  static const int _feedbackDisplaySeconds = 2;

  String _getInstruction() {
    if (_isResting) {
      final feedback = _lastAttemptFeedback;
      final showingFeedback = feedback != null &&
          _restSecondsLeft > 20 - _feedbackDisplaySeconds;
      if (showingFeedback) {
        return context.t(feedback.messageKey);
      }
      return context.t('breathAutoNextAttemptInstruction');
    }
    switch (_step) {
      case _AttemptStep.notStarted:
        return '';
      case _AttemptStep.sitRelax:
        return context.t('breathStepSitRelax');
      case _AttemptStep.deepBreath:
        return context.t('breathStepDeepBreath');
      case _AttemptStep.holding:
        return context.t('breathStepHold');
      case _AttemptStep.exhale:
        return '${context.t('breathStepExhale')} ${context.t('breathStepExhaleFinishHint')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSeconds = _isResting
        ? _restSecondsLeft
        : (_step == _AttemptStep.holding
              ? _holdCountdownSecondsLeft
              : _stopwatch.elapsed.inSeconds - _exhaleStartElapsedSeconds);

    // Two clear regions instead of a scrolling stack of separate cards: a
    // big, centered breathing animation on top (the thing to look at and
    // breathe along with) and instruction text + the step's action button
    // below it (the thing to read and act on). SafeArea + a minimum-height
    // scroll fallback keeps this from overflowing on short screens without
    // reintroducing the old scattered card layout on tall ones.
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(context.t('breathTestPageTitle')),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildProgressIndicator(),
                      Expanded(
                        // notStarted has nothing below the circle anymore —
                        // "BAŞLA" moved inside it and there's no instruction
                        // text yet, so give it the whole remaining height
                        // instead of the usual 6:4 split, which otherwise
                        // left the circle sitting high with a dead empty
                        // region underneath instead of centered on screen.
                        flex: _step == _AttemptStep.notStarted ? 10 : 6,
                        child: Center(
                          child: _buildBreathingCircle(
                            currentSeconds,
                            constraints.maxWidth,
                          ),
                        ),
                      ),
                      if (_step != _AttemptStep.notStarted)
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: _buildInstructionText(context),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildStepActionButton(context),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final testNumber = index + 1;
          final isCompleted = testNumber < _currentTest;
          final isCurrent = testNumber == _currentTest;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isCompleted || isCurrent
                      ? AppTheme.brandPrimary
                      : const Color(0xFF132238),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: AppTheme.brandPrimary.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : const [],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Talimat metni + disclaimer — artık ayrı bir Card/grafik taşımıyor,
  /// grafik üstteki nefes dairesine taşındı. Adım değişince fade+slide ile
  /// geçiş yapmaya devam eder.
  Widget _buildInstructionText(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: (_step == _AttemptStep.notStarted && !_isResting)
          ? const SizedBox.shrink(key: ValueKey('no_instruction'))
          : Column(
              key: ValueKey('${_isResting}_$_step'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getInstruction(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.t('breathExerciseDisclaimer'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
    );
  }

  /// Adımın aksiyonunu üstlenen büyük buton. sitRelax/deepBreath kullanıcının
  /// kendi hızında "Devam" tuşuyla ilerler; holding sabit sayaçla otomatik
  /// exhale'e geçer (tıklanacak bir şey yok); exhale'i elle bitirme her zaman
  /// görünür kalır — otomatik algılama çalışmazsa her zaman var olan
  /// elle-bitirme yolu. notStarted (ilk giriş) burada ayrıca render edilmiyor
  /// — o durumda "BAŞLA" tıklaması nefes dairesinin kendisine taşındı (bkz.
  /// [_buildBreathingCircle]), tek bir tıklanabilir alan olsun diye; ayrı bir
  /// buton burada tekrar göstermek çift kontrol yaratırdı.
  Widget _buildStepActionButton(BuildContext context) {
    if (_step == _AttemptStep.notStarted) {
      return const SizedBox(height: 56);
    }

    final VoidCallback? onPressed = switch (_step) {
      _ when _isResting => null,
      _AttemptStep.exhale => _handleBreathPressed,
      _AttemptStep.notStarted => _startCurrentTest,
      _AttemptStep.sitRelax => _advanceFromSitRelax,
      _AttemptStep.deepBreath => _advanceFromDeepBreath,
      // The hold countdown itself is fixed — nothing to tap, it advances
      // to exhale on its own once it reaches zero.
      _AttemptStep.holding => null,
    };

    if (_isResting || _step == _AttemptStep.holding) {
      return const SizedBox(height: 56);
    }

    final label = switch (_step) {
      _AttemptStep.notStarted => context.t('start'),
      _ => context.t('breathStepOkAction'),
    };

    // breath_timer_circle stays on the button itself across every step —
    // tests tap this one key throughout the whole flow.
    final button = FilledButton(
      key: const ValueKey('breath_timer_circle'),
      onPressed: onPressed,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
    );

    return SizedBox(width: double.infinity, height: 56, child: button);
  }

  /// Büyük, ekranın çoğunu kaplayan ortalanmış nefes animasyonu — artık
  /// tıklanabilir değil (aksiyon `_buildStepActionButton`'a taşındı),
  /// sadece o anki adımı görsel olarak anlatır. Tüm scale/opacity geçişleri
  /// `Curves.easeInOutSine` ile yumuşatılmış — doğal nefes ritmine yakın,
  /// önceki lineer okumaların "acemi" hissinin yerini alıyor.
  Widget _buildBreathingCircle(int seconds, double availableWidth) {
    final isResting = _isResting;
    final isIdle = !_isRunning && !isResting;
    final isSitRelax = _step == _AttemptStep.sitRelax;
    final isDeepBreath = _step == _AttemptStep.deepBreath;
    final isExhaling = _step == _AttemptStep.exhale;
    final accentColor = isResting
        ? const Color(0xFFFFB74D)
        : AppTheme.brandPrimary;
    final diameter = availableWidth <= 0
        ? 260.0
        : (availableWidth * 0.72).clamp(200.0, 300.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([
            _pulseController,
            _exhaleShrinkController,
            _stepBreathController,
            _exhaleWaveController,
          ]),
          builder: (context, child) {
            double eased(Animation<double> controller) =>
                Curves.easeInOutSine.transform(controller.value);

            // A slow, continuous scale+glow pulse while an attempt is
            // running — not paced to any fixed inhale/hold/exhale timing
            // (the test is open-ended), just a calming "still breathing,
            // still holding" visual anchor. Static (no pulse) when idle or
            // resting. Held off during sitRelax/deepBreath, which drive
            // their own bigger breathing animation instead (see below), and
            // during the hold countdown itself — held breath, no motion —
            // so the "held still" moment reads as visually distinct from
            // the steps either side of it.
            final ambientPulseActive =
                _isRunning &&
                !isSitRelax &&
                !isDeepBreath &&
                _step != _AttemptStep.holding;
            final pulse = ambientPulseActive ? eased(_pulseController) : 0.0;
            var scale = 1.0 + (pulse * 0.04);
            final glowAlpha = isIdle ? 0.0 : 0.08 + (pulse * 0.14);

            // Sit-relax / deep-breath: a slow grow-shrink loop the user can
            // visually breathe along with. Deep-breath uses a much wider
            // range to read as one deliberate, bigger breath rather than
            // sit-relax's gentle resting rhythm.
            if (isSitRelax) {
              scale = 0.90 + (eased(_stepBreathController) * 0.10);
            } else if (isDeepBreath) {
              scale = 0.78 + (eased(_stepBreathController) * 0.30);
            }

            // While actively exhaling, an inner disc slowly shrinks — a
            // visual echo of the breath itself running out, on top of (not
            // instead of) the numeric seconds count.
            final exhaleShrinkScale =
                1.0 - (eased(_exhaleShrinkController) * 0.85);

            final circleContent = Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Outward "wind" rings while exhaling — three
                  // staggered rings expanding toward the edge and
                  // fading out, echoing air actually moving out of
                  // frame.
                  if (isExhaling) ..._exhaleWindRings(accentColor),
                  if (isExhaling)
                    Transform.scale(
                      scale: exhaleShrinkScale.clamp(0.12, 1.0),
                      child: Container(
                        width: diameter * 0.89,
                        height: diameter * 0.89,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.28),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.9),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  if (isExhaling)
                    // The phone/mic guide from the old instruction card,
                    // now centered inside the breathing circle itself
                    // instead of a separate small card graphic.
                    SizedBox(
                      width: diameter * 0.24,
                      height: diameter * 0.28,
                      child: CustomPaint(
                        painter: _PhoneMicPainter(
                          color: accentColor,
                          pulse: eased(_exhaleWaveController),
                        ),
                      ),
                    )
                  else if (isIdle)
                    // "BAŞLA" now lives inside the circle itself — the
                    // whole circle is the tappable start control (see the
                    // InkWell wrapper below), so there is exactly one
                    // control to start a test rather than a separate
                    // button underneath duplicating it.
                    Text(
                      context.t('start').toUpperCase(),
                      style: TextStyle(
                        fontSize: diameter * 0.11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: accentColor.withValues(alpha: 0.95),
                      ),
                    )
                  else if (isSitRelax || isDeepBreath)
                    // A simple nested-circle breathing indicator instead
                    // of a stock Material figure icon — the inner disc
                    // grows/shrinks with the same controller already
                    // driving the outer circle's scale, so what's asked
                    // for in the instruction text ("nefes alın") is
                    // shown, not just described.
                    Transform.scale(
                      scale: isSitRelax
                          ? 0.6 + (eased(_stepBreathController) * 0.25)
                          : 0.45 + (eased(_stepBreathController) * 0.45),
                      child: Container(
                        width: diameter * 0.4,
                        height: diameter * 0.4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.22),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.75),
                            width: 2,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      seconds.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: diameter * 0.22,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: accentColor.withValues(
                          alpha: isExhaling ? 0.55 : 0.85,
                        ),
                        letterSpacing: 2,
                      ),
                    ),
                ],
              ),
            );

            final circleDecoration = BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accentColor.withValues(alpha: isIdle ? 0.16 : 0.26),
                  const Color(0xFF132238),
                ],
                stops: const [0.0, 1.0],
              ),
              border: Border.all(
                color: accentColor.withValues(alpha: isIdle ? 0.35 : 0.55),
                width: 2,
              ),
              boxShadow: glowAlpha > 0
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: glowAlpha),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ]
                  : const [],
            );

            final circle = isIdle
                ? Material(
                    key: const ValueKey('breath_timer_circle'),
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _startCurrentTest,
                      child: Container(
                        width: diameter,
                        height: diameter,
                        decoration: circleDecoration,
                        child: circleContent,
                      ),
                    ),
                  )
                : Container(
                    width: diameter,
                    height: diameter,
                    decoration: circleDecoration,
                    child: circleContent,
                  );

            return Transform.scale(scale: scale, child: circle);
          },
        ),
        const SizedBox(height: 14),
        Text(
          // Resting already shows its countdown on the big circle above —
          // no need to repeat the same number again in smaller text below.
          (!isResting && _step == _AttemptStep.exhale)
              ? context.t(
                  _acousticListeningActive
                      ? 'breathListeningHint'
                      : 'tapCircleToFinish',
                )
              : '',
          style: const TextStyle(fontSize: 13, color: Colors.white54),
        ),
      ],
    );
  }

  /// Three rings, evenly staggered a third of a cycle apart so a new one is
  /// always starting as another fades out — each expands outward from the
  /// mic icon and fades, standing in for air visibly leaving toward the
  /// microphone rather than just a countdown ticking.
  List<Widget> _exhaleWindRings(Color accentColor) {
    return List.generate(3, (i) {
      final phase = (_exhaleWaveController.value + (i / 3)) % 1.0;
      final radius = 40.0 + (phase * 68.0);
      final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.5;
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: accentColor.withValues(alpha: opacity),
            width: 2,
          ),
        ),
      );
    });
  }
}

/// A phone outline with the microphone location marked at the bottom edge
/// and small chevrons animating downward toward it, one loop per
/// [pulse] cycle — a literal "blow here" pointer.
class _PhoneMicPainter extends CustomPainter {
  final Color color;
  final double pulse;

  const _PhoneMicPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phoneStroke = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045;

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w * 0.5,
        height: h * 0.86,
      ),
      Radius.circular(w * 0.09),
    );
    canvas.drawRRect(phoneRect, phoneStroke);

    // Microphone location, pulsing.
    final micCenter = Offset(w / 2, h * 0.80);
    canvas.drawCircle(
      micCenter,
      w * 0.045 + (pulse * 0.02 * w),
      Paint()..color = color.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      micCenter,
      w * 0.09 + (pulse * 0.06 * w),
      Paint()
        ..color = color.withValues(alpha: (1 - pulse) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    // Two chevrons animating downward toward the mic.
    for (var i = 0; i < 2; i++) {
      final t = (pulse + (i * 0.5)) % 1.0;
      final y = h * 0.22 + (t * h * 0.42);
      final alpha = (1 - t).clamp(0.0, 1.0) * 0.8;
      final chevronPaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(w / 2 - w * 0.09, y)
        ..lineTo(w / 2, y + h * 0.06)
        ..lineTo(w / 2 + w * 0.09, y);
      canvas.drawPath(path, chevronPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PhoneMicPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.color != color;
  }
}
