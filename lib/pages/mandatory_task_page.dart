import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/app_texts.dart';
import '../core/app_theme.dart';
import '../services/storage_service.dart';
import '../services/tts_locale.dart';
import '../services/tts_voice_selector.dart';
import 'craving_sos_page.dart';

/// Styled like an incoming-call screen (large pulsing avatar, caller-style
/// title, two big round accept/decline buttons) so a triggered task reads
/// as urgent and hard to ignore — reusing the presentation the app's old
/// fake-call barrier used, now that the fake-call feature itself is gone.
class MandatoryTaskPage extends StatefulWidget {
  final String taskTitle;

  const MandatoryTaskPage({super.key, required this.taskTitle});

  @override
  State<MandatoryTaskPage> createState() => _MandatoryTaskPageState();
}

class _MandatoryTaskPageState extends State<MandatoryTaskPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Answering plays a spoken announcement of the task, like the other
  // party starting to talk the moment a real phone call is picked up
  // (loudspeaker-style, not just a silent screen change) -- fired via a
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
      // A real incoming call can't be dismissed with the back button
      // either — the user has to actively answer or decline.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Text(
                  context.t('mandatoryTaskTitle'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Spacer(),
                // A mandatory "don't smoke" command is exactly the moment a
                // real craving is most likely to hit — the SOS breathing
                // helper needs to be reachable from right here, not just
                // from the home screen. Placed above the icon (not as a
                // corner-floating button) so it never overlaps the
                // accept/decline call buttons below. Pushed (not popped) so
                // answering the command is unaffected.
                ElevatedButton.icon(
                  key: const ValueKey('mandatory_task_sos_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.sos),
                  label: Text(context.t('cravingSosButton')),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CravingSosPage()),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.08);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: CircleAvatar(
                    radius: 64,
                    backgroundColor: AppTheme.noSmokeGreen.withValues(
                      alpha: 0.25,
                    ),
                    child: const Icon(
                      Icons.smoke_free,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.t('mandatoryTaskCommand'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppTexts.localizeCanonicalText(context, widget.taskTitle),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.t('mandatoryTaskHint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallStyleButton(
                      key: const ValueKey('mandatory_task_decline_button'),
                      color: Colors.redAccent,
                      icon: Icons.call_end,
                      label: context.t('mandatoryTaskDeclineButton'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    _CallStyleButton(
                      key: const ValueKey('mandatory_task_start_button'),
                      color: AppTheme.noSmokeGreen,
                      icon: Icons.call,
                      label: context.t('mandatoryTaskStartButton'),
                      onPressed: () => _acceptAndAnnounce(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallStyleButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CallStyleButton({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
