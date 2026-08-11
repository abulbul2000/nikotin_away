import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/storage_service.dart';
import 'ai_chat_page.dart';

class CoachModePage extends StatefulWidget {
  const CoachModePage({super.key});

  @override
  State<CoachModePage> createState() => _CoachModePageState();
}

enum _CoachModePreset { easy, normal, hard, custom }

class _CoachModePageState extends State<CoachModePage> {
  final StorageService _storageService = StorageService();

  String _preference = 'neutral';
  String _frequency = 'orta';
  bool _loading = true;

  static const _presetValues = {
    _CoachModePreset.easy: ('dislike', 'az'),
    _CoachModePreset.normal: ('neutral', 'orta'),
    _CoachModePreset.hard: ('like', 'cok'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preference =
        await _storageService.loadSetting('duration_barrier_preference') ??
        'neutral';
    final frequency =
        await _storageService.loadSetting(
          'duration_barrier_frequency_preference',
        ) ??
        'orta';
    if (!mounted) return;
    setState(() {
      _preference = preference;
      _frequency = frequency;
      _loading = false;
    });
  }

  _CoachModePreset _currentPreset() {
    for (final entry in _presetValues.entries) {
      if (entry.value == (_preference, _frequency)) {
        return entry.key;
      }
    }
    return _CoachModePreset.custom;
  }

  Future<void> _applyPreset(_CoachModePreset preset) async {
    final values = _presetValues[preset];
    if (values == null) return;
    await _applyValues(preference: values.$1, frequency: values.$2);
  }

  Future<void> _applyValues({
    required String preference,
    required String frequency,
  }) async {
    await _storageService.saveSetting(
      'duration_barrier_preference',
      preference,
    );
    await _storageService.saveSetting(
      'duration_barrier_frequency_preference',
      frequency,
    );
    await _storageService.saveSetting(
      'duration_barrier_enabled',
      preference == 'off' ? '0' : '1',
    );
    if (!mounted) return;
    setState(() {
      _preference = preference;
      _frequency = frequency;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('coachModeSavedConfirmation'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPreset = _currentPreset();

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

                _ModeCard(
                  title: context.t('coachModeEasyTitle'),
                  description: context.t('coachModeEasyDescription'),
                  icon: Icons.spa_outlined,
                  selected: currentPreset == _CoachModePreset.easy,
                  onTap: () => _applyPreset(_CoachModePreset.easy),
                ),

                _ModeCard(
                  title: context.t('coachModeNormalTitle'),
                  description: context.t('coachModeNormalDescription'),
                  icon: Icons.balance_outlined,
                  selected: currentPreset == _CoachModePreset.normal,
                  onTap: () => _applyPreset(_CoachModePreset.normal),
                ),

                _ModeCard(
                  title: context.t('coachModeHardTitle'),
                  description: context.t('coachModeHardDescription'),
                  icon: Icons.bolt_outlined,
                  selected: currentPreset == _CoachModePreset.hard,
                  onTap: () => _applyPreset(_CoachModePreset.hard),
                ),

                if (currentPreset == _CoachModePreset.custom)
                  _ModeCard(
                    title: context.t('coachModeCustomLabel'),
                    description: context.t('coachModeCustomDescription'),
                    icon: Icons.tune,
                    selected: true,
                    onTap: null,
                  ),

                const SizedBox(height: 12),

                ExpansionTile(
                  title: Text(context.t('coachModeAdvancedToggle')),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _preference,
                      decoration: InputDecoration(
                        labelText: context.t('durationBarrierHow'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'like',
                          child: Text(context.t('durationBarrierLike')),
                        ),
                        DropdownMenuItem(
                          value: 'neutral',
                          child: Text(context.t('durationBarrierNeutral')),
                        ),
                        DropdownMenuItem(
                          value: 'dislike',
                          child: Text(context.t('durationBarrierDislike')),
                        ),
                        DropdownMenuItem(
                          value: 'off',
                          child: Text(context.t('durationBarrierOff')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _applyValues(preference: value, frequency: _frequency);
                      },
                    ),

                    const SizedBox(height: 12),

                    if (_preference != 'off')
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
                          _applyValues(
                            preference: _preference,
                            frequency: value,
                          );
                        },
                      ),

                    const SizedBox(height: 12),
                  ],
                ),

                const SizedBox(height: 24),

                // 🔥 Yapay Zekâ Mentörü Butonu
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AIChatPage(),
                      ),
                    );
                  },
                  child: const Text("Yapay Zekâ Mentörü"),
                ),
              ],
            ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: selected
            ? const BorderSide(color: Colors.greenAccent, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: Colors.greenAccent),
            ],
          ),
        ),
      ),
    );
  }
}
