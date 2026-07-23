import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../services/storage_service.dart';
import 'breath_test_page.dart';

/// The single, consolidated daily touchpoint, meant to be reached near the
/// user's bedtime rather than scattered through the day: a short
/// recall-based "when did you smoke today" check-in, plus an optional link
/// to the breathing exercise. Replaces asking for several separate
/// interruptions throughout the day with one end-of-day moment.
class DailyCheckInPage extends StatefulWidget {
  final String name;
  final String packsPerDay;

  const DailyCheckInPage({
    super.key,
    required this.name,
    required this.packsPerDay,
  });

  @override
  State<DailyCheckInPage> createState() => _DailyCheckInPageState();
}

class _DailyCheckInPageState extends State<DailyCheckInPage> {
  final StorageService _storageService = StorageService();
  final Set<int> _selectedHours = <int>{};
  bool _didNotSmoke = false;
  bool _isSaving = false;
  bool _saved = false;
  List<int> _awakeHours = List<int>.generate(24, (h) => h);

  @override
  void initState() {
    super.initState();
    _loadAwakeHours();
  }

  Future<void> _loadAwakeHours() async {
    final context = await _storageService.loadMergedProfileContext();
    final sleep = _parseHour(context['sleepTime']?.toString());
    final wake = _parseHour(context['wakeTime']?.toString());
    if (sleep == null || wake == null || !mounted) {
      return;
    }
    final hours = <int>[];
    var hour = wake;
    while (hour != sleep) {
      hours.add(hour);
      hour = (hour + 1) % 24;
    }
    setState(() {
      _awakeHours = hours;
    });
  }

  int? _parseHour(String? value) {
    if (value == null || !value.contains(':')) {
      return null;
    }
    return int.tryParse(value.split(':').first);
  }

  String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      if (!_didNotSmoke && _selectedHours.isNotEmpty) {
        await _storageService.logRecalledSmokingHours(
          day: DateTime.now(),
          hours: _selectedHours.toList(),
        );
      }
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.t('saveErrorRetry'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('dailyCheckInTitle'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('dailyCheckInIntro'),
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('breathExerciseCardTitle'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BreathTestPage(
                              name: widget.name,
                              packsPerDay: widget.packsPerDay,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.air),
                      label: Text(context.t('breathTest')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.t('dailyCheckInHoursQuestion'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _didNotSmoke,
              title: Text(context.t('dailyCheckInDidNotSmoke')),
              onChanged: _saved
                  ? null
                  : (value) {
                      setState(() {
                        _didNotSmoke = value ?? false;
                        if (_didNotSmoke) {
                          _selectedHours.clear();
                        }
                      });
                    },
            ),
            if (!_didNotSmoke)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _awakeHours.map((hour) {
                  final selected = _selectedHours.contains(hour);
                  return FilterChip(
                    label: Text(_hourLabel(hour)),
                    selected: selected,
                    onSelected: _saved
                        ? null
                        : (value) {
                            setState(() {
                              if (value) {
                                _selectedHours.add(hour);
                              } else {
                                _selectedHours.remove(hour);
                              }
                            });
                          },
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            if (_saved)
              Text(
                context.t('dailyCheckInSaved'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.green, fontSize: 15),
              )
            else
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.t('save')),
              ),
          ],
        ),
      ),
    );
  }
}
