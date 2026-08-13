import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/engines/breath_feedback_engine.dart';
import 'package:no_smoke/models/breath_attempt_feedback.dart';

void main() {
  group('BreathFeedbackEngine.buildFeedback', () {
    final engine = BreathFeedbackEngine();

    test('short blow duration triggers the too-short encouragement', () {
      final feedback = engine.buildFeedback(
        blowDurationSeconds: 2,
        blowStability: 0.9,
        blowIntensity: 0.9,
        currentScore: 50,
      );
      expect(feedback.messageKey, 'breathFeedbackTooShort');
      expect(feedback.tone, BreathFeedbackTone.encouraging);
    });

    test('low stability (with duration fine) triggers the steady-force '
        'suggestion', () {
      final feedback = engine.buildFeedback(
        blowDurationSeconds: 10,
        blowStability: 0.2,
        blowIntensity: 0.9,
        currentScore: 50,
      );
      expect(feedback.messageKey, 'breathFeedbackLowStability');
    });

    test('weak intensity (with duration/stability fine) triggers the '
        'move-closer suggestion', () {
      final feedback = engine.buildFeedback(
        blowDurationSeconds: 10,
        blowStability: 0.9,
        blowIntensity: 0.1,
        currentScore: 50,
      );
      expect(feedback.messageKey, 'breathFeedbackWeakSignal');
    });

    test('a solid attempt with no prior score gets the neutral good-attempt '
        'message', () {
      final feedback = engine.buildFeedback(
        blowDurationSeconds: 10,
        blowStability: 0.9,
        blowIntensity: 0.9,
        currentScore: 90,
      );
      expect(feedback.messageKey, 'breathFeedbackGoodAttempt');
      expect(feedback.tone, BreathFeedbackTone.neutral);
    });

    test('a meaningful score improvement over the previous attempt takes '
        'priority over any technical issue', () {
      final feedback = engine.buildFeedback(
        blowDurationSeconds: 2, // would otherwise trigger tooShort
        blowStability: 0.2, // would otherwise trigger lowStability
        blowIntensity: 90 / 100, // fine
        currentScore: 60,
        previousScore: 50,
      );
      expect(feedback.messageKey, 'breathFeedbackBetterThanBefore');
      expect(feedback.tone, BreathFeedbackTone.positive);
    });

    test('a tiny score bump under the improvement threshold does not count '
        'as "better than before"', () {
      final feedback = engine.buildFeedback(
        blowDurationSeconds: 10,
        blowStability: 0.9,
        blowIntensity: 0.9,
        currentScore: 52,
        previousScore: 50,
      );
      expect(feedback.messageKey, isNot('breathFeedbackBetterThanBefore'));
    });

    test('a score drop from the previous attempt never claims improvement', () {
      final feedback = engine.buildFeedback(
        blowDurationSeconds: 10,
        blowStability: 0.9,
        blowIntensity: 0.9,
        currentScore: 40,
        previousScore: 50,
      );
      expect(feedback.messageKey, isNot('breathFeedbackBetterThanBefore'));
    });

    test('never suggests a diagnosis or blaming language regardless of how '
        'poor the attempt was', () {
      final feedback = engine.buildFeedback(
        blowDurationSeconds: 0,
        blowStability: 0,
        blowIntensity: 0,
        currentScore: 0,
      );
      final lowered = feedback.messageKey.toLowerCase();
      expect(lowered, isNot(contains('hastal')));
      expect(lowered, isNot(contains('kotu')));
    });
  });
}
