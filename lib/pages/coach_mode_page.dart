import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/storage_service.dart';

/// The single UI surface that writes duration_barrier_enabled/
/// duration_barrier_frequency_preference — every other screen that used to
/// ask about this (survey_page.dart, weekly_survey_page.dart) either never
/// saved the answer or never showed the question at all; ai_chat_page.dart
/// remains a second *write* path (the AI tool call), not a second question,
/// so it still calls the same two settings this page does.
///
/// duration_barrier_preference ('like'/'neutral'/'dislike') no longer
/// exists: it used to feed MentorEngine.buildDurationBarrierCommands, which
/// generated its own random barrier length. That function is gone —
/// duration is now SmokingIntervalService's alone — so a like/dislike
/// scoring knob would have nothing left to tune. Only the consent switch
/// (on/off) and the frequency axis (how many barrier tasks per day) remain,
/// and they are asked as two independent questions rather than folded into
/// one preference value.
class CoachModePage extends StatefulWidget {
  const CoachModePage({super.key});

  @override
  State<CoachModePage> createState() => _CoachModePageState();
}

class _CoachModePageState extends State<CoachModePage> {
  final StorageService _storageService = StorageService();

  bool _enabled = true;
  String _frequency = 'orta';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabledRaw =
        await _storageService.loadSetting('duration_barrier_enabled') ?? '1';
    final frequency =
        await _storageService.loadSetting(
          'duration_barrier_frequency_preference',
        ) ??
        'orta';
    if (!mounted) return;
    setState(() {
      _enabled = enabledRaw != '0';
      _frequency = frequency;
      _loading = false;
    });
  }

  Future<void> _applyEnabled(bool enabled) async {
    await _storageService.saveSetting(
      'duration_barrier_enabled',
      enabled ? '1' : '0',
    );
    if (!mounted) return;
    setState(() => _enabled = enabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('coachModeSavedConfirmation'))),
    );
  }

  Future<void> _applyFrequency(String frequency) async {
    await _storageService.saveSetting(
      'duration_barrier_frequency_preference',
      frequency,
    );
    if (!mounted) return;
    setState(() => _frequency = frequency);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('coachModeSavedConfirmation'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('coachModeTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  context.t('coachModeIntro'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),

                Card(
                  child: SwitchListTile(
                    title: Text(context.t('durationBarrierEnabledTitle')),
                    subtitle: Text(
                      context.t('durationBarrierEnabledDescription'),
                    ),
                    value: _enabled,
                    onChanged: _applyEnabled,
                  ),
                ),

                const SizedBox(height: 12),

                if (_enabled)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _frequency,
                    decoration: InputDecoration(
                      labelText: context.t('durationBarrierFrequencyHow'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'az',
                        child: Text(context.t('few')),
                      ),
                      DropdownMenuItem(
                        value: 'orta',
                        child: Text(context.t('stressMedium')),
                      ),
                      DropdownMenuItem(
                        value: 'cok',
                        child: Text(context.t('veryHigh')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _applyFrequency(value);
                    },
                  ),
              ],
            ),
    );
  }
}
