
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../engines/breath_test_engine.dart';
import '../services/breath_test_service.dart';
import 'home_page.dart';
import 'risk_result_page.dart';
import 'weekly_survey_page.dart';

class BreathTestPage extends StatefulWidget {
  final String name;
  final String packsPerDay;
  final bool navigateToHomeOnComplete;
  final bool askWeeklySurveyOnComplete;
  final BreathTestService? breathTestService;

  const BreathTestPage({
    super.key,
    this.name = '',
    this.packsPerDay = '1 paketten az',
    this.navigateToHomeOnComplete = false,
    this.askWeeklySurveyOnComplete = false,
    this.breathTestService,
  });

  @override
  State<BreathTestPage> createState() => _BreathTestPageState();
}

class _BreathTestPageState extends State<BreathTestPage> {
  final Stopwatch _stopwatch = Stopwatch();
  final BreathTestEngine _breathTestEngine = BreathTestEngine();
  late final BreathTestService _breathTestService;
  Timer? _timer;
  int _currentTest = 1;
  final List<int> _attemptSeconds = <int>[];
  bool _isResting = false;
  int _restSecondsLeft = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _breathTestService = widget.breathTestService ?? BreathTestService();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCurrentTest() {
    if (_isResting) {
      return;
    }
    _timer?.cancel();
    _stopwatch.reset();
    _stopwatch.start();
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _handleBreathPressed() {
    if (!_isRunning) {
      return;
    }

    _stopwatch.stop();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    final seconds = _stopwatch.elapsed.inSeconds;
    _attemptSeconds.add(seconds);

    if (_attemptSeconds.length >= 3) {
      unawaited(_navigateToResult());
      return;
    }

    _startRestInterval();
  }

  void _startRestInterval() {
    _timer?.cancel();
    setState(() {
      _isResting = true;
      _restSecondsLeft = 20;
    });

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
        if (!mounted) {
          return;
        }
        setState(() {
          _isResting = false;
          _currentTest = _attemptSeconds.length + 1;
        });
      }
    });
  }

  Future<void> _navigateToResult() async {
    try {
      final sorted = [..._attemptSeconds]..sort((a, b) => b.compareTo(a));
      final bestSeconds = sorted.first;
      final averageSeconds =
          (_attemptSeconds.reduce((a, b) => a + b) / _attemptSeconds.length)
              .round();

      final blowStability = _breathTestEngine.estimateBlowStabilityFromAttempts(
        _attemptSeconds,
      );
      final blowIntensity = _breathTestEngine.estimateBlowIntensity(
        holdDuration: bestSeconds.toDouble(),
        blowDuration: averageSeconds.toDouble(),
      );

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
            persistBreathResultOnContinue: false,
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
            persistBreathResultOnContinue: false,
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
      return context.t('breathRestInstruction');
    }
    return context.t('breathActiveInstruction');
  }

  @override
  Widget build(BuildContext context) {
    final currentSeconds = _isResting
        ? _restSecondsLeft
        : _stopwatch.elapsed.inSeconds;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('breathTest')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Progress Indicator - Visual dots showing test progress
              _buildProgressIndicator(),
              const SizedBox(height: 32),
              
              // Instruction Card with professional styling
              _buildInstructionCard(context),
              const SizedBox(height: 40),
              
              // Professional Timer Display
              _buildTimerDisplay(currentSeconds),
              const SizedBox(height: 24),
              
              // Previous Attempts Display
              if (_attemptSeconds.isNotEmpty)
                _buildAttemptsDisplay(),
              
              const SizedBox(height: 40),
              
              // Action Buttons
              _buildActionButtons(context),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Row(
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
                            ? Colors.green
                            : isCurrent
                                ? Colors.blue
                                : Colors.grey[300],
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 28,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_attemptSeconds.length >= testNumber ? _attemptSeconds[testNumber - 1] : '-'}s',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildInstructionCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.blue[100]!,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _isResting ? Icons.psychology : Icons.info,
              color: Colors.blue[700],
              size: 24,
            ),
            const SizedBox(height: 12),
            Text(
              _getInstruction(),
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(int seconds) {
    final isResting = _isResting;
    
    return Column(
      children: [
        Text(
          isResting ? 'KALAN SÜRESİ' : 'DAYANIKLILIK',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: isResting ? Colors.orange[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isResting ? Colors.orange[200]! : Colors.blue[200]!,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                seconds.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: isResting ? Colors.orange[700] : Colors.blue[700],
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttemptsDisplay() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Önceki Denemeler',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_attemptSeconds.length, (index) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    'Deneme ${index + 1}: ${_attemptSeconds[index]}s',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (!_isRunning && !_isResting) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _startCurrentTest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow, size: 24),
              const SizedBox(width: 12),
              Text(
                context.t('start').toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_isResting) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[400],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: null,
          child: Text(
            'Dinlenme - $_restSecondsLeft saniye kaldı',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _handleBreathPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 24),
              const SizedBox(width: 12),
              Text(
                context.t('iBreathed').toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
