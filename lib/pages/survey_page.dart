import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../core/app_texts.dart';
import '../models/medication.dart';
import '../models/survey_record.dart';
import '../models/user_profile_snapshot.dart';
import '../services/ambient_audio_service.dart';
import '../services/device_permission_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../widgets/consecutive_smoking_section.dart';
import '../widgets/no_smoke_logo.dart';
import '../widgets/packs_per_day_section.dart';
import '../widgets/survey_wizard.dart';
import 'breath_test_page.dart';
import 'permission_setup_page.dart';
import 'smoked_log_consent_page.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> with WidgetsBindingObserver {
  static const _draftSettingKey = 'survey_draft_v1';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  String? gender;
  String? profession;
  String? smokingYears;
  String? cigarettesPerPack;
  String? firstCigaretteRange;
  String smokeFreeRange = '30-60';
  String workplaceSmokingRule = 'Hayır';
  String stressLevel = 'Orta';
  String interventionIntensity = 'balanced';
  String quitReason = 'Sağlık';
  String? sleepTime;
  String? wakeTime;
  String? workStartTime;
  String? workEndTime;
  final Set<String> workingDays = <String>{};
  bool hasSmokingBreaks = false;
  String? breakStart1;
  String? breakEnd1;
  bool hasSecondBreak = false;
  String? breakStart2;
  String? breakEnd2;
  String weekendSmokingPattern = 'Ayni';
  String? schoolType;
  String packOption = '1 paketten az';
  String? consecutiveSmokingHabit;
  String? consecutiveSmokingCount;
  String durationBarrierPreference = 'Farketmez';
  String durationBarrierFrequencyPreference = 'Orta';

  bool hypertension = false;
  bool asthma = false;
  bool diabetes = false;
  bool copd = false;
  bool heartDisease = false;
  bool otherHealthCondition = false;
  final otherHealthConditionController = TextEditingController();
  bool usesMedication = false;
  final List<_MedicationDraft> medicationDrafts = [];

  final Set<String> triggerSet = <String>{};

  static const List<String> professionOptions = [
    'Ücretli',
    'Serbest Çalışıyor',
    'Öğrenci',
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

  String get _resolvedPacksPerDay => packOption;

  bool get _isStudent => profession == 'Öğrenci';
  bool get _isUniversityStudent => _isStudent && schoolType == 'Universite';

  String _professionLabel(String value, BuildContext context) {
    switch (value) {
      case 'Ücretli':
        return context.t('professionSalaried');
      // Kept for older survey records saved before the profession list was
      // trimmed down to Ücretli/Esnaf/Serbest/Diğer — never offered as a
      // choice anymore, but still needs to render correctly if it comes
      // back out of storage.
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

  // Tap-to-open native time picker. Shows a neutral "Seçiniz" placeholder
  // until the user actually picks a time — previously this rendered two
  // inline hour/minute dropdowns that always displayed a hardcoded 07:00
  // even when nothing had been chosen yet, which looked like a real
  // (unintentional) selection.
  Widget _buildTimePickerRow({
    required String label,
    required String? currentValue,
    required Function(String) onChanged,
  }) {
    final hasValue = currentValue != null && currentValue.isNotEmpty;
    final (currentHour, currentMinute) = _parseTimeString(currentValue);

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
          InkWell(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: hasValue ? currentHour : TimeOfDay.now().hour,
                  minute: hasValue ? currentMinute : 0,
                ),
              );
              if (picked != null) {
                onChanged(_formatTime(picked.hour, picked.minute));
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              child: Text(
                hasValue
                    ? _formatTime(currentHour, currentMinute)
                    : context.t('selectOption'),
                style: TextStyle(
                  fontSize: 18,
                  color: hasValue ? null : Theme.of(context).hintColor,
                ),
              ),
            ),
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
    if (otherHealthCondition && otherHealthConditionController.text.trim().isNotEmpty) {
      health.add(otherHealthConditionController.text.trim());
    }
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
        age: int.tryParse(ageController.text.trim()),
        smokingYears: int.tryParse(smokingYears ?? ''),
        cigarettesPerPack: int.tryParse(cigarettesPerPack ?? ''),
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
      if (gender != null && gender!.isNotEmpty) {
        await _storageService.saveSetting('gender', gender!);
      }
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

    try {
      final medications = _collectValidMedications();
      for (final medication in medications) {
        await _storageService.saveMedication(medication);
      }
      await NotificationService.scheduleMedicationReminders(medications);
      debugPrint(
        '[SurveyPage] save medications ok: count=${medications.length}',
      );
    } catch (error, stackTrace) {
      debugPrint('[SurveyPage] save medications failed (non-blocking): $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return recordId;
  }

  List<Medication> _collectValidMedications() {
    if (!usesMedication) return [];
    final now = DateTime.now();
    final medications = <Medication>[];
    for (var i = 0; i < medicationDrafts.length; i++) {
      final draft = medicationDrafts[i];
      final name = draft.nameController.text.trim();
      if (name.isEmpty || draft.times.isEmpty) continue;
      medications.add(
        Medication(
          id: '${now.millisecondsSinceEpoch}_$i',
          name: name,
          times: List<String>.from(draft.times),
          createdAt: now,
        ),
      );
    }
    return medications;
  }

  /// Introduces the floating "I smoked" button once, during setup.
  ///
  /// The button is the app's only source of ground truth about when someone
  /// actually smokes — the barrier length and the risky-hour ranking are both
  /// computed from it. It used to be reachable only from a switch in
  /// settings, so a new user had no reason to know it existed, and the
  /// disclosure written for it was never shown to anyone who did not go
  /// looking. Offered here because it is the moment the overlay permission
  /// it depends on has just been dealt with.
  ///
  /// Declining is free: the button stays off and nothing asks again.
  Future<void> _offerQuickLogButton() async {
    if (!mounted) return;
    await offerSmokedLogButton(context);
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
          firstCigaretteRange: firstCigaretteRange!,
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
    // Explain the discipline-protocol mechanism (compliance logging,
    // sensor-based risk inference, full-screen task alerts) BEFORE asking
    // for the microphone/activity-recognition permissions it depends on —
    // those permissions must never be requested without the user first
    // understanding what they're being used for.
    if (mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.t('disciplineDisclosureTitle')),
          content: SingleChildScrollView(
            child: Text(context.t('disciplineDisclosureMessage')),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.t('disciplineDisclosureAcknowledge')),
            ),
          ],
        ),
      );
    }
    if (!mounted) {
      return;
    }

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

    // Everything the task system still needs beyond the runtime permissions
    // requested above — "display over other apps", and on some devices the
    // manufacturer's own notification editor — is handled on one screen.
    //
    // These used to be two consecutive dialogs. Worded near-identically and
    // carrying the same two buttons, the second arriving right after the
    // user got back from Settings read as the first one having reappeared;
    // and neither rechecked anything afterwards, so granting was never
    // acknowledged. The screen re-reads every row on resume instead.
    if (result.notificationsGranted && mounted) {
      final hasOverlay = await DevicePermissionService.hasOverlayPermission();
      final isMiui = await DevicePermissionService.isMiuiDevice();
      if ((!hasOverlay || isMiui) && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PermissionSetupPage(),
          ),
        );
      }
      if (mounted) {
        await _offerQuickLogButton();
      }
    }

    if (result.telemetryGranted) {
      await AmbientAudioService().startMonitoring();
    }

    await _saveInitialProfileSnapshot(recordId);
    await _storageService.saveInterventionIntensity(interventionIntensity);

    if (result.notificationsGranted) {
      try {
        await NotificationService.scheduleHealthConditionAdviceNotifications(
          healthConditions: _selectedHealthConditions(),
          sleepTime: sleepTime!,
          wakeTime: wakeTime!,
        );
        debugPrint('[SurveyPage] scheduleHealthConditionAdviceNotifications ok');
      } catch (error, stackTrace) {
        debugPrint(
          '[SurveyPage] scheduleHealthConditionAdviceNotifications failed (non-blocking): $error',
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
    if (firstCigaretteRange == null || firstCigaretteRange!.isEmpty) {
      return context.t('validationFirstCigaretteRequired');
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

  // Per-step gates for SurveyWizard's Next button — same fields and the
  // same messages as _missingRequiredFieldMessage above (which stays in
  // place as a final safety net on submit), just split by which step each
  // field actually lives on so the user is stopped and told what's missing
  // right where they are, instead of only at the very end.
  String? _validatePersonalInfoStep() {
    if (nameController.text.trim().isEmpty) {
      return context.t('validationNameRequired');
    }
    if (ageController.text.trim().isEmpty) {
      return context.t('validationAgeRequired');
    }
    if (gender == null || gender!.isEmpty) {
      return context.t('validationGenderRequired');
    }
    return null;
  }

  String? _validateSmokingInfoStep() {
    if (consecutiveSmokingHabit == null || consecutiveSmokingHabit!.isEmpty) {
      return context.t('validationChainHabitRequired');
    }
    if (consecutiveSmokingHabit == 'Evet' &&
        (consecutiveSmokingCount == null || consecutiveSmokingCount!.isEmpty)) {
      return context.t('validationChainCountRequired');
    }
    if (firstCigaretteRange == null || firstCigaretteRange!.isEmpty) {
      return context.t('validationFirstCigaretteRequired');
    }
    return null;
  }

  String? _validateLifeRoutineStep() {
    if (sleepTime == null || sleepTime!.isEmpty) {
      return context.t('validationSleepTimeRequired');
    }
    if (wakeTime == null || wakeTime!.isEmpty) {
      return context.t('validationWakeTimeRequired');
    }
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreDraftIfAny());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Persist whatever the user has entered so far whenever the app leaves
    // the foreground — this is the single moment most likely to precede
    // losing the in-progress survey (backgrounded, killed by the OS, etc).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(_saveDraft());
    }
  }

  Map<String, dynamic> _buildDraftMap() {
    return {
      'name': nameController.text,
      'age': ageController.text,
      'gender': gender,
      'profession': profession,
      'smokingYears': smokingYears,
      'cigarettesPerPack': cigarettesPerPack,
      'firstCigaretteRange': firstCigaretteRange,
      'smokeFreeRange': smokeFreeRange,
      'workplaceSmokingRule': workplaceSmokingRule,
      'stressLevel': stressLevel,
      'quitReason': quitReason,
      'sleepTime': sleepTime,
      'wakeTime': wakeTime,
      'workStartTime': workStartTime,
      'workEndTime': workEndTime,
      'workingDays': workingDays.toList(),
      'hasSmokingBreaks': hasSmokingBreaks,
      'breakStart1': breakStart1,
      'breakEnd1': breakEnd1,
      'hasSecondBreak': hasSecondBreak,
      'breakStart2': breakStart2,
      'breakEnd2': breakEnd2,
      'weekendSmokingPattern': weekendSmokingPattern,
      'packOption': packOption,
      'consecutiveSmokingHabit': consecutiveSmokingHabit,
      'consecutiveSmokingCount': consecutiveSmokingCount,
      'durationBarrierPreference': durationBarrierPreference,
      'durationBarrierFrequencyPreference': durationBarrierFrequencyPreference,
      'hypertension': hypertension,
      'asthma': asthma,
      'diabetes': diabetes,
      'copd': copd,
      'heartDisease': heartDisease,
      'otherHealthCondition': otherHealthCondition,
      'otherHealthConditionText': otherHealthConditionController.text,
      'triggers': triggerSet.toList(),
    };
  }

  void _applyDraft(Map<String, dynamic> draft) {
    setState(() {
      nameController.text = draft['name']?.toString() ?? '';
      ageController.text = draft['age']?.toString() ?? '';
      gender = draft['gender'] as String?;
      profession = draft['profession'] as String?;
      smokingYears = draft['smokingYears'] as String?;
      cigarettesPerPack = draft['cigarettesPerPack'] as String?;
      firstCigaretteRange =
          draft['firstCigaretteRange'] as String? ?? firstCigaretteRange;
      smokeFreeRange = draft['smokeFreeRange'] as String? ?? smokeFreeRange;
      workplaceSmokingRule =
          draft['workplaceSmokingRule'] as String? ?? workplaceSmokingRule;
      stressLevel = draft['stressLevel'] as String? ?? stressLevel;
      quitReason = draft['quitReason'] as String? ?? quitReason;
      sleepTime = draft['sleepTime'] as String?;
      wakeTime = draft['wakeTime'] as String?;
      workStartTime = draft['workStartTime'] as String?;
      workEndTime = draft['workEndTime'] as String?;
      final draftWorkingDays = draft['workingDays'] as List<dynamic>?;
      if (draftWorkingDays != null) {
        workingDays
          ..clear()
          ..addAll(draftWorkingDays.map((e) => e.toString()));
      }
      hasSmokingBreaks = draft['hasSmokingBreaks'] as bool? ?? hasSmokingBreaks;
      breakStart1 = draft['breakStart1'] as String?;
      breakEnd1 = draft['breakEnd1'] as String?;
      hasSecondBreak = draft['hasSecondBreak'] as bool? ?? hasSecondBreak;
      breakStart2 = draft['breakStart2'] as String?;
      breakEnd2 = draft['breakEnd2'] as String?;
      weekendSmokingPattern =
          draft['weekendSmokingPattern'] as String? ?? weekendSmokingPattern;
      packOption = draft['packOption'] as String? ?? packOption;
      consecutiveSmokingHabit = draft['consecutiveSmokingHabit'] as String?;
      consecutiveSmokingCount = draft['consecutiveSmokingCount'] as String?;
      durationBarrierPreference =
          draft['durationBarrierPreference'] as String? ??
          durationBarrierPreference;
      durationBarrierFrequencyPreference =
          draft['durationBarrierFrequencyPreference'] as String? ??
          durationBarrierFrequencyPreference;
      hypertension = draft['hypertension'] as bool? ?? false;
      asthma = draft['asthma'] as bool? ?? false;
      diabetes = draft['diabetes'] as bool? ?? false;
      copd = draft['copd'] as bool? ?? false;
      heartDisease = draft['heartDisease'] as bool? ?? false;
      otherHealthCondition = draft['otherHealthCondition'] as bool? ?? false;
      otherHealthConditionController.text =
          draft['otherHealthConditionText']?.toString() ?? '';
      final draftTriggers = draft['triggers'] as List<dynamic>?;
      if (draftTriggers != null) {
        triggerSet
          ..clear()
          ..addAll(draftTriggers.map((e) => e.toString()));
      }
    });
  }

  Future<void> _saveDraft() async {
    try {
      await _storageService.saveSetting(
        _draftSettingKey,
        jsonEncode(_buildDraftMap()),
      );
    } catch (_) {
      // Best-effort only — never let a draft-save failure interrupt the
      // user's actual survey flow.
    }
  }

  Future<void> _clearDraft() async {
    try {
      await _storageService.saveSetting(_draftSettingKey, '');
    } catch (_) {
      // Ignore — worst case a stale draft prompt reappears once.
    }
  }

  Future<void> _restoreDraftIfAny() async {
    final raw = await _storageService.loadSetting(_draftSettingKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    Map<String, dynamic>? draft;
    try {
      final decoded = jsonDecode(raw);
      draft = decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      draft = null;
    }
    if (draft == null || draft.isEmpty || !mounted) {
      return;
    }

    final shouldResume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('surveyDraftFoundTitle')),
        content: Text(context.t('surveyDraftFoundMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t('surveyDraftDiscard')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t('surveyDraftResume')),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (shouldResume == true) {
      _applyDraft(draft);
    } else {
      await _clearDraft();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nameController.dispose();
    ageController.dispose();
    otherHealthConditionController.dispose();
    for (final draft in medicationDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Widget _stepPersonalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NoSmokeLogo(size: 90, showLabel: true),
        const SizedBox(height: 16),
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: context.t('name'),
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
            hintText: context.t('age'),
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
          isExpanded: true,
          key: const ValueKey('gender_dropdown'),
          initialValue: gender,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
          ),
          hint: Text(context.t('gender')),
          items: [
            DropdownMenuItem(value: 'Erkek', child: Text(context.t('male'))),
            DropdownMenuItem(value: 'Kadın', child: Text(context.t('female'))),
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
          isExpanded: true,
          key: const ValueKey('profession_dropdown'),
          initialValue: profession,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
          ),
          hint: Text(context.t('professionLabel')),
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
          // Profession is genuinely optional (see _missingRequiredFieldMessage),
          // so this field must not render a "required" error — it never
          // blocks submission and shouldn't visually claim otherwise.
        ),
      ],
    );
  }

  Widget _stepSmokingInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PacksPerDaySection(
          selectedPackOption: packOption,
          onPackOptionChanged: (value) {
            setState(() {
              packOption = value;
            });
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: cigarettesPerPack,
          decoration: InputDecoration(
            hintText: context.t('cigarettesPerPackLabel'),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              cigarettesPerPack = value;
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: firstCigaretteRange,
          hint: Text(context.t('firstCigaretteWhen')),
          decoration: InputDecoration(
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
          isExpanded: true,
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
            hintText: context.t('smokingYears'),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              smokingYears = value;
            });
          },
          // Smoking-years is genuinely optional (see
          // _missingRequiredFieldMessage) — empty is fine and must not
          // error. If a value IS entered, it's still range-checked so
          // obviously bad data (negative, >100) doesn't get saved.
          validator: (value) {
            if (value == null || value.isEmpty) {
              return null;
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
      ],
    );
  }

  Widget _stepLifeRoutine() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTimePickerRow(
          label: context.t('sleepTime'),
          currentValue: sleepTime,
          onChanged: (value) {
            setState(() {
              sleepTime = value;
            });
          },
        ),
        _buildTimePickerRow(
          label: context.t('wakeTime'),
          currentValue: wakeTime,
          onChanged: (value) {
            setState(() {
              wakeTime = value;
            });
          },
        ),
        if (_isStudent) ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            key: const ValueKey('school_type_dropdown'),
            initialValue: schoolType,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
            ),
            hint: Text(context.t('schoolTypeLabel')),
            items: [
              DropdownMenuItem(
                value: 'Lise',
                child: Text(context.t('schoolTypeHighSchool')),
              ),
              DropdownMenuItem(
                value: 'Universite',
                child: Text(context.t('schoolTypeUniversity')),
              ),
            ],
            onChanged: (value) {
              setState(() {
                schoolType = value;
              });
            },
          ),
          const SizedBox(height: 10),
        ],
        _buildTimePickerRow(
          label: _isStudent
              ? (_isUniversityStudent
                  ? context.t('firstLectureStart')
                  : context.t('schoolStart'))
              : context.t('workStart'),
          currentValue: workStartTime,
          onChanged: (value) {
            setState(() {
              workStartTime = value;
            });
          },
        ),
        _buildTimePickerRow(
          label: _isStudent
              ? (_isUniversityStudent
                  ? context.t('lastLectureEnd')
                  : context.t('schoolEnd'))
              : context.t('workEnd'),
          currentValue: workEndTime,
          onChanged: (value) {
            setState(() {
              workEndTime = value;
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: workplaceSmokingRule,
          decoration: InputDecoration(
            labelText: _isStudent
                ? (_isUniversityStudent
                    ? context.t('campusSmoking')
                    : context.t('schoolSmoking'))
                : context.t('workplaceSmoking'),
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: 'Evet', child: Text(context.t('yes'))),
            DropdownMenuItem(value: 'Hayır', child: Text(context.t('no'))),
            DropdownMenuItem(
              value: 'Sadece molalarda',
              child: Text(
                _isStudent
                    ? context.t('onlyBreaksBetweenLectures')
                    : context.t('onlyBreaks'),
              ),
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
          alignment: AlignmentDirectional.centerStart,
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
          isExpanded: true,
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
            isExpanded: true,
            initialValue: breakStart1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
            ),
            hint: Text(context.t('break1Start')),
            items: workTimeOptions
                .map(
                  (time) =>
                      DropdownMenuItem<String>(value: time, child: Text(time)),
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
            isExpanded: true,
            initialValue: breakEnd1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
            ),
            hint: Text(context.t('break1End')),
            items: workTimeOptions
                .map(
                  (time) =>
                      DropdownMenuItem<String>(value: time, child: Text(time)),
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
              isExpanded: true,
              initialValue: breakStart2,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
              ),
              hint: Text(context.t('break2Start')),
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
              isExpanded: true,
              initialValue: breakEnd2,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
              ),
              hint: Text(context.t('break2End')),
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
      ],
    );
  }

  Widget _stepHealthStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: hypertension,
          title: Text(context.t('hypertension')),
          onChanged: (value) => setState(() => hypertension = value ?? false),
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
          onChanged: (value) => setState(() => heartDisease = value ?? false),
        ),
        CheckboxListTile(
          value: otherHealthCondition,
          title: Text(context.t('otherHealthCondition')),
          onChanged: (value) =>
              setState(() => otherHealthCondition = value ?? false),
        ),
        if (otherHealthCondition)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 8,
            ),
            child: TextField(
              controller: otherHealthConditionController,
              decoration: InputDecoration(
                hintText: context.t('otherHealthConditionHint'),
              ),
            ),
          ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: usesMedication,
          title: Text(context.t('usesMedicationQuestion')),
          onChanged: (value) => setState(() {
            usesMedication = value ?? false;
            if (usesMedication && medicationDrafts.isEmpty) {
              medicationDrafts.add(_MedicationDraft());
            }
          }),
        ),
        if (usesMedication) ..._buildMedicationDraftRows(),
        if (usesMedication)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => medicationDrafts.add(_MedicationDraft())),
                icon: const Icon(Icons.add),
                label: Text(context.t('addMedicationButton')),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildMedicationDraftRows() {
    return medicationDrafts.asMap().entries.map((entry) {
      final index = entry.key;
      final draft = entry.value;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: draft.nameController,
                        decoration: InputDecoration(
                          hintText: context.t('medicationNameHint'),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: medicationDrafts.length > 1
                          ? () => setState(() {
                              medicationDrafts.removeAt(index).dispose();
                            })
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final time in draft.times)
                      Chip(
                        label: Text(time),
                        onDeleted: () =>
                            setState(() => draft.times.remove(time)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add_alarm, size: 18),
                      label: Text(context.t('addMedicationTimeButton')),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked == null) return;
                        final formatted =
                            '${picked.hour.toString().padLeft(2, '0')}:'
                            '${picked.minute.toString().padLeft(2, '0')}';
                        setState(() {
                          if (!draft.times.contains(formatted)) {
                            draft.times.add(formatted);
                            draft.times.sort();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _stepTriggersAndStress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('triggerTitleHint'),
          style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 8),
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
          isExpanded: true,
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
        const SizedBox(height: 20),
        sectionTitle(context.t('interventionIntensityTitle')),
        Text(
          context.t('interventionIntensityHint'),
          style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: interventionIntensity,
          decoration: InputDecoration(
            labelText: context.t('interventionIntensityTitle'),
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'gentle',
              child: Text(context.t('interventionIntensityGentle')),
            ),
            DropdownMenuItem(
              value: 'balanced',
              child: Text(context.t('interventionIntensityBalanced')),
            ),
            DropdownMenuItem(
              value: 'strict',
              child: Text(context.t('interventionIntensityStrict')),
            ),
          ],
          onChanged: (value) {
            setState(() {
              interventionIntensity = value!;
            });
          },
        ),
      ],
    );
  }

  /// Runs the exact same validation → save → permission-flow → navigation
  /// sequence the old single-page "Devam Et" button used to run, now
  /// triggered from the wizard's final "Tamamla" button.
  Future<bool> _submitSurvey() async {
    // Both checks matter and neither alone is sufficient: field-level
    // validators (e.g. the smoking-years 0-100 range check) catch bad data
    // in fields that are otherwise optional, while _missingRequiredFieldMessage
    // enforces the fields that are genuinely required. Previously the Form's
    // validate() result was discarded, so a bad smoking-years value could be
    // silently saved despite showing a red error on screen.
    final isFieldDataValid = _formKey.currentState?.validate() ?? true;
    final missingMessage = _missingRequiredFieldMessage();
    final saveErrorMessage = context.t('saveErrorRetry');
    final invalidFieldMessage = context.t('validationFixHighlightedFields');

    if (missingMessage != null) {
      if (!mounted) return false;
      _showValidationMessage(missingMessage);
      return false;
    }

    if (!isFieldDataValid) {
      if (!mounted) return false;
      _showValidationMessage(invalidFieldMessage);
      return false;
    }

    late final String recordId;
    try {
      recordId = await _saveInitialSurveyRecord();
    } catch (error, stackTrace) {
      debugPrint('[SurveyPage] Initial survey save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return false;
      _showValidationMessage(saveErrorMessage);
      return false;
    }

    // The record is now durably saved — the in-progress draft is no
    // longer needed.
    unawaited(_clearDraft());

    await _runBulkPermissionFlow(recordId);

    if (!mounted) return false;
    if (!context.mounted) return false;

    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => BreathTestPage(
          name: nameController.text.trim(),
          packsPerDay: _resolvedPacksPerDay,
        ),
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SurveyWizard(
            finishLabel: context.t('continue'),
            nextLabel: context.t('continue'),
            backLabel: context.t('back'),
            steps: [
              SurveyStep(
                title: context.t('initialSurvey'),
                content: _stepPersonalInfo(),
                validate: _validatePersonalInfoStep,
              ),
              SurveyStep(
                title: context.t('smokingInfo'),
                content: _stepSmokingInfo(),
                validate: _validateSmokingInfoStep,
              ),
              SurveyStep(
                title: context.t('lifeRoutine'),
                content: _stepLifeRoutine(),
                validate: _validateLifeRoutineStep,
              ),
              SurveyStep(
                title: context.t('healthStatus'),
                content: _stepHealthStatus(),
              ),
              SurveyStep(
                title: context.t('triggerTitle'),
                subtitle: context.t('stressTitle'),
                content: _stepTriggersAndStress(),
              ),
            ],
            onFinish: _submitSurvey,
            onStepChanged: (_) => unawaited(_saveDraft()),
          ),
        ),
      ),
    );
  }
}

class _MedicationDraft {
  _MedicationDraft({String? name})
    : nameController = TextEditingController(text: name ?? '');

  final TextEditingController nameController;
  final List<String> times = [];

  void dispose() {
    nameController.dispose();
  }
}
