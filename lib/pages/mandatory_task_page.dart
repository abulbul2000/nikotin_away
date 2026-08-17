import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../services/storage_service.dart';
import '../services/tts_locale.dart';
import '../services/tts_voice_selector.dart';
import 'craving_sos_page.dart';

/// Vertical-list task prompt — mirrors the native overlay's design
/// (TaskOverlayService.kt's showOverlay: title, body, stacked full-width
/// buttons) so the in-app screen and the (currently unused) native overlay
/// agree on one visual language instead of two. Replaces the earlier
/// incoming-call-style presentation.
class MandatoryTaskPage extends StatefulWidget {
  final String taskTitle;

  const MandatoryTaskPage({super.key, required this.taskTitle});

  @override
  State<MandatoryTaskPage> createState() => _MandatoryTaskPageState();
}

class _MandatoryTaskPageState extends State<MandatoryTaskPage> {
  // Answering plays a spoken announcement of the task -- fired via a
  // standalone FlutterTts instance rather than the page's own state, so
  // navigating away immediately after doesn't cut the announcement off.
  void _acceptAndAnnounce(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final announcement =
        '${context.t('mandatoryTaskCommand')}. '
        '${AppTexts.localizeCanonicalText(context, widget.taskTitle)}';
    unawaited(_speakAnnouncement(languageCode, announcement));
    Navigator.of(context).pop(true);
  }

  Future<void> _speakAnnouncement(String languageCode, String text) async {
    try {
      final locale = ttsLocaleForLanguageCode(languageCode);
      if (locale == null) return;
      final storedGender = await StorageService().loadSetting('gender');
      final tts = FlutterTts();
      await tts.setLanguage(locale);
      await configureBestVoice(
        tts,
        locale: locale,
        // No live mic recording is running here (unlike the breath test),
        // so there's no timing constraint pulling toward the faster but
        // more robotic local voice -- prefer the more natural-sounding
        // network voice when the engine has one for this locale.
        preferLocalVoice: false,
        preferredGender: ttsGenderHintFor(storedGender),
      );
      await tts.setVolume(1.0);
      await tts.setSpeechRate(0.5);
      await tts.setPitch(1.0);
      await tts.speak(text);
    } catch (_) {
      // Best-effort -- the on-screen task text already covers the same
      // guidance if the device has no usable TTS voice for this language.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Same as before: not dismissible with the back button, the user has
      // to actively answer.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.noSmokeNavy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Text(
                  context.t('mandatoryTaskTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppTexts.localizeCanonicalText(context, widget.taskTitle),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 17,
                  ),
                ),
                const Spacer(flex: 3),
                _TaskListButton(
                  key: const ValueKey('mandatory_task_start_button'),
                  label: context.t('mandatoryTaskStartButton'),
                  onPressed: () => _acceptAndAnnounce(context),
                ),
                const SizedBox(height: 12),
                _TaskListButton(
                  key: const ValueKey('mandatory_task_decline_button'),
                  label: context.t('mandatoryTaskDeclineButton'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 12),
                _TaskListButton(
                  key: const ValueKey('mandatory_task_sos_button'),
                  label: context.t('cravingSosButton'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CravingSosPage()),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width, rounded, light-gray button — matches the native overlay's
/// plain Android Button styling so both surfaces read as the same prompt.
class _TaskListButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TaskListButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEEEEEE),
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
