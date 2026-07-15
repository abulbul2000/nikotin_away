import 'package:flutter/material.dart';

import '../core/app_texts.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../widgets/consecutive_smoking_section.dart';
import '../widgets/no_smoke_logo.dart';
import '../widgets/packs_per_day_section.dart';
import 'breath_test_page.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  String? gender;
  String? profession;
  String? smokingYears;
  String firstCigaretteRange = '10-30';
  String smokeFreeRange = '30-60';
  String workplaceSmokingRule = 'Hayır';
  String stressLevel = 'Orta';
  String quitReason = 'Sağlık';
  String? sleepTime;
  String? wakeTime;
  String? workStartTime;
  String? workEndTime;
  final Set<String> workingDays = <String>{'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  bool hasSmokingBreaks = false;
  String? breakStart1;
  String? breakEnd1;
  bool hasSecondBreak = false;
  String? breakStart2;
  String? breakEnd2;
  String weekendSmokingPattern = 'Ayni';
  String packOption = '1 paketten az';
  String? highPackOption;
  String? consecutiveSmokingHabit;
  String? consecutiveSmokingCount;
  String durationBarrierPreference = 'Farketmez';
  String durationBarrierFrequencyPreference = 'Orta';

  bool hypertension = false;
  bool asthma = false;
  bool diabetes = false;
  bool copd = false;
  bool heartDisease = false;

  final Set<String> triggerSet = <String>{};

  static const List<String> professionOptions = [
    'Öğrenci',
    'Memur',
    'İşçi',
    'Sağlık Çalışanı',
    'Öğretmen',
    'Mühendis',
    'Esnaf',
    'Emekli',
    'Serbest Çalışıyor',
    'Diğer',
  ];

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget triggerTile(String title, String key) {
    return CheckboxListTile(
      dense: true,
      value: triggerSet.contains(key),
      title: Text(title),
      onChanged: (value) {
        setState(() {
          if (value == true) {
            triggerSet.add(key);
          } else {
            triggerSet.remove(key);
          }
        });
      },
    );
  }

  List<String> get timeOptions {
    return List.generate(48, (index) {
      final hour = (index ~/ 2).toString().padLeft(2, '0');
      final minute = index.isEven ? '00' : '30';
      return '$hour:$minute';
    });
  }

  List<String> get workTimeOptions {
    return List.generate(38, (index) {
      final totalMinutes = (5 * 60) + (index * 30);
      final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
      final minute = (totalMinutes % 60).toString().padLeft(2, '0');
      return '$hour:$minute';
    });
  }



  static const List<Map<String, String>> workDayOptions = [
    {'key': 'Mon', 'labelKey': 'dayMonShort'},
    {'key': 'Tue', 'labelKey': 'dayTueShort'},
    {'key': 'Wed', 'labelKey': 'dayWedShort'},
    {'key': 'Thu', 'labelKey': 'dayThuShort'},
    {'key': 'Fri', 'labelKey': 'dayFriShort'},
    {'key': 'Sat', 'labelKey': 'daySatShort'},
    {'key': 'Sun', 'labelKey': 'daySunShort'},
  ];

  String get _resolvedPacksPerDay {
    if (packOption == '3+ paket') {
      return highPackOption ?? '4 paket';
    }
    return packOption;
  }

  String _professionLabel(String value, BuildContext context) {
    switch (value) {
      case 'Öğrenci':
        return context.t('professionStudent');
      case 'Memur':
        return context.t('professionOfficer');
      case 'İşçi':
        return context.t('professionWorker');
      case 'Sağlık Çalışanı':
        return context.t('professionHealthcare');
      case 'Öğretmen':
        return context.t('professionTeacher');
      case 'Mühendis':
        return context.t('professionEngineer');
      case 'Esnaf':
        return context.t('professionTradesman');
      case 'Emekli':
        return context.t('professionRetired');
      case 'Serbest Çalışıyor':
        return context.t('professionFreelance');
      case 'Diğer':
        return context.t('professionOther');
      default:
        return value;
    }
  }

  // Parse HH:MM time string to (hours, minutes)
  (int, int) _parseTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return (7, 0);
    final parts = timeStr.split(':');
    if (parts.length != 2) return (7, 0);
    final h = int.tryParse(parts[0]) ?? 7;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h, m);
  }

  // Format hours and minutes to HH:MM
  String _formatTime(int hours, int minutes) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  // Build time picker with separate hour and minute dropdowns
  Widget _buildTimePickerRow({
    required String label,
    required String? currentValue,
    required List<int> minuteOptions,
    required Function(String) onChanged,
  }) {
    final (currentHour, currentMinute) = _parseTimeString(currentValue);
    final hourList = List.generate(24, (i) => i);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Hours dropdown
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: currentHour,
                  items: hourList.map((h) {
                    return DropdownMenuItem(
                      value: h,
                      child: Text(
                        h.toString().padLeft(2, '0'),
                        style: const TextStyle(fontSize: 18),
                      ),
                    );
                  }).toList(),
                  onChanged: (newHour) {
                    if (newHour != null) {
                      onChanged(_formatTime(newHour, currentMinute));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                ':',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              // Minutes dropdown
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: minuteOptions.contains(currentMinute) ? currentMinute : minuteOptions.first,
                  items: minuteOptions.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(
                        m.toString().padLeft(2, '0'),
                        style: const TextStyle(fontSize: 18),
                      ),
                    );
                  }).toList(),
                  onChanged: (newMinute) {
                    if (newMinute != null) {
                      onChanged(_formatTime(currentHour, newMinute));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _selectedTriggerLabels() {
    final mapping = <String, String>{
      'coffee': 'Kahve',
      'meal': 'Yemek Sonrasi',
      'driving': 'Arac',
      'stress': 'Stres',
      'phone': 'Telefon',
      'social': 'Sosyal Ortam',
      'alcohol': 'Alkol',
    };
    return triggerSet.map((key) => mapping[key] ?? key).toList();
  }

  List<String> _selectedHealthConditions() {
    final health = <String>[];
    if (hypertension) health.add('Hipertansiyon');
    if (asthma) health.add('Astim');
    if (diabetes) health.add('Diyabet');
    if (copd) health.add('KOAH');
    if (heartDisease) health.add('Kalp Hastaligi');
    return health;
  }

  List<Map<String, String>> _selectedBreakWindows() {
    final result = <Map<String, String>>[];
    if (hasSmokingBreaks &&
        breakStart1 != null &&
        breakEnd1 != null &&
        breakStart1!.isNotEmpty &&
        breakEnd1!.isNotEmpty) {
      result.add({'start': breakStart1!, 'end': breakEnd1!});
    }
    if (hasSmokingBreaks &&
        hasSecondBreak &&
        breakStart2 != null &&
        breakEnd2 != null &&
        breakStart2!.isNotEmpty &&
        breakEnd2!.isNotEmpty) {
      result.add({'start': breakStart2!, 'end': breakEnd2!});
    }
    return result;
  }

  Future<String> _saveInitialSurveyRecord() async {
    final initialTitle = context.t('initialRecordTitle');
    final recordId = DateTime.now().millisecondsSinceEpoch.toString();
    final selectedTriggers = _selectedTriggerLabels();
    final selectedHealth = _selectedHealthConditions();
    final inferredWorkStart = _resolvedWorkStartForStorage();
    final inferredWorkEnd = _resolvedWorkEndForStorage();
    final inferredWorkingDays = _resolvedWorkingDaysForStorage();
    final inferredWeekendPattern = _resolvedWeekendPatternForStorage();
    final inferredBreakWindows = _resolvedBreakWindowsForStorage(
      workStart: inferredWorkStart,
      workEnd: inferredWorkEnd,
    );

    debugPrint(
      '[SurveyPage] save start: recordId=$recordId, name=${nameController.text.trim()}, '
      'profession=${profession ?? 'null'}, workStart=${workStartTime ?? 'null'}, workEnd=${workEndTime ?? 'null'}',
    );

    final record = SurveyRecord(
      id: recordId,
      completedAt: DateTime.now(),
      type: 'initial',
      title: initialTitle,
      name: nameController.text.trim(),
      packsPerDay: _resolvedPacksPerDay,
      exhaleTestSeconds: 0,
      inhaleTestSeconds: 0,
      riskScore: 0,
      riskLevel: 'BAŞLANGIÇ',
      consecutiveSmokingHabit: consecutiveSmokingHabit,
      consecutiveSmokingCount: consecutiveSmokingHabit == 'Evet'
          ? consecutiveSmokingCount
          : null,
      quitDate: DateTime.now(), // Sigara bırakma başlangıcı
    );

    try {
      await _storageService.saveSurveyRecord(record);
      debugPrint('[SurveyPage] saveSurveyRecord ok: $recordId');
    } catch (error, stackTrace) {
      debugPrint('[SurveyPage] saveSurveyRecord failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    try {
      await _storageService.saveSurveyDetail(
        recordId: recordId,
        triggers: selectedTriggers,
        healthConditions: selectedHealth,
        firstCigaretteRange: firstCigaretteRange,
        smokeFreeRange: smokeFreeRange,
        profession: profession,
        sleepTime: sleepTime,
        wakeTime: wakeTime,
        stressLevel: stressLevel,
        quitReason: quitReason,
        workStart: inferredWorkStart,
        workEnd: inferredWorkEnd,
        workplaceSmokingRule: workplaceSmokingRule,
        workingDays: inferredWorkingDays,
        breakWindows: inferredBreakWindows,
        weekendSmokingPattern: inferredWeekendPattern,
      );
      debugPrint('[SurveyPage] saveSurveyDetail ok: $recordId');
    } catch (error, stackTrace) {
      debugPrint('[SurveyPage] saveSurveyDetail failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    try {
      await _storageService.saveSleepTime(sleepTime!);
      await _storageService.saveSetting('wake_time', wakeTime!);
      await _storageService.saveSetting('daily_breath_test_target', '1');
      debugPrint('[SurveyPage] saveSleepTime ok: $sleepTime');
    } catch (error, stackTrace) {
      debugPrint('[SurveyPage] saveSleepTime failed (non-blocking): $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final normalizedPreference = durationBarrierPreference == 'Begeniyorum'
        ? 'like'
        : durationBarrierPreference == 'Begenmiyorum'
        ? 'dislike'
        : durationBarrierPreference == 'Istemiyorum'
        ? 'off'
        : 'neutral';
    final normalizedFrequency = durationBarrierFrequencyPreference == 'Az'
        ? 'az'
        : durationBarrierFrequencyPreference == 'Cok'
        ? 'cok'
        : 'orta';
    final enabled = normalizedPreference == 'off' ? '0' : '1';

    try {
      await _storageService.saveSetting(
        'duration_barrier_preference',
        normalizedPreference,
      );
      await _storageService.saveSetting(
        'duration_barrier_frequency_preference',
        normalizedFrequency,
      );
      await _storageService.saveSetting('duration_barrier_enabled', enabled);
      debugPrint('[SurveyPage] save duration barrier preferences ok');
    } catch (error, stackTrace) {
      debugPrint(
        '[SurveyPage] save duration barrier preferences failed (non-blocking): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    return recordId;
  }

  Future<void> _saveInitialProfileSnapshot(String recordId) async {
    final selectedTriggers = _selectedTriggerLabels();
    final selectedHealth = _selectedHealthConditions();

    // Create profile after user passes through the bulk permission step.
    try {
      await _storageService.saveUserProfileSnapshot(
        UserProfileSnapshot(
          id: 'profile_$recordId',
          createdAt: DateTime.now(),
          riskScore: 0,
          packsPerDay: _resolvedPacksPerDay,
          firstCigaretteRange: firstCigaretteRange,
          smokeFreeRange: smokeFreeRange,
          consecutiveSmokingHabit: consecutiveSmokingHabit ?? 'Hayır',
          consecutiveSmokingCount: consecutiveSmokingCount,
          triggers: selectedTriggers,
          healthConditions: selectedHealth,
          profession: profession ?? 'Belirtilmedi',
          sleepTime: sleepTime!,
          wakeTime: wakeTime!,
          latestExhaleSeconds: 0,
          latestInhaleSeconds: 0,
        ),
      );
      debugPrint('[SurveyPage] saveUserProfileSnapshot ok: profile_$recordId');
    } catch (error, stackTrace) {
      debugPrint(
        '[SurveyPage] saveUserProfileSnapshot failed (non-blocking): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _runBulkPermissionFlow(String recordId) async {
    // Ask required permissions right after initial survey is created.
    var result = await PermissionService.requestOnboardingPermissions();
    if (!mounted) {
      return;
    }

    while (!result.notificationsGranted && mounted) {
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.t('permissionsRetryTitle')),
          content: Text(context.t('permissionsRetryMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('continue'),
              child: Text(context.t('continueWithoutPermission')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('exact'),
              child: Text(context.t('openAlarmReminderSettings')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('settings'),
              child: Text(context.t('openSettings')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('retry'),
              child: Text(context.t('retry')),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }

      if (action == 'continue') {
        break;
      }

      if (action == 'settings') {
        await PermissionService.openPermissionSettings();
      }

      if (action == 'exact') {
        await PermissionService.openExactAlarmSettingsOptional();
      }

      result = await PermissionService.requestOnboardingPermissions();
      if (!mounted) {
        return;
      }
    }

    if (!result.telemetryGranted) {
      _showValidationMessage(context.t('sensorPermissionRecommended'));
    }

    if (!result.notificationsGranted) {
      _showValidationMessage(context.t('notificationPermissionRequired'));
    }

    await _saveInitialProfileSnapshot(recordId);

    if (result.notificationsGranted) {
      try {
        await NotificationService.scheduleAdaptiveDailyBreathReminders(
          sleepTime: sleepTime!,
          wakeTime: wakeTime!,
          minimumCount: 1,
          preferredCount: 1,
        );
        debugPrint('[SurveyPage] scheduleDailyBreathReminder ok');
      } catch (error, stackTrace) {
        debugPrint(
          '[SurveyPage] scheduleDailyBreathReminder failed (non-blocking): $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  String? _missingRequiredFieldMessage() {
    if (nameController.text.trim().isEmpty) {
      return context.t('validationNameRequired');
    }
    if (ageController.text.trim().isEmpty) {
      return context.t('validationAgeRequired');
    }
    if (gender == null || gender!.isEmpty) {
      return context.t('validationGenderRequired');
    }
    // Profession/smoking-years are optional to keep onboarding lightweight.
    if (consecutiveSmokingHabit == null || consecutiveSmokingHabit!.isEmpty) {
      return context.t('validationChainHabitRequired');
    }
    if (consecutiveSmokingHabit == 'Evet' &&
        (consecutiveSmokingCount == null || consecutiveSmokingCount!.isEmpty)) {
      return context.t('validationChainCountRequired');
    }
    if (sleepTime == null || sleepTime!.isEmpty) {
      return context.t('validationSleepTimeRequired');
    }
    if (wakeTime == null || wakeTime!.isEmpty) {
      return context.t('validationWakeTimeRequired');
    }
    // Work schedule and break windows are inferred in background when omitted.
    return null;
  }

  String _resolvedWorkStartForStorage() {
    if (workStartTime != null && workStartTime!.trim().isNotEmpty) {
      return workStartTime!;
    }
    final wake = wakeTime ?? '07:00';
    final wakeMinutes = _parseMinutes(wake) ?? (7 * 60);
    return _formatMinutes((wakeMinutes + 120) % (24 * 60));
  }

  String _resolvedWorkEndForStorage() {
    if (workEndTime != null && workEndTime!.trim().isNotEmpty) {
      return workEndTime!;
    }
    final start = _parseMinutes(_resolvedWorkStartForStorage()) ?? (9 * 60);
    return _formatMinutes((start + (8 * 60)) % (24 * 60));
  }

  List<String> _resolvedWorkingDaysForStorage() {
    if (workingDays.isNotEmpty) {
      return workingDays.toList();
    }
    return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  }

  String _resolvedWeekendPatternForStorage() {
    final value = weekendSmokingPattern.trim();
    return value.isEmpty ? 'Ayni' : value;
  }

  List<Map<String, String>> _resolvedBreakWindowsForStorage({
    required String workStart,
    required String workEnd,
  }) {
    final selected = _selectedBreakWindows();
    if (selected.isNotEmpty || workplaceSmokingRule != 'Sadece molalarda') {
      return selected;
    }

    // If user skips break details, infer a single mid-shift smoking break.
    final start = _parseMinutes(workStart);
    final end = _parseMinutes(workEnd);
    if (start == null || end == null) {
      return const [
        {'start': '12:30', 'end': '13:00'},
      ];
    }

    final duration = end >= start ? (end - start) : ((24 * 60) - start + end);
    final mid = (start + (duration ~/ 2)) % (24 * 60);
    final breakStart = (mid - 15) < 0 ? (24 * 60) + (mid - 15) : (mid - 15);
    final breakEnd = (breakStart + 30) % (24 * 60);
    return [
      {'start': _formatMinutes(breakStart), 'end': _formatMinutes(breakEnd)},
    ];
  }

  int? _parseMinutes(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return (hour.clamp(0, 23) * 60) + minute.clamp(0, 59);
  }

  String _formatMinutes(int totalMinutes) {
    final safe = ((totalMinutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    final hour = (safe ~/ 60).toString().padLeft(2, '0');
    final minute = (safe % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showValidationMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NoSmokeLogo(size: 110, showLabel: true),
              const SizedBox(height: 20),
              Text(
                context.t('initialSurvey'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.t('name'),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.t('age'),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const ValueKey('gender_dropdown'),
                initialValue: gender,
                decoration: InputDecoration(
                  labelText: context.t('gender'),
                  border: OutlineInputBorder(),
                ),
                hint: Text(context.t('selectOption')),
                items: [
                  DropdownMenuItem(
                    value: 'Erkek',
                    child: Text(context.t('male')),
                  ),
                  DropdownMenuItem(
                    value: 'Kadın',
                    child: Text(context.t('female')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    gender = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const ValueKey('profession_dropdown'),
                initialValue: profession,
                decoration: InputDecoration(
                  labelText: context.t('professionLabel'),
                  border: OutlineInputBorder(),
                ),
                hint: Text(context.t('selectOption')),
                items: professionOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_professionLabel(value, context)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    profession = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              sectionTitle(context.t('smokingInfo')),
              PacksPerDaySection(
                selectedPackOption: packOption,
                selectedHighPackOption: highPackOption,
                onPackOptionChanged: (value) {
                  setState(() {
                    packOption = value;
                    if (value != '3+ paket') {
                      highPackOption = null;
                    } else {
                      highPackOption ??=
                          PacksPerDaySection.highPackOptions.first;
                    }
                  });
                },
                onHighPackOptionChanged: (value) {
                  setState(() {
                    highPackOption = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: firstCigaretteRange,
                decoration: InputDecoration(
                  labelText: context.t('firstCigaretteWhen'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: '0-5',
                    child: Text(context.t('firstCigarette0to5')),
                  ),
                  DropdownMenuItem(
                    value: '5-10',
                    child: Text(context.t('firstCigarette5to10')),
                  ),
                  DropdownMenuItem(
                    value: '10-30',
                    child: Text(context.t('firstCigarette10to30')),
                  ),
                  DropdownMenuItem(
                    value: '30-60',
                    child: Text(context.t('firstCigarette30to60')),
                  ),
                  DropdownMenuItem(
                    value: '60+',
                    child: Text(context.t('firstCigarette60plus')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    firstCigaretteRange = value!;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: smokeFreeRange,
                decoration: InputDecoration(
                  labelText: context.t('maxSmokeFreeDuration'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: '0-15',
                    child: Text(context.t('smokeFree0to15')),
                  ),
                  DropdownMenuItem(
                    value: '15-30',
                    child: Text(context.t('smokeFree15to30')),
                  ),
                  DropdownMenuItem(
                    value: '30-60',
                    child: Text(context.t('smokeFree30to60')),
                  ),
                  DropdownMenuItem(
                    value: '60-120',
                    child: Text(context.t('smokeFree60to120')),
                  ),
                  DropdownMenuItem(
                    value: '120-240',
                    child: Text(context.t('smokeFree120to240')),
                  ),
                  DropdownMenuItem(
                    value: '240+',
                    child: Text(context.t('smokeFree240plus')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    smokeFreeRange = value!;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: smokingYears,
                decoration: InputDecoration(
                  labelText: context.t('smokingYears'),
                  hintText: 'örn: 5',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    smokingYears = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '';
                  }
                  final intValue = int.tryParse(value);
                  if (intValue == null || intValue < 0 || intValue > 100) {
                    return context.t('validationSmokeYearsRange');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              ConsecutiveSmokingSection(
                consecutiveSmokingHabit: consecutiveSmokingHabit,
                consecutiveSmokingCount: consecutiveSmokingCount,
                onHabitChanged: (value) {
                  setState(() {
                    consecutiveSmokingHabit = value;
                    if (value != 'Evet') {
                      consecutiveSmokingCount = null;
                    }
                  });
                },
                onCountChanged: (value) {
                  setState(() {
                    consecutiveSmokingCount = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              sectionTitle(context.t('lifeRoutine')),
              _buildTimePickerRow(
                label: context.t('sleepTime'),
                currentValue: sleepTime,
                minuteOptions: [0, 15, 30, 45],
                onChanged: (value) {
                  setState(() {
                    sleepTime = value;
                  });
                },
              ),
              _buildTimePickerRow(
                label: context.t('wakeTime'),
                currentValue: wakeTime,
                minuteOptions: [0, 15, 30, 45],
                onChanged: (value) {
                  setState(() {
                    wakeTime = value;
                  });
                },
              ),
              _buildTimePickerRow(
                label: context.t('workStart'),
                currentValue: workStartTime,
                minuteOptions: [0, 30],
                onChanged: (value) {
                  setState(() {
                    workStartTime = value;
                  });
                },
              ),
              _buildTimePickerRow(
                label: context.t('workEnd'),
                currentValue: workEndTime,
                minuteOptions: [0, 30],
                onChanged: (value) {
                  setState(() {
                    workEndTime = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: workplaceSmokingRule,
                decoration: InputDecoration(
                  labelText: context.t('workplaceSmoking'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Evet',
                    child: Text(context.t('yes')),
                  ),
                  DropdownMenuItem(
                    value: 'Hayır',
                    child: Text(context.t('no')),
                  ),
                  DropdownMenuItem(
                    value: 'Sadece molalarda',
                    child: Text(context.t('onlyBreaks')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    workplaceSmokingRule = value!;
                    if (workplaceSmokingRule == 'Hayır') {
                      hasSmokingBreaks = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.t('workDaysLabel'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: workDayOptions.map((day) {
                  final key = day['key']!;
                  final selected = workingDays.contains(key);
                  return FilterChip(
                    label: Text(context.t(day['labelKey']!)),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          workingDays.add(key);
                        } else {
                          workingDays.remove(key);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: weekendSmokingPattern,
                decoration: InputDecoration(
                  labelText: context.t('weekendPatternLabel'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Ayni',
                    child: Text(context.t('weekendPatternSame')),
                  ),
                  DropdownMenuItem(
                    value: 'HaftaSonuDahaFazla',
                    child: Text(context.t('weekendPatternMore')),
                  ),
                  DropdownMenuItem(
                    value: 'HaftaSonuDahaAz',
                    child: Text(context.t('weekendPatternLess')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    weekendSmokingPattern = value ?? 'Ayni';
                  });
                },
              ),
              const SizedBox(height: 10),
              if (workplaceSmokingRule != 'Hayır')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('smokingBreakExists')),
                  value: hasSmokingBreaks,
                  onChanged: (value) {
                    setState(() {
                      hasSmokingBreaks = value;
                      if (!value) {
                        hasSecondBreak = false;
                        breakStart1 = null;
                        breakEnd1 = null;
                        breakStart2 = null;
                        breakEnd2 = null;
                      }
                    });
                  },
                ),
              if (workplaceSmokingRule != 'Hayır' && hasSmokingBreaks) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: breakStart1,
                  decoration: InputDecoration(
                    labelText: context.t('break1Start'),
                    border: const OutlineInputBorder(),
                  ),
                  hint: Text(context.t('selectOption')),
                  items: workTimeOptions
                      .map(
                        (time) => DropdownMenuItem<String>(
                          value: time,
                          child: Text(time),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      breakStart1 = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: breakEnd1,
                  decoration: InputDecoration(
                    labelText: context.t('break1End'),
                    border: const OutlineInputBorder(),
                  ),
                  hint: Text(context.t('selectOption')),
                  items: workTimeOptions
                      .map(
                        (time) => DropdownMenuItem<String>(
                          value: time,
                          child: Text(time),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      breakEnd1 = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('break2Exists')),
                  value: hasSecondBreak,
                  onChanged: (value) {
                    setState(() {
                      hasSecondBreak = value;
                      if (!value) {
                        breakStart2 = null;
                        breakEnd2 = null;
                      }
                    });
                  },
                ),
                if (hasSecondBreak) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: breakStart2,
                    decoration: InputDecoration(
                      labelText: context.t('break2Start'),
                      border: const OutlineInputBorder(),
                    ),
                    hint: Text(context.t('selectOption')),
                    items: workTimeOptions
                        .map(
                          (time) => DropdownMenuItem<String>(
                            value: time,
                            child: Text(time),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        breakStart2 = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: breakEnd2,
                    decoration: InputDecoration(
                      labelText: context.t('break2End'),
                      border: const OutlineInputBorder(),
                    ),
                    hint: Text(context.t('selectOption')),
                    items: workTimeOptions
                        .map(
                          (time) => DropdownMenuItem<String>(
                            value: time,
                            child: Text(time),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        breakEnd2 = value;
                      });
                    },
                  ),
                ],
              ],
              const SizedBox(height: 20),
              sectionTitle(context.t('healthStatus')),
              CheckboxListTile(
                value: hypertension,
                title: Text(context.t('hypertension')),
                onChanged: (value) =>
                    setState(() => hypertension = value ?? false),
              ),
              CheckboxListTile(
                value: asthma,
                title: Text(context.t('asthma')),
                onChanged: (value) => setState(() => asthma = value ?? false),
              ),
              CheckboxListTile(
                value: diabetes,
                title: Text(context.t('diabetes')),
                onChanged: (value) => setState(() => diabetes = value ?? false),
              ),
              CheckboxListTile(
                value: copd,
                title: Text(context.t('copd')),
                onChanged: (value) => setState(() => copd = value ?? false),
              ),
              CheckboxListTile(
                value: heartDisease,
                title: Text(context.t('heartDisease')),
                onChanged: (value) =>
                    setState(() => heartDisease = value ?? false),
              ),
              const SizedBox(height: 20),
              sectionTitle(context.t('triggerTitle')),
              triggerTile(context.t('triggerCoffee'), 'coffee'),
              triggerTile(context.t('triggerMeal'), 'meal'),
              triggerTile(context.t('triggerDriving'), 'driving'),
              triggerTile(context.t('triggerStress'), 'stress'),
              triggerTile(context.t('triggerPhone'), 'phone'),
              triggerTile(context.t('triggerSocial'), 'social'),
              triggerTile(context.t('triggerAlcohol'), 'alcohol'),
              const SizedBox(height: 20),
              sectionTitle(context.t('stressTitle')),
              DropdownButtonFormField<String>(
                initialValue: stressLevel,
                decoration: InputDecoration(
                  labelText: context.t('stressTitle'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Düşük',
                    child: Text(context.t('stressLow')),
                  ),
                  DropdownMenuItem(
                    value: 'Orta',
                    child: Text(context.t('stressMedium')),
                  ),
                  DropdownMenuItem(
                    value: 'Yüksek',
                    child: Text(context.t('stressHigh')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    stressLevel = value!;
                  });
                },
              ),
              const SizedBox(height: 10),
              sectionTitle(context.t('quitReasonTitle')),
              DropdownButtonFormField<String>(
                initialValue: quitReason,
                decoration: InputDecoration(
                  labelText: context.t('quitReason'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Sağlık',
                    child: Text(context.t('quitHealth')),
                  ),
                  DropdownMenuItem(
                    value: 'Aile',
                    child: Text(context.t('quitFamily')),
                  ),
                  DropdownMenuItem(
                    value: 'Maddi sebepler',
                    child: Text(context.t('quitMoney')),
                  ),
                  DropdownMenuItem(
                    value: 'Çocuklar',
                    child: Text(context.t('quitChildren')),
                  ),
                  DropdownMenuItem(
                    value: 'Performans',
                    child: Text(context.t('quitPerformance')),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    quitReason = value!;
                  });
                },
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  key: const ValueKey('survey_continue_button'),
                  onPressed: () async {
                    _formKey.currentState?.validate();
                    final missingMessage = _missingRequiredFieldMessage();
                    final saveErrorMessage = context.t('saveErrorRetry');

                    if (missingMessage != null) {
                      if (!mounted) return;
                      _showValidationMessage(missingMessage);
                      return;
                    }

                    late final String recordId;
                    try {
                      recordId = await _saveInitialSurveyRecord();
                    } catch (error, stackTrace) {
                      debugPrint(
                        '[SurveyPage] Initial survey save failed: $error',
                      );
                      debugPrintStack(stackTrace: stackTrace);
                      if (!mounted) return;
                      _showValidationMessage(saveErrorMessage);
                      return;
                    }

                    await _runBulkPermissionFlow(recordId);

                    if (!mounted) return;

                    if (!context.mounted) return;
                    final navigator = Navigator.of(context);
                    await navigator.push(
                      MaterialPageRoute(
                        builder: (_) => BreathTestPage(
                          name: nameController.text.trim(),
                          packsPerDay: _resolvedPacksPerDay,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    context.t('continue'),
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
