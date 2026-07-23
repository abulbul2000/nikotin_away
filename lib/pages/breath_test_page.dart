import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemSound, SystemSoundType;

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../engines/breath_acoustic_engine.dart';
import '../engines/breath_test_engine.dart';
import '../models/breath_acoustic_sample.dart';
import '../services/breath_audio_service.dart';
import '../services/breath_test_service.dart';
import '../services/breath_voice_guide_service.dart';
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
  final BreathVoiceGuideService? breathVoiceGuideService;

  const BreathTestPage({
    super.key,
    this.name = '',
    this.packsPerDay = '1 paketten az',
    this.navigateToHomeOnComplete = false,
    this.askWeeklySurveyOnComplete = false,
    this.breathTestService,
    this.breathAudioService,
    this.breathVoiceGuideService,
  });

  @override
  State<BreathTestPage> createState() => _BreathTestPageState();
}

/// Each attempt walks through these in order: read/hear "sit and relax",
/// tap OK; read/hear "take a deep breath", tap OK (this is when the hold
/// actually begins — the stopwatch and mic both start here, listening
/// through the quiet hold for a clean calibration baseline); a fixed
/// 5-second "hold" countdown runs on its own, no tap needed; then
/// read/hear "exhale now" and the mic auto-detects the exhale (or the user
/// taps the circle/OK button manually if it doesn't). Steps 1-2 are
/// user-paced (a fixed timer can't know whether someone actually finished
/// reading/hearing them yet); the hold step is deliberately timer-paced
/// instead, since "hold for 5 seconds" is a specific duration, not a
/// read-at-your-own-pace instruction.
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

  final Stopwatch _stopwatch = Stopwatch();
  final BreathTestEngine _breathTestEngine = BreathTestEngine();
  final BreathAcousticEngine _breathAcousticEngine = BreathAcousticEngine();
  late final BreathTestService _breathTestService;
  late final BreathAudioService _breathAudioService;
  late final BreathVoiceGuideService _breathVoiceGuideService;
  bool _voiceLanguageReady = false;
  Timer? _timer;
  int _currentTest = 1;
  final List<int> _attemptSeconds = <int>[];
  final List<BreathAcousticSample> _currentAttemptSamples = [];
  // One entry per completed attempt; null means the microphone wasn't
  // available or no exhale could be confidently detected for that attempt —
  // _navigateToResult falls back to the timing-based proxy unless every
  // attempt has a real reading.
  final List<BreathAcousticAnalysis?> _attemptAcousticResults = [];
  bool _isResting = false;
  int _restSecondsLeft = 0;
  bool _restCountdownDone = false;
  bool _restInstructionAnnounced = false;
  bool _isRunning = false;
  bool _wasBackgroundedDuringAttempt = false;
  bool _acousticListeningActive = false;
  bool _autoFinishing = false;
  _AttemptStep _step = _AttemptStep.notStarted;
  static const int _holdCountdownSeconds = 5;
  int _holdCountdownSecondsLeft = _holdCountdownSeconds;
  bool _holdWaitingForStartTap = false;
  int _exhaleStartElapsedSeconds = 0;
  Timer? _holdRetryTimer;
  // Long enough for the user to actually hear "Başlata basın" and react to
  // it — 1 second (an earlier value) wasn't: the TTS phrase itself takes
  // most of that window to finish speaking, so the retry kept firing
  // before anyone had a real chance to tap, and the hold step just looped.
  static const Duration _holdRetryGrace = Duration(seconds: 5);
  Timer? _acousticGiveUpTimer;
  bool _ttsSpeaking = false;
  Timer? _ttsGraceTimer;

  // The phone's own speaker leaks into its mic, so whatever the voice guide
  // is saying would otherwise get analyzed as real signal (and did, before
  // this existed — the "Şimdi nefesinizi verin" cue was getting picked up
  // as the calibration baseline itself, making the threshold impossibly
  // high for the real exhale that followed). This grace period keeps
  // ignoring samples briefly after speech ends too, since the tail/echo
  // doesn't cut off instantly.
  static const Duration _ttsEchoGrace = Duration(milliseconds: 350);

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

  @override
  void initState() {
    super.initState();
    _breathTestService = widget.breathTestService ?? BreathTestService();
    _breathAudioService = widget.breathAudioService ?? BreathAudioService();
    _breathVoiceGuideService =
        widget.breathVoiceGuideService ?? BreathVoiceGuideService();
    _breathVoiceGuideService.onSpeakingStateChanged = _handleTtsSpeakingChanged;
    WidgetsBinding.instance.addObserver(this);
  }

  void _handleTtsSpeakingChanged(bool speaking) {
    _ttsGraceTimer?.cancel();
    if (speaking) {
      _ttsSpeaking = true;
      return;
    }
    _ttsGraceTimer = Timer(_ttsEchoGrace, () {
      _ttsSpeaking = false;
      // If the rest countdown already hit zero while this was still
      // talking, this is what actually kicks off the next attempt.
      _maybeBeginNextAttemptAutomatically();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_voiceLanguageReady) {
      _voiceLanguageReady = true;
      unawaited(
        _breathVoiceGuideService.setLanguage(
          Localizations.localeOf(context).languageCode,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _acousticGiveUpTimer?.cancel();
    _holdRetryTimer?.cancel();
    _ttsGraceTimer?.cancel();
    _pulseController.dispose();
    _exhaleShrinkController.dispose();
    _breathAudioService.dispose();
    _breathVoiceGuideService.dispose();
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
    _holdRetryTimer?.cancel();
    _pulseController.stop();
    _exhaleShrinkController.reset();
    unawaited(_breathAudioService.stopListening());
    unawaited(_breathVoiceGuideService.stop());
    _currentAttemptSamples.clear();
    _acousticListeningActive = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _isRunning = false;
      _step = _AttemptStep.notStarted;
      _holdWaitingForStartTap = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Speaks a step's instruction text. When [appendPressOk] is set, adds
  /// "press OK" as its own spoken sentence afterward — the on-screen text
  /// stays just the instruction itself (the button is visible), but a
  /// spoken cue benefits from explicitly saying what to do next since
  /// the user may not be looking at the screen.
  Future<void> _speakStep(String textKey, {bool appendPressOk = false}) {
    final text = appendPressOk
        ? '${context.t(textKey)} ${context.t('breathStepPressOkVoiceSuffix')}'
        : context.t(textKey);
    return _breathVoiceGuideService.speak(text);
  }

  /// Step 1 of 4: begins an attempt. Just shows/speaks the "sit and relax"
  /// cue — nothing is measured yet, the user advances with the OK button
  /// once they're ready.
  void _startCurrentTest() {
    if (_isResting) {
      return;
    }
    SystemSound.play(SystemSoundType.click);
    _autoFinishing = false;
    setState(() {
      _isRunning = true;
      _step = _AttemptStep.sitRelax;
    });
    unawaited(_speakStep('breathStepSitRelax', appendPressOk: true));
  }

  /// Step 1 -> Step 2: still nothing measured yet — just moves from "sit
  /// and relax" to "take a deep breath".
  void _advanceFromSitRelax() {
    if (_step != _AttemptStep.sitRelax) {
      return;
    }
    SystemSound.play(SystemSoundType.click);
    setState(() {
      _step = _AttemptStep.deepBreath;
    });
    unawaited(_speakStep('breathStepDeepBreath', appendPressOk: true));
  }

  /// Step 2 -> Step 3: this is the real start of the measurement — the
  /// user has just taken their breath and is now holding it, so the
  /// stopwatch and the mic both start right here. The mic starting now
  /// (rather than only once the exhale step begins) is deliberate: the
  /// 5-second hold is genuinely quiet, so it doubles as an excellent
  /// calibration window before the exhale cue is even spoken.
  void _advanceFromDeepBreath() {
    if (_step != _AttemptStep.deepBreath) {
      return;
    }
    SystemSound.play(SystemSoundType.click);
    _stopwatch.reset();
    _stopwatch.start();
    _pulseController.repeat(reverse: true);
    setState(() {
      _step = _AttemptStep.holding;
      _holdWaitingForStartTap = false;
      _holdCountdownSecondsLeft = _holdCountdownSeconds;
    });
    unawaited(_speakStep('breathStepHold'));
    unawaited(_startAcousticListeningForAttempt());
    _startHoldCountdown();
  }

  void _startHoldCountdown() {
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
        _promptHoldStartTap();
      }
    });
  }

  /// The 5-second hold has elapsed. Rather than silently auto-advancing,
  /// this reveals the "Başlat" button and asks the user to actively
  /// confirm they're ready to exhale — if they don't tap within
  /// [_holdRetryGrace], the hold likely wasn't real (app backgrounded,
  /// phone set down, etc.), so the countdown resets and tries again rather
  /// than barreling into the exhale step with nobody there. The
  /// instruction text itself ("hold for 5 seconds and press Start") was
  /// already said in full up front — nothing new to say here, the button
  /// appearing is cue enough.
  void _promptHoldStartTap() {
    if (!mounted || _step != _AttemptStep.holding) {
      return;
    }
    setState(() {
      _holdWaitingForStartTap = true;
    });
    _holdRetryTimer?.cancel();
    _holdRetryTimer = Timer(_holdRetryGrace, () {
      if (!mounted ||
          _step != _AttemptStep.holding ||
          !_holdWaitingForStartTap) {
        return;
      }
      // Restart the measurement clock too, not just the on-screen
      // countdown — otherwise a retried hold would silently add the
      // abandoned first attempt's dead time into the saved
      // holdDuration/blowDuration, inflating the score with time the
      // user wasn't actually holding/exhaling for.
      _stopwatch
        ..reset()
        ..start();
      // Same reasoning for the acoustic samples: the abandoned attempt's
      // calibration window is stale once we've restarted, so a fresh
      // baseline needs fresh samples, not ones mixed in from before.
      _currentAttemptSamples.clear();
      setState(() {
        _holdWaitingForStartTap = false;
        _holdCountdownSecondsLeft = _holdCountdownSeconds;
      });
      unawaited(_speakStep('breathStepHold'));
      _startHoldCountdown();
    });
  }

  /// The "Başlat" tap that confirms the hold and moves straight into the
  /// exhale: the blow instruction is spoken/shown, the circle starts
  /// counting, and the give-up safety-net clock (see
  /// [_acousticGiveUpAfter]) begins — no extra "press OK" checkpoint in
  /// between (there was one; it just made the user tap twice in a row for
  /// no benefit, since "press Start" already *was* their confirmation).
  void _handleHoldStartTap() {
    if (_step != _AttemptStep.holding || !_holdWaitingForStartTap) {
      return;
    }
    SystemSound.play(SystemSoundType.click);
    _holdRetryTimer?.cancel();
    setState(() {
      _step = _AttemptStep.exhale;
      _holdWaitingForStartTap = false;
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
    unawaited(
      _breathVoiceGuideService.speak(
        '${context.t('breathStepExhale')} ${context.t('breathStepExhaleFinishHint')}',
      ),
    );

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

  /// Best-effort: if the microphone isn't available (permission denied,
  /// platform error), [_acousticListeningActive] just stays false and
  /// every attempt behaves exactly like the manual-tap flow always has.
  Future<void> _startAcousticListeningForAttempt() async {
    _currentAttemptSamples.clear();
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
  /// Samples are collected from the start of the hold step onward (that
  /// quiet 5 seconds is the best calibration data available), but an
  /// exhale is only ever *acted on* once the exhale step has actually
  /// begun — otherwise a stray noise during the hold could end the
  /// attempt before the user was even told to exhale.
  void _handleAcousticSample(BreathAcousticSample sample) {
    final inMeasuredStep =
        _step == _AttemptStep.holding || _step == _AttemptStep.exhale;
    if (!inMeasuredStep || _autoFinishing || _ttsSpeaking) {
      return;
    }
    _currentAttemptSamples.add(sample);
    final analysis = _breathAcousticEngine.analyze(_currentAttemptSamples);
    if (_step == _AttemptStep.exhale && analysis.exhaleDetected) {
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
    _holdRetryTimer?.cancel();
    _pulseController.stop();
    _exhaleShrinkController.reset();
    unawaited(_breathAudioService.stopListening());
    unawaited(_breathVoiceGuideService.stop());
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

    if (_attemptSeconds.length >= 3) {
      unawaited(_navigateToResult());
      return;
    }

    _startRestInterval();
  }

  /// How long into the 20s rest window (counting down from there) the
  /// combined "here's everything for the next attempt" announcement
  /// starts. Not an exact science — TTS duration isn't known ahead of
  /// time — so [_maybeBeginNextAttemptAutomatically] treats "the rest
  /// countdown reached zero" and "the announcement finished speaking" as
  /// two independent conditions and only starts once *both* are true,
  /// rather than assuming this lead time lines them up perfectly.
  static const int _restInstructionLeadSeconds = 15;

  void _startRestInterval() {
    _timer?.cancel();
    _restCountdownDone = false;
    setState(() {
      _isResting = true;
      _restInstructionAnnounced = false;
      _restSecondsLeft = 20;
    });

    // Mic listens through the entire rest period — plenty of genuine
    // quiet time for calibration well before the combined instruction
    // (muted like any other speech) or the next attempt's exhale begins.
    unawaited(_startAcousticListeningForAttempt());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _restSecondsLeft -= 1;
      });

      if (_restSecondsLeft == _restInstructionLeadSeconds) {
        setState(() {
          _restInstructionAnnounced = true;
        });
        unawaited(
          _breathVoiceGuideService.speak(
            context.t('breathAutoNextAttemptInstruction'),
          ),
        );
      }

      if (_restSecondsLeft <= 0) {
        timer.cancel();
        _restCountdownDone = true;
        _maybeBeginNextAttemptAutomatically();
      }
    });
  }

  /// Starts the next attempt's exhale measurement the instant both the
  /// rest countdown has reached zero *and* the combined instruction has
  /// finished being spoken — whichever of the two actually finishes last.
  /// No "BAŞLA"/OK taps in between: only the very first attempt needs a
  /// deliberate tap to begin (there's no preceding rest period to have
  /// already announced everything during), every attempt after that was
  /// already fully explained while the user was resting.
  void _maybeBeginNextAttemptAutomatically() {
    if (!mounted || !_restCountdownDone || _ttsSpeaking || _isRunning) {
      return;
    }
    setState(() {
      _isResting = false;
      _currentTest = _attemptSeconds.length + 1;
    });
    _beginAutoMeasuredAttempt();
  }

  void _beginAutoMeasuredAttempt() {
    SystemSound.play(SystemSoundType.click);
    _autoFinishing = false;
    _stopwatch
      ..reset()
      ..start();
    _pulseController.repeat(reverse: true);
    setState(() {
      _isRunning = true;
      _step = _AttemptStep.exhale;
      _exhaleStartElapsedSeconds = 0;
    });
    _exhaleShrinkController
      ..stop()
      ..forward(from: 0);

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

      final processed = await _breathTestService.processBreathTest(
        name: widget.name,
        packsPerDay: widget.packsPerDay,
        holdDuration: bestSeconds.toDouble(),
        blowDuration: averageSeconds.toDouble(),
        blowStability: blowStability,
        blowIntensity: blowIntensity,
        title: context.t('breathTestRecordTitle'),
      );

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

    if (widget.askWeeklySurveyOnComplete) {
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

  String _getInstruction() {
    if (_isResting) {
      return _restInstructionAnnounced
          ? context.t('breathAutoNextAttemptInstruction')
          : context.t('breathRestInstruction');
    }
    switch (_step) {
      case _AttemptStep.notStarted:
        return '';
      case _AttemptStep.sitRelax:
        return context.t('breathStepSitRelax');
      case _AttemptStep.deepBreath:
        return context.t('breathStepDeepBreath');
      case _AttemptStep.holding:
        // Single combined instruction throughout the whole hold step
        // (counting down and waiting-for-tap alike) — not two different
        // texts swapped mid-way.
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
    final showOkButton =
        _step == _AttemptStep.sitRelax || _step == _AttemptStep.deepBreath;

    return Scaffold(
      appBar: AppBar(elevation: 0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Progress Indicator - Visual dots showing test progress
              _buildProgressIndicator(),
              const SizedBox(height: 32),

              // Instruction Card with professional styling — animates in
              // as each new step (sit & relax / deep breath / exhale)
              // replaces the previous one, instead of jumping instantly.
              AnimatedSwitcher(
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
                    : _buildInstructionCard(
                        context,
                        key: ValueKey('${_isResting}_$_step'),
                      ),
              ),
              const SizedBox(height: 32),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: showOkButton
                    ? _buildStepOkButton(key: ValueKey(_step))
                    : Padding(
                        key: const ValueKey('breath_timer'),
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            _buildTimerDisplay(currentSeconds),
                            if (_step == _AttemptStep.exhale) ...[
                              const SizedBox(height: 24),
                              _buildFinishOkButton(),
                            ],
                            if (_step == _AttemptStep.holding &&
                                _holdWaitingForStartTap) ...[
                              const SizedBox(height: 24),
                              _buildHoldStartButton(),
                            ],
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepOkButton({required Key key}) {
    return SizedBox(
      key: key,
      width: double.infinity,
      child: ElevatedButton(
        key: const ValueKey('breath_step_ok_button'),
        onPressed: switch (_step) {
          _AttemptStep.sitRelax => _advanceFromSitRelax,
          _AttemptStep.deepBreath => _advanceFromDeepBreath,
          _ => null,
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.noSmokeGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          context.t('breathStepOkAction').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }

  /// Explicit manual-finish control for the exhale step, alongside the
  /// timer circle (which stays tappable too — this just gives the same
  /// action an unambiguous "I'm done" button, for whenever the mic doesn't
  /// catch the exhale itself).
  Widget _buildFinishOkButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: const ValueKey('breath_finish_ok_button'),
        onPressed: _handleBreathPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.noSmokeGreen,
          side: const BorderSide(color: AppTheme.noSmokeGreen),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          context.t('breathStepOkAction').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }

  /// Confirms the hold and moves on to the exhale step — see
  /// [_promptHoldStartTap].
  Widget _buildHoldStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        key: const ValueKey('breath_hold_start_button'),
        onPressed: _handleHoldStartTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.noSmokeGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          context.t('start').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final testNumber = index + 1;
        final isCompleted = testNumber < _currentTest;
        final isCurrent = testNumber == _currentTest;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppTheme.noSmokeGreen
                        : isCurrent
                        ? const Color(0xFF132238)
                        : const Color(0xFF132238),
                    border: isCurrent
                        ? Border.all(color: AppTheme.noSmokeGreen, width: 2)
                        : null,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppTheme.noSmokeGreen.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : const [],
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.black, size: 28)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInstructionCard(BuildContext context, {required Key key}) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = _isResting
        ? Icons.psychology
        : switch (_step) {
            _AttemptStep.sitRelax => Icons.self_improvement,
            _AttemptStep.deepBreath => Icons.air,
            _AttemptStep.holding => Icons.timer_outlined,
            _AttemptStep.exhale => Icons.graphic_eq,
            _AttemptStep.notStarted => Icons.info,
          };
    return Card(
      key: key,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.noSmokeGreen, size: 24),
            const SizedBox(height: 12),
            Text(
              _getInstruction(),
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.t('breathExerciseDisclaimer'),
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(int seconds) {
    final isResting = _isResting;
    final isIdle = !_isRunning && !isResting;
    final accentColor = isResting
        ? const Color(0xFFFFB74D)
        : AppTheme.noSmokeGreen;

    final circle = AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _exhaleShrinkController]),
      builder: (context, child) {
        // A slow, continuous scale+glow pulse while an attempt is running —
        // not paced to any fixed inhale/hold/exhale timing (the test is
        // open-ended), just a calming "still breathing, still holding"
        // visual anchor. Static (no pulse) when idle or resting. Kept
        // deliberately muted (low alpha throughout) rather than a bold
        // solid-fill circle.
        final pulse = _isRunning ? _pulseController.value : 0.0;
        final scale = 1.0 + (pulse * 0.04);
        final glowAlpha = isIdle ? 0.0 : 0.08 + (pulse * 0.14);
        // While actively exhaling, an inner disc slowly shrinks — a visual
        // echo of the breath itself running out, on top of (not instead
        // of) the numeric seconds count.
        final isExhaling = _step == _AttemptStep.exhale;
        final exhaleShrinkScale = 1.0 - (_exhaleShrinkController.value * 0.85);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF132238),
              border: Border.all(
                color: accentColor.withValues(alpha: isIdle ? 0.35 : 0.55),
                width: 2,
              ),
              boxShadow: glowAlpha > 0
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: glowAlpha),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ]
                  : const [],
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isExhaling)
                    Transform.scale(
                      scale: exhaleShrinkScale.clamp(0.12, 1.0),
                      child: Container(
                        width: 196,
                        height: 196,
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
                  isIdle
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              color: accentColor.withValues(alpha: 0.8),
                              size: 36,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.t('start').toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: accentColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          seconds.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: accentColor.withValues(alpha: 0.85),
                            letterSpacing: 2,
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            key: const ValueKey('breath_timer_circle'),
            customBorder: const CircleBorder(),
            onTap: switch (_step) {
              _ when isResting => null,
              _AttemptStep.exhale => _handleBreathPressed,
              _AttemptStep.notStarted => _startCurrentTest,
              // The 5-second hold is a fixed countdown — nothing to tap.
              // sitRelax/deepBreath show their own OK button instead of
              // this circle at all.
              _AttemptStep.holding ||
              _AttemptStep.sitRelax ||
              _AttemptStep.deepBreath => null,
            },
            child: circle,
          ),
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
}
