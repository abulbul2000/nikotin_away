import 'dart:async';
import 'dart:convert';
import 'dart:math' show max, min;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_texts.dart';
import '../core/mentor_command_codes.dart';
import '../engines/mentor_message_builder.dart';
import '../models/adaptive_plan.dart';
import '../models/adaptive_task_models.dart';
import '../models/behavior_dashboard.dart';
import '../models/breath_noise_baseline.dart';
import '../models/breath_progress_record.dart';
import '../models/breath_test_result.dart';
import '../models/cough_test_record.dart';
import '../models/mentor_message.dart';
import '../models/protocol_violation.dart';
import '../models/reduction_progress.dart';
import '../models/location_visit_event.dart';
import '../models/medication.dart';
import '../models/subscription_state.dart';
import '../models/sensor_usage_event.dart';
import '../models/significant_place.dart';
import '../models/sleep_probe_event.dart';
import '../models/snoring_probe_event.dart';
import '../models/smoking_count_discrepancy.dart';
import '../models/smoking_event.dart';
import '../models/task_assignment.dart';
import '../models/daily_progress_report.dart';
import '../models/step_counter_sample.dart';
import '../models/smoking_time_prediction.dart';
import '../models/survey_record.dart';
import '../models/task_history.dart';
import '../models/user_profile_snapshot.dart';
import '../engines/breath_test_engine.dart';
import '../engines/mentor_engine.dart';
import '../engines/prediction_engine.dart';
import '../engines/sleep_intelligence_engine.dart';
import '../engines/smoking_time_prediction_engine.dart';
import '../engines/step_trend_engine.dart';
import '../engines/wearable_signal_engine.dart';
import 'behavior_engine.dart';
import 'language_service.dart';
import 'discipline_protocol_service.dart';
import 'smoking_count_discrepancy_engine.dart';
import 'mentor_relief_service.dart';
import 'smoking_interval_service.dart';
import 'health_connect_service.dart';

class StorageService {
  static const _tableName = 'app_events';
  static const _settingsTable = 'app_settings';
  static const _surveyDetailsTable = 'survey_details';
  static const _profileSnapshotTable = 'user_profile_snapshots';
  static const _languageHistoryTable = 'language_history';
  static const _sensorUsageTable = 'sensor_usage_events';
  static const _sleepProbeTable = 'sleep_probe_events';
  static const _snoringProbeTable = 'snoring_probe_events';
  static const _significantPlacesTable = 'significant_places';
  static const _locationVisitEventsTable = 'location_visit_events';
  static const _stepCounterSamplesTable = 'step_counter_samples';
  static const _breathTestResultsTable = 'breath_test_results';
  static const _breathProgressRecordsTable = 'breath_progress_records';
  static const _breathNoiseBaselinesTable = 'breath_noise_baselines';
  static const _coughTestRecordsTable = 'cough_test_records';
  static const _behaviorSnapshotTable = 'behavior_snapshots';
  static const _taskFollowUpTable = 'task_followups';
  static const _protocolViolationTable = 'protocol_violations';
  static const _adaptiveTaskStateTable = 'adaptive_task_state';
  static const _adaptiveTaskEventTable = 'adaptive_task_events';
  static const _adaptiveHourlyProfileTable = 'adaptive_hourly_profile';
  static const _smokingEventsTable = 'smoking_events';
  static const _taskAssignmentsTable = 'task_assignments';
  static const _mentorMessagesTable = 'mentor_messages';
  static const _consentEventsTable = 'consent_events';
  static const _subscriptionStateTable = 'subscription_state';
  static const _failureTriggersTable = 'failure_triggers';
  static const _notificationsHistoryTable = 'notification_history';
  static const _behaviorDirtyKey = 'behavior_dirty';
  static const _registrationCompletedKey = 'registration_completed';
  static const _isProfileCompletedKey = 'isProfileCompleted';
  static const _surveyTypes = {'initial', 'weekly'};
  final BehaviorEngine _behaviorEngine = BehaviorEngine();
  final BreathTestEngine _breathTestEngine = BreathTestEngine();
  final StepTrendEngine _stepTrendEngine = StepTrendEngine();
  final WearableSignalEngine _wearableSignalEngine = WearableSignalEngine();
  final HealthConnectService _healthConnectService = HealthConnectService();
  final PredictionEngine _predictionEngine = PredictionEngine();
  final SleepIntelligenceEngine _sleepIntelligenceEngine =
      SleepIntelligenceEngine();
  final SmokingTimePredictionEngine _smokingTimePredictionEngine =
      SmokingTimePredictionEngine();
  final MentorMessageBuilder _mentorMessageBuilder = MentorMessageBuilder();
  final MentorEngine _mentorEngine = MentorEngine();
  final DisciplineProtocolService _disciplineProtocolService =
      DisciplineProtocolService();

  /// Injectable so tests can supply a seeded [Random] through
  /// [SmokingIntervalService]. `dailyTaskCount` applies a +/-1 jitter whose
  /// magnitude equals the frequency-preference adjustment itself, so without a
  /// fixed seed any assertion about frequency is a coin flip.
  final SmokingIntervalService _smokingIntervalService;

  StorageService({SmokingIntervalService? smokingIntervalService})
    : _smokingIntervalService =
          smokingIntervalService ?? SmokingIntervalService();
  final SmokingCountDiscrepancyEngine _smokingCountDiscrepancyEngine =
      const SmokingCountDiscrepancyEngine();
  Database? _database;

  static const List<String> cloudBackupTableNames = [
    _tableName,
    _settingsTable,
    _surveyDetailsTable,
    _profileSnapshotTable,
    _languageHistoryTable,
    _sensorUsageTable,
    _sleepProbeTable,
    _snoringProbeTable,
    _significantPlacesTable,
    _locationVisitEventsTable,
    _stepCounterSamplesTable,
    _breathTestResultsTable,
    _breathProgressRecordsTable,
    _breathNoiseBaselinesTable,
    _coughTestRecordsTable,
    _behaviorSnapshotTable,
    _taskFollowUpTable,
    _protocolViolationTable,
    _adaptiveTaskStateTable,
    _adaptiveTaskEventTable,
    _adaptiveHourlyProfileTable,
    _smokingEventsTable,
    _taskAssignmentsTable,
    _mentorMessagesTable,
    _consentEventsTable,
    _medicationsTable,
    _medicationDoseLogTable,
    _failureTriggersTable,
    _notificationsHistoryTable,
  ];

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Exports every user-owned local table. Subscription entitlements are
  /// deliberately excluded: they must be restored from the store/server,
  /// never from a client-controlled backup.
  Future<Map<String, List<Map<String, dynamic>>>> exportCloudBackup() async {
    final db = await database;
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in cloudBackupTableNames) {
      final rows = await db.query(table);
      result[table] = rows
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    return result;
  }

  /// Imports a cloud backup into an already-initialized local database.
  /// Upserts preserve any rows created on this device while restoring rows
  /// that are missing after a reinstall.
  Future<void> importCloudBackup(
    Map<String, List<Map<String, dynamic>>> backup,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in cloudBackupTableNames) {
        final rows = backup[table];
        if (rows == null) continue;
        for (final row in rows) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  static const String _dbFileName = 'no_smoke.db';

  Future<String> databaseFilePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, _dbFileName);
  }

  /// Closes the live sqflite connection so the underlying file can be
  /// safely overwritten (see CloudBackupService.restore) — the next call
  /// to [database] transparently reopens it from whatever is on disk at
  /// that point.
  Future<void> closeDatabaseConnection() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, _dbFileName);
    return openDatabase(
      path,
      // 22: smoking_events.placeId — which known place a cigarette happened
      // at, for the risky-hour ranking.
      // 23: task_assignments — the live lifecycle of an issued task, which
      // the append-only adaptive_task_events log was never shaped to hold.
      // 24: medication_dose_log — the taken/postponed answer to a
      // medication reminder notification.
      // 25: breath_test_results.{fev1EnergyIntegral,fvcEnergyIntegral,
      // fev1FvcRatioPercent,peakFlowIndex,peakFlowAtMs} — spirometry-style
      // presentation estimates from the forceful-exhale protocol.
      // 26: breath_progress_records — the user-facing score/duration/
      // stability/intensity record BreathTrendEngine summarizes, kept
      // separate from breath_test_results (the risk-engine's own internal
      // representation). breath_noise_baselines — per-attempt ambient noise
      // baseline readings BreathNoiseEngine uses to compute each device's
      // own relative reference level.
      // 27: cough_test_records — user-initiated 30s cough test result
      // (coughCount/severityScore/severityLevel).
      // 28: task_assignments.isCheckIn — marks a short "still holding on?"
      // check-in slotted into a long barrier, apart from a full task.
      // 29: task_assignments.taskKind — what shape completing a task takes
      // (no_smoke_window/check_in/sleep_routine), see TaskKind.
      // 30: mentor_messages.{followUpQuestion,followUpQuickReplies,
      // followUpReply} — the "Zorlanıyorum" follow-up question/options/
      // answer, stored on the same row rather than a new message so it
      // reads as a continuation of the original reply.
      // 31: subscription_state — trial-start timestamp + subscription
      // status, see SubscriptionState. Upgrading users who already
      // completed the initial survey get trialStartedAt backfilled to
      // "now" rather than penalized for not having had a trial before.
      // 32: failure_triggers — the single-tap "what happened?" answer
      // logged right after a barrier failure, see saveFailureTrigger.
      // 33: smoking_events.trigger — the reason selected after a cigarette
      // log, used by the adaptive trigger profile.
      version: 34,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            completedAt TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            name TEXT NOT NULL,
            packsPerDay TEXT,
            dailyCigarettes INTEGER NOT NULL,
            exhaleTestSeconds INTEGER NOT NULL,
            inhaleTestSeconds INTEGER NOT NULL,
            riskScore INTEGER NOT NULL,
            riskLevel TEXT NOT NULL,
            taskTitle TEXT,
            taskResult TEXT,
            consecutiveSmokingHabit TEXT,
            consecutiveSmokingCount TEXT,
            quitDate TEXT
          )
        ''');
        await _ensureSettingsTable(db);
        await _ensureSurveyDetailsTable(db);
        await _ensureProfileSnapshotTable(db);
        await _ensureLanguageHistoryTable(db);
        await _ensureSensorUsageTable(db);
        await _ensureBreathTestResultsTable(db);
        await _ensureBreathProgressRecordsTable(db);
        await _ensureBreathNoiseBaselinesTable(db);
        await _ensureBehaviorSnapshotTable(db);
        await _ensureTaskFollowUpTable(db);
        await _ensureProtocolViolationTable(db);
        await _ensureAdaptiveTaskStateTable(db);
        await _ensureAdaptiveTaskEventTable(db);
        await _ensureAdaptiveHourlyProfileTable(db);
        await _ensureSmokingEventsTable(db);
        await _ensureTaskAssignmentsTable(db);
        await _ensureMentorMessagesTable(db);
        await _ensureSleepProbeTable(db);
        await _ensureSnoringProbeTable(db);
        await _ensureLocationIntelligenceTables(db);
        await _ensureStepCounterTable(db);
        await _ensureConsentEventsTable(db);
        await _ensureSubscriptionStateTable(db);
        await _ensureMedicationsTable(db);
        await _ensureMedicationDoseLogTable(db);
        await _ensureCoughTestRecordsTable(db);
        await _ensureFailureTriggersTable(db);
        await _ensureNotificationsHistoryTable(db);
        await _ensureIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureColumn(db, 'packsPerDay', 'TEXT');
        await _ensureColumn(db, 'taskTitle', 'TEXT');
        await _ensureColumn(db, 'taskResult', 'TEXT');
        await _ensureColumn(db, 'consecutiveSmokingHabit', 'TEXT');
        await _ensureColumn(db, 'consecutiveSmokingCount', 'TEXT');
        await _ensureColumn(db, 'quitDate', 'TEXT');
        await _ensureSettingsTable(db);
        await _ensureSurveyDetailsTable(db);
        await _ensureProfileSnapshotTable(db);
        await _ensureLanguageHistoryTable(db);
        await _ensureSensorUsageTable(db);
        await _ensureBreathTestResultsTable(db);
        await _ensureBreathProgressRecordsTable(db);
        await _ensureBreathNoiseBaselinesTable(db);
        await _ensureBehaviorSnapshotTable(db);
        await _ensureTaskFollowUpTable(db);
        await _ensureProtocolViolationTable(db);
        await _ensureAdaptiveTaskStateTable(db);
        await _ensureAdaptiveTaskEventTable(db);
        await _ensureAdaptiveHourlyProfileTable(db);
        await _ensureSmokingEventsTable(db);
        await _ensureTaskAssignmentsTable(db);
        await _ensureMentorMessagesTable(db);
        await _ensureSleepProbeTable(db);
        await _ensureSnoringProbeTable(db);
        await _ensureLocationIntelligenceTables(db);
        await _ensureStepCounterTable(db);
        await _ensureConsentEventsTable(db);
        await _ensureSubscriptionStateTable(db);
        await _ensureMedicationsTable(db);
        await _ensureMedicationDoseLogTable(db);
        await _ensureCoughTestRecordsTable(db);
        await _ensureFailureTriggersTable(db);
        await _ensureNotificationsHistoryTable(db);
        if (oldVersion < 31) {
          // Can't go through loadSurveyHistory()/startTrialIfNeeded() here —
          // both resolve the `database` getter, which would recursively
          // call _initDatabase() while openDatabase() is still mid-upgrade.
          // Query/write against the upgrade callback's own `db` instead.
          //
          // Wrapped in try/catch: $_tableName exists on every real device
          // (it's the very first table, created since version 1), but some
          // migration tests open a hand-built legacy DB containing only the
          // one table they're targeting. Missing it there just means "skip
          // the trial backfill", not a real failure.
          try {
            final surveyRows = await db.query(
              _tableName,
              where: 'type = ?',
              whereArgs: ['initial'],
              limit: 1,
            );
            if (surveyRows.isNotEmpty) {
              final existingState = await db.query(
                _subscriptionStateTable,
                where: 'id = ?',
                whereArgs: ['current'],
                limit: 1,
              );
              if (existingState.isEmpty ||
                  existingState.first['trialStartedAt'] == null) {
                final now = DateTime.now();
                await db.insert(
                  _subscriptionStateTable,
                  SubscriptionState(
                    trialStartedAt: now,
                    status: SubscriptionStatus.trial,
                    updatedAt: now,
                  ).toJson(),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          } catch (_) {
            // See comment above — expected for isolated-table migration
            // tests, harmless to skip.
          }
        }
        if (oldVersion < 9) {
          await _ensureIndexes(db);
        }
        if (oldVersion < 10) {
          await _ensureIndexes(db);
        }
        if (oldVersion < 11) {
          await _ensureIndexes(db);
        }
      },
    );
  }

  /// Append-only KVKK/GDPR consent trail — separate from the plain '1'/'0'
  /// enable flags each opt-in service already persists (Sleep/Location/
  /// Wearable Intelligence). KVKK's "parçalı açık rıza" guidance expects a
  /// record of *who* (this device's single local user) consented to *what*
  /// (featureKey), *when* (createdAt), and to *which version* of the
  /// disclosure text (consentTextVersion) — and expects withdrawal to be
  /// recorded too, not just silently overwrite the grant. A single mutable
  /// row per feature can't represent that history, so this is a real
  /// table (one INSERT per decision) rather than another settings key.
  Future<void> _ensureConsentEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_consentEventsTable (
        id TEXT PRIMARY KEY,
        featureKey TEXT NOT NULL,
        granted INTEGER NOT NULL,
        consentTextVersion TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> recordConsentDecision({
    required String featureKey,
    required bool granted,
    required String consentTextVersion,
  }) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert(_consentEventsTable, {
      'id': 'consent_${featureKey}_${now.microsecondsSinceEpoch}',
      'featureKey': featureKey,
      'granted': granted ? 1 : 0,
      'consentTextVersion': consentTextVersion,
      'createdAt': now.toIso8601String(),
    });
  }

  /// Most recent decision for a feature, or null if it was never asked
  /// about. Used to show "ne zaman izin verdin" in a future privacy
  /// screen, and as the audit trail if a Data Safety/KVKK request ever
  /// needs to demonstrate consent provenance.
  Future<Map<String, dynamic>?> loadLatestConsentDecision(
    String featureKey,
  ) async {
    final db = await database;
    final rows = await db.query(
      _consentEventsTable,
      where: 'featureKey = ?',
      whereArgs: [featureKey],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return {
      'granted': row['granted'] == 1,
      'consentTextVersion': row['consentTextVersion'],
      'createdAt': DateTime.parse(row['createdAt'] as String),
    };
  }

  /// Single-row (id = 'current') snapshot of trial/subscription state — see
  /// [SubscriptionState]. Deliberately a mutable single row, not an
  /// append-only trail like [_consentEventsTable]: this represents "what is
  /// true right now" (needed on every app-open gate check), not a decision
  /// history. The server side (verifySubscription Cloud Function) never
  /// stores this — it only answers "is this token active" on request, so
  /// this row is the only persistent record of the user's access state.
  Future<void> _ensureSubscriptionStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_subscriptionStateTable (
        id TEXT PRIMARY KEY,
        trialStartedAt TEXT,
        status TEXT NOT NULL,
        productId TEXT,
        purchaseToken TEXT,
        purchaseOrderId TEXT,
        expiryTimeMillis TEXT,
        lastVerifiedAt TEXT,
        lastVerificationAttemptAt TEXT,
        autoRenewing INTEGER NOT NULL DEFAULT 0,
        updatedAt TEXT NOT NULL,
        maxObservedAt TEXT
      )
    ''');
    await _ensureTableColumn(
      db,
      _subscriptionStateTable,
      'maxObservedAt',
      'TEXT',
    );
  }

  /// Starts the 14-day trial clock the first time this is called — a no-op
  /// on every later call, so callers can invoke it unconditionally right
  /// after the initial survey completes ([hasCompletedInitialSurvey]'s
  /// trigger point) without needing their own "already started?" check.
  Future<void> startTrialIfNeeded() async {
    final existing = await loadSubscriptionState();
    if (existing?.trialStartedAt != null) {
      return;
    }
    final now = DateTime.now();
    await saveSubscriptionState(
      (existing ??
              SubscriptionState(
                status: SubscriptionStatus.trial,
                updatedAt: now,
              ))
          .copyWith(
            trialStartedAt: now,
            status: SubscriptionStatus.trial,
            updatedAt: now,
          ),
    );
  }

  Future<DateTime?> loadTrialStartedAt() async {
    final state = await loadSubscriptionState();
    return state?.trialStartedAt;
  }

  Future<void> saveSubscriptionState(SubscriptionState state) async {
    final db = await database;
    await db.insert(
      _subscriptionStateTable,
      state.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SubscriptionState?> loadSubscriptionState() async {
    final db = await database;
    final rows = await db.query(
      _subscriptionStateTable,
      where: 'id = ?',
      whereArgs: ['current'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SubscriptionState.fromJson(rows.first);
  }

  static const _medicationsTable = 'medications';

  Future<void> _ensureMedicationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_medicationsTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        timesJson TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Medication _medicationFromRow(Map<String, Object?> row) {
    final timesRaw = jsonDecode(row['timesJson'] as String) as List<dynamic>;
    return Medication(
      id: row['id'] as String,
      name: row['name'] as String,
      times: timesRaw.map((t) => t.toString()).toList(),
      createdAt: DateTime.parse(row['createdAt'] as String),
    );
  }

  Future<List<Medication>> loadMedications() async {
    final db = await database;
    final rows = await db.query(_medicationsTable, orderBy: 'createdAt ASC');
    return rows.map(_medicationFromRow).toList();
  }

  /// Upserts by id — callers pass an existing id to edit a medication's
  /// name/times in place, or a freshly generated one to add a new one.
  Future<void> saveMedication(Medication medication) async {
    final db = await database;
    await db.insert(_medicationsTable, {
      'id': medication.id,
      'name': medication.name,
      'timesJson': jsonEncode(medication.times),
      'createdAt': medication.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMedication(String id) async {
    final db = await database;
    await db.delete(_medicationsTable, where: 'id = ?', whereArgs: [id]);
  }

  static const _medicationDoseLogTable = 'medication_dose_log';

  /// Append-only: each row is one answer to one reminder (taken or
  /// postponed), not a mutable per-medication flag — a day with two doses
  /// of the same medication needs both answers kept separately.
  Future<void> _ensureMedicationDoseLogTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_medicationDoseLogTable (
        id TEXT PRIMARY KEY,
        medicationId TEXT NOT NULL,
        outcome TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  /// Records the answer to a medication reminder notification ('taken' or
  /// 'postponed'). Fire-and-forget from the background notification-action
  /// isolate, same as the task-assignment log.
  Future<void> logMedicationDoseOutcome({
    required String medicationId,
    required String outcome,
    DateTime? at,
  }) async {
    final db = await database;
    final when = at ?? DateTime.now();
    await db.insert(_medicationDoseLogTable, {
      'id': 'dose_${medicationId}_${when.microsecondsSinceEpoch}',
      'medicationId': medicationId,
      'outcome': outcome,
      'createdAt': when.toIso8601String(),
    });
  }

  static const _wearableRiskAdjustmentKey = 'wearable_risk_adjustment';
  static const _wearableRiskAdjustmentAtKey =
      'wearable_risk_adjustment_updated_at';
  static const _wearableRiskRefreshInterval = Duration(hours: 1);
  static const _elevatedHeartRateAdjustment = 4;

  /// Refreshes the cached wearable-derived risk adjustment (Phase 11).
  /// Deliberately **not** called from [loadBehaviorDashboard] itself —
  /// that function runs on every app open with no staleness check (a
  /// known hot path, see Phase 9's notes on why a live Health Connect
  /// fetch was never wired in directly). Reading a native platform
  /// channel every single time the home screen loads would add real,
  /// unpredictable latency to that path for a signal only a minority of
  /// users will have enabled at all. Instead: callers (home_page.dart)
  /// invoke this out-of-band and throttled (at most once/hour, same
  /// cadence as LocationIntelligenceService's foreground sampling); it
  /// persists a small cached int that [loadBehaviorDashboard] just reads
  /// via a plain [loadSetting] call — cheap, synchronous-feeling, no
  /// native I/O in the hot path itself.
  Future<void> refreshWearableRiskSignal({bool force = false}) async {
    final enabled = (await loadSetting('wearable_intelligence_enabled')) == '1';
    if (!enabled) {
      return;
    }
    if (!force) {
      final lastRaw = await loadSetting(_wearableRiskAdjustmentAtKey);
      final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
      if (last != null &&
          DateTime.now().difference(last) < _wearableRiskRefreshInterval) {
        return;
      }
    }

    var adjustment = 0;
    try {
      final snapshot = await _healthConnectService.fetchRecentSnapshot();
      final latest = snapshot.latestHeartRateBpm;
      final baseline = snapshot.baselineHeartRateBpm;
      if (latest != null &&
          baseline != null &&
          _wearableSignalEngine.isElevatedHeartRate(
            latestBpm: latest,
            baselineBpm: baseline,
          )) {
        adjustment = _elevatedHeartRateAdjustment;
      }
    } catch (_) {
      // No usable wearable data right now — cache a neutral adjustment
      // rather than leaving a stale (possibly elevated) one in place.
      adjustment = 0;
    }

    await saveSetting(_wearableRiskAdjustmentKey, adjustment.toString());
    await saveSetting(
      _wearableRiskAdjustmentAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<int> _loadCachedWearableRiskAdjustment() async {
    final raw = await loadSetting(_wearableRiskAdjustmentKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// Phase 11 "uzun süre oturma" detector — reuses the step samples
  /// already collected for the report/trend features, no new sensor or
  /// permission. See [StepTrendEngine.isSedentaryWindow] for why the gap
  /// between samples matters as much as the step count itself.
  Future<bool> isRecentlySedentary({
    Duration lookback = const Duration(hours: 3),
  }) async {
    final samples = await loadStepCounterSamples(
      since: DateTime.now().subtract(lookback),
    );
    return _stepTrendEngine.isSedentaryWindow(samples);
  }

  Future<void> _ensureSmokingEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_smokingEventsTable (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        source TEXT NOT NULL,
        approximate INTEGER NOT NULL,
        placeId TEXT,
        trigger TEXT
      )
    ''');
    // Added after the table shipped, so existing installs need it separately.
    // Holds a SignificantPlace id, never coordinates: the app keeps a handful
    // of finalised centroids and no trail, and writing a position onto every
    // cigarette would assemble precisely the movement history that design
    // avoids.
    await _ensureTableColumn(db, _smokingEventsTable, 'placeId', 'TEXT');
    await _ensureTableColumn(db, _smokingEventsTable, 'trigger', 'TEXT');
  }

  /// One row per issued task, carrying the whole lifecycle.
  ///
  /// Separate from `adaptive_task_events`, which stays what it has always
  /// been: an append-only record of finished outcomes for the learning
  /// engine. This table is the live state a task passes through — accepted,
  /// postponed, suspended for a breathing exercise — none of which that log
  /// was ever meant to hold.
  Future<void> _ensureTaskAssignmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_taskAssignmentsTable (
        id TEXT PRIMARY KEY,
        planDate TEXT NOT NULL,
        canonicalTitle TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        scheduledAt TEXT NOT NULL,
        state TEXT NOT NULL,
        deliveredAt TEXT,
        respondedAt TEXT,
        barrierStartedAt TEXT,
        barrierEndsAt TEXT,
        attemptCount INTEGER NOT NULL DEFAULT 1,
        postponeCount INTEGER NOT NULL DEFAULT 0,
        totalPostponedMinutes INTEGER NOT NULL DEFAULT 0,
        gateDeferCount INTEGER NOT NULL DEFAULT 0,
        gateReason TEXT,
        sosCount INTEGER NOT NULL DEFAULT 0,
        sosTotalMinutes INTEGER NOT NULL DEFAULT 0,
        watchdogId TEXT,
        notificationId INTEGER,
        isCheckIn INTEGER NOT NULL DEFAULT 0,
        taskKind TEXT NOT NULL DEFAULT '${TaskKind.noSmokeWindow}',
        sosStartedAt TEXT
      )
    ''');
    // 28: isCheckIn — marks a shorter "are you still holding on?" prompt
    // slotted into a long barrier, distinct from a full ADAPTIVE_NO_SMOKE
    // task. Added via ALTER rather than only in the CREATE above so
    // installs already on this table (created before this column existed)
    // pick it up too.
    await _ensureTableColumn(
      db,
      _taskAssignmentsTable,
      'isCheckIn',
      'INTEGER NOT NULL DEFAULT 0',
    );
    // 29: taskKind — what shape completing the task takes (see TaskKind).
    // Same ALTER-for-existing-installs reasoning as isCheckIn above.
    await _ensureTableColumn(
      db,
      _taskAssignmentsTable,
      'taskKind',
      "TEXT NOT NULL DEFAULT '${TaskKind.noSmokeWindow}'",
    );
    // sosStartedAt — when the task most recently entered sosActive, so
    // closeStaleAbandonedSosSessions can find one the user never came back
    // to resume. Same ALTER-for-existing-installs reasoning as above.
    await _ensureTableColumn(db, _taskAssignmentsTable, 'sosStartedAt', 'TEXT');
  }

  Future<void> _ensureMentorMessagesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_mentorMessagesTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        type TEXT NOT NULL,
        text TEXT NOT NULL,
        tone TEXT NOT NULL,
        quickReplies TEXT,
        read INTEGER NOT NULL DEFAULT 0,
        userReply TEXT
      )
    ''');
    // 30: the "Zorlanıyorum" follow-up question/options/answer, added via
    // ALTER (not the CREATE above) so installs already on this table pick
    // it up too.
    await _ensureTableColumn(
      db,
      _mentorMessagesTable,
      'followUpQuestion',
      'TEXT',
    );
    await _ensureTableColumn(
      db,
      _mentorMessagesTable,
      'followUpQuickReplies',
      'TEXT',
    );
    await _ensureTableColumn(db, _mentorMessagesTable, 'followUpReply', 'TEXT');
  }

  Future<void> _ensureSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureSurveyDetailsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_surveyDetailsTable (
        recordId TEXT PRIMARY KEY,
        triggerJson TEXT,
        healthJson TEXT,
        firstCigaretteRange TEXT,
        smokeFreeRange TEXT,
        profession TEXT,
        sleepTime TEXT,
        wakeTime TEXT,
        stressLevel TEXT,
        quitReason TEXT,
        workStart TEXT,
        workEnd TEXT,
        workplaceSmokingRule TEXT,
        workingDaysJson TEXT,
        breakWindowsJson TEXT,
        weekendSmokingPattern TEXT,
        weeklyJson TEXT,
        age INTEGER,
        smokingYears INTEGER,
        cigarettesPerPack INTEGER,
        createdAt TEXT NOT NULL
      )
    ''');
    await _ensureTableColumn(db, _surveyDetailsTable, 'weeklyJson', 'TEXT');
    await _ensureTableColumn(
      db,
      _surveyDetailsTable,
      'workingDaysJson',
      'TEXT',
    );
    await _ensureTableColumn(
      db,
      _surveyDetailsTable,
      'breakWindowsJson',
      'TEXT',
    );
    await _ensureTableColumn(
      db,
      _surveyDetailsTable,
      'weekendSmokingPattern',
      'TEXT',
    );
    await _ensureTableColumn(db, _surveyDetailsTable, 'age', 'INTEGER');
    await _ensureTableColumn(
      db,
      _surveyDetailsTable,
      'smokingYears',
      'INTEGER',
    );
    await _ensureTableColumn(
      db,
      _surveyDetailsTable,
      'cigarettesPerPack',
      'INTEGER',
    );
  }

  Future<void> _ensureProfileSnapshotTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_profileSnapshotTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        riskScore INTEGER NOT NULL,
        packsPerDay TEXT NOT NULL,
        firstCigaretteRange TEXT NOT NULL,
        smokeFreeRange TEXT NOT NULL,
        consecutiveSmokingHabit TEXT NOT NULL,
        consecutiveSmokingCount TEXT,
        triggerJson TEXT NOT NULL,
        healthJson TEXT NOT NULL,
        profession TEXT NOT NULL,
        sleepTime TEXT NOT NULL,
        wakeTime TEXT NOT NULL,
        latestExhaleSeconds INTEGER NOT NULL,
        latestInhaleSeconds INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _ensureLanguageHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_languageHistoryTable (
        id TEXT PRIMARY KEY,
        languageCode TEXT NOT NULL,
        selectedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureSensorUsageTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_sensorUsageTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        activityState TEXT NOT NULL,
        accelerometerMagnitude REAL NOT NULL,
        gyroscopeMagnitude REAL NOT NULL,
        ambientMeanDecibel REAL NOT NULL DEFAULT 0,
        ambientPeakDecibel REAL NOT NULL DEFAULT 0,
        mealSoundLikelihood REAL NOT NULL DEFAULT 0,
        screenUnlockCount INTEGER NOT NULL,
        appUsageMinutes INTEGER NOT NULL,
        idleMinutes INTEGER NOT NULL,
        charging INTEGER NOT NULL
      )
    ''');
    await _ensureTableColumn(
      db,
      _sensorUsageTable,
      'ambientMeanDecibel',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _sensorUsageTable,
      'ambientPeakDecibel',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _sensorUsageTable,
      'mealSoundLikelihood',
      'REAL NOT NULL DEFAULT 0',
    );
  }

  Future<void> _ensureSleepProbeTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_sleepProbeTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        screenOff INTEGER NOT NULL,
        charging INTEGER NOT NULL
      )
    ''');
  }

  /// A separate table (not a column bolted onto sleep_probe_events) since
  /// this is a genuinely different signal with different consent
  /// implications -- screen/charging state is free OS metadata, this is a
  /// short opt-in audio sample analyzed on-device for a rhythmic
  /// snore-like pattern (see SleepProbeReceiver.kt); nothing is ever
  /// written to disk except the resulting boolean.
  Future<void> _ensureSnoringProbeTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_snoringProbeTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        snoreLikely INTEGER NOT NULL
      )
    ''');
    await _ensureTableColumn(
      db,
      _snoringProbeTable,
      'severityScore',
      'INTEGER',
    );
    await _ensureTableColumn(db, _snoringProbeTable, 'severityLevel', 'TEXT');
    // Nullable, no DEFAULT -- existing rows predate the Android 11+ silent
    // capture-failure fix (SnoringCaptureService.kt) and are read back as
    // null, which SnoringProbeEvent.captureSucceeded's doc comment explains
    // callers should treat as true (the old assumption).
    await _ensureTableColumn(
      db,
      _snoringProbeTable,
      'captureSucceeded',
      'INTEGER',
    );
    await _ensureTableColumn(db, _snoringProbeTable, 'source', 'TEXT');
    // Backfill from the id prefix ("manualsnoreprobe_" vs. "snoreprobe_"),
    // which was the only thing distinguishing the two sources before this
    // column existed (see saveManualSnoringProbe's doc comment history) --
    // WHERE source IS NULL makes this safe to run on every _ensureSnoringProbeTable
    // call (onCreate and onUpgrade both call it) without re-touching rows a
    // prior run already backfilled.
    await db.execute('''
      UPDATE $_snoringProbeTable
      SET source = CASE
        WHEN id LIKE 'manualsnoreprobe_%' THEN '${SnoringProbeEvent.sourceManual}'
        ELSE '${SnoringProbeEvent.sourceOvernight}'
      END
      WHERE source IS NULL
    ''');
  }

  /// [source] restricts to [SnoringProbeEvent.sourceOvernight] or
  /// [SnoringProbeEvent.sourceManual] rows only; null (the default) returns
  /// both. Callers that feed the nightly summary or risk score MUST pass
  /// [SnoringProbeEvent.sourceOvernight] explicitly -- see
  /// [countRecentSnoreLikelyEvents], which does exactly that.
  Future<List<SnoringProbeEvent>> loadSnoringProbeEventsBetween({
    required DateTime start,
    required DateTime end,
    String? source,
  }) async {
    final db = await database;
    final whereClauses = ['createdAt >= ?', 'createdAt <= ?'];
    final whereArgs = <Object?>[
      start.toUtc().toIso8601String(),
      end.toUtc().toIso8601String(),
    ];
    if (source != null) {
      whereClauses.add('source = ?');
      whereArgs.add(source);
    }
    final rows = await db.query(
      _snoringProbeTable,
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'createdAt ASC',
    );
    return rows
        .map(
          (row) => SnoringProbeEvent(
            id: row['id'] as String,
            createdAt: DateTime.parse(row['createdAt'] as String),
            snoreLikely: (row['snoreLikely'] as int) == 1,
            severityScore: row['severityScore'] as int?,
            severityLevel: row['severityLevel'] as String?,
            captureSucceeded: (row['captureSucceeded'] as int?) == null
                ? null
                : (row['captureSucceeded'] as int) == 1,
            source: row['source'] as String?,
          ),
        )
        .toList();
  }

  /// Count of snore-likely OVERNIGHT probes since [since] (defaults to the
  /// last 12 hours, comfortably covering one night) -- shown as a simple
  /// summary in Settings rather than a full report, matching the feature's
  /// scope, and feeds BehaviorEngine.calculateSnoringRiskAdjustment.
  ///
  /// Always filters to [SnoringProbeEvent.sourceOvernight] -- a daytime,
  /// user-initiated SnoringTestPage run must never inflate "last night's"
  /// count or the risk score just because the user was curious and ran it
  /// two or three times (see FAZ 3 finding). Also excludes probes where the
  /// capture itself failed (captureSucceeded == false -- see
  /// SnoringCaptureService.kt / SnoringProbeEvent.captureSucceeded's doc
  /// comment) explicitly, not just incidentally via snoreLikely already
  /// being false on those rows: a night the microphone never actually
  /// opened must count toward neither "snoring detected" nor "confirmed
  /// clean", so it can't silently lower the risk adjustment the way a real
  /// clean night correctly does.
  Future<int> countRecentSnoreLikelyEvents({DateTime? since}) async {
    final cutoff = since ?? DateTime.now().subtract(const Duration(hours: 12));
    final events = await loadSnoringProbeEventsBetween(
      start: cutoff,
      end: DateTime.now(),
      source: SnoringProbeEvent.sourceOvernight,
    );
    return events
        .where((e) => e.captureSucceeded != false && e.snoreLikely)
        .length;
  }

  /// Records a daytime, user-initiated Snoring Test result into the same
  /// table the overnight native probes write to -- explicitly tagged
  /// [SnoringProbeEvent.sourceManual] so [countRecentSnoreLikelyEvents]
  /// (and anything else scoped to the nightly summary) can never mistake it
  /// for one of SleepProbeReceiver.kt's passive probes.
  Future<void> saveManualSnoringProbe(SnoringProbeEvent event) async {
    final db = await database;
    await db.insert(_snoringProbeTable, {
      'id': event.id,
      'createdAt': event.createdAt.toUtc().toIso8601String(),
      'snoreLikely': event.snoreLikely ? 1 : 0,
      'severityScore': event.severityScore,
      'severityLevel': event.severityLevel,
      // A manual, user-initiated test always completes synchronously in the
      // foreground (the user is looking at the result on screen) — capture
      // failure isn't a scenario here the way it is for the overnight native
      // probe.
      'captureSucceeded': 1,
      'source': SnoringProbeEvent.sourceManual,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _ensureLocationIntelligenceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_significantPlacesTable (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        visitCount INTEGER NOT NULL,
        firstSeenAt TEXT NOT NULL,
        lastSeenAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_locationVisitEventsTable (
        id TEXT PRIMARY KEY,
        placeId TEXT NOT NULL,
        transitionType TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureStepCounterTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_stepCounterSamplesTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        cumulativeSteps INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _ensureBreathTestResultsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_breathTestResultsTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        holdDuration REAL NOT NULL,
        blowDuration REAL NOT NULL,
        blowIntensity REAL NOT NULL,
        blowStability REAL NOT NULL,
        holdRisk INTEGER NOT NULL,
        blowRisk INTEGER NOT NULL,
        intensityRisk INTEGER NOT NULL,
        stabilityRisk INTEGER NOT NULL,
        breathScore REAL NOT NULL,
        riskContribution REAL NOT NULL
      )
    ''');
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'holdDuration',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'blowDuration',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'blowIntensity',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'blowStability',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'holdRisk',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'blowRisk',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'intensityRisk',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'stabilityRisk',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'breathScore',
      'REAL NOT NULL DEFAULT 0',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'riskContribution',
      'REAL NOT NULL DEFAULT 0',
    );
    // Spirometry-style estimates (see BreathAcousticEngine.estimateSpirometry)
    // — nullable, unlike the columns above: rows saved before this existed,
    // and attempts with no full acoustic reading, legitimately have none.
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'fev1EnergyIntegral',
      'REAL',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'fvcEnergyIntegral',
      'REAL',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'fev1FvcRatioPercent',
      'REAL',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'peakFlowIndex',
      'REAL',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'peakFlowAtMs',
      'INTEGER',
    );
    // Acoustic wheeze finding (see WheezeDetectionEngine.analyze) — nullable,
    // same reasoning as the spirometry columns above.
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'wheezeDetected',
      'INTEGER',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'wheezeSeverityLevel',
      'TEXT',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'wheezeSeverityScore',
      'INTEGER',
    );
    await _ensureTableColumn(
      db,
      _breathTestResultsTable,
      'wheezeBandEnergyRatio',
      'REAL',
    );
  }

  /// User-initiated cough test result — a short (default 30s) mic listen
  /// that counts distinct cough events, separate from the breath test's
  /// hold/exhale protocol. averageIntervalSeconds/earlyBurstRatio/
  /// peakIntensityScore are nullable: rows with zero detected coughs have
  /// nothing to compute an interval or burst pattern from.
  Future<void> _ensureCoughTestRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_coughTestRecordsTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        coughCount INTEGER NOT NULL,
        testDurationSeconds INTEGER NOT NULL,
        severityScore INTEGER NOT NULL,
        severityLevel TEXT NOT NULL,
        averageIntervalSeconds REAL,
        earlyBurstRatio REAL,
        peakIntensityScore INTEGER
      )
    ''');
    // Acoustic wheeze finding (see WheezeDetectionEngine.analyze) — nullable,
    // same reasoning as breath_test_results' wheeze columns.
    await _ensureTableColumn(
      db,
      _coughTestRecordsTable,
      'wheezeDetected',
      'INTEGER',
    );
    await _ensureTableColumn(
      db,
      _coughTestRecordsTable,
      'wheezeSeverityLevel',
      'TEXT',
    );
    await _ensureTableColumn(
      db,
      _coughTestRecordsTable,
      'wheezeSeverityScore',
      'INTEGER',
    );
    await _ensureTableColumn(
      db,
      _coughTestRecordsTable,
      'wheezeBandEnergyRatio',
      'REAL',
    );
    // See CoughTestRecord.insufficientSignal — marks a kept-anyway attempt
    // whose recording never cleared the noise floor, so callers can tell it
    // apart from a real "no coughs detected" result.
    await _ensureTableColumn(
      db,
      _coughTestRecordsTable,
      'insufficientSignal',
      'INTEGER',
    );
  }

  /// User-facing breath test record (score/duration/stability/intensity +
  /// noisy-environment flag) that BreathTrendEngine.summarize consumes —
  /// deliberately separate from [_breathTestResultsTable], which is the
  /// risk engine's own internal representation (holdRisk/blowRisk/etc.).
  Future<void> _ensureBreathProgressRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_breathProgressRecordsTable (
        id TEXT PRIMARY KEY,
        completedAt TEXT NOT NULL,
        breathScore REAL NOT NULL,
        blowDurationSeconds REAL NOT NULL,
        blowStability REAL NOT NULL,
        blowIntensity REAL NOT NULL,
        isNoisyEnvironment INTEGER NOT NULL DEFAULT 0,
        schemaVersion INTEGER NOT NULL DEFAULT 1
      )
    ''');
    // Rows saved before this column existed recorded blowDurationSeconds as
    // hold+blow combined (see BreathAcousticEngine.analyze's measurementStartMs
    // fix) — DEFAULT 1 backfills every pre-existing row as legacy/inflated.
    // New rows are always written with schemaVersion 2 (see
    // saveBreathProgressRecord) so BreathTrendEngine can exclude the legacy
    // ones from trend/chart statistics without losing the history.
    await _ensureTableColumn(
      db,
      _breathProgressRecordsTable,
      'schemaVersion',
      'INTEGER NOT NULL DEFAULT 1',
    );
  }

  /// Ambient noise readings BreathNoiseEngine.computeReferenceLevel uses to
  /// derive each device's own relative noise reference (median of the most
  /// recent readings) — see BreathNoiseEngine's doc comment for why a fixed
  /// dB threshold doesn't work across devices.
  Future<void> _ensureBreathNoiseBaselinesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_breathNoiseBaselinesTable (
        id TEXT PRIMARY KEY,
        measuredAt TEXT NOT NULL,
        level REAL NOT NULL
      )
    ''');
  }

  Future<void> _ensureBehaviorSnapshotTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_behaviorSnapshotTable (
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        snapshotJson TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureTaskFollowUpTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_taskFollowUpTable (
        id TEXT PRIMARY KEY,
        taskTitle TEXT NOT NULL,
        scheduledAt TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureProtocolViolationTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_protocolViolationTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'app_flow',
        taskTitle TEXT,
        details TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        resolved INTEGER NOT NULL
      )
    ''');
    await _ensureTableColumn(
      db,
      _protocolViolationTable,
      'source',
      "TEXT NOT NULL DEFAULT 'app_flow'",
    );
  }

  /// A single-tap "what happened?" answer logged right after a barrier
  /// failure (see [saveFailureTrigger]) — feeds the same risky-hour/trigger
  /// profile the weekly survey's trigger questions do, so a failure the
  /// user explains is worth as much to that profile as one they reported on
  /// a survey a week later.

  Future<void> _ensureNotificationsHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_notificationsHistoryTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT '',
        receivedAt TEXT NOT NULL,
        expiresAt TEXT NOT NULL,
        availableAt TEXT,
        dedupeKey TEXT,
        acknowledgedAt TEXT
      )
    ''');
    await _ensureTableColumn(
      db,
      _notificationsHistoryTable,
      'availableAt',
      'TEXT',
    );
    await _ensureTableColumn(
      db,
      _notificationsHistoryTable,
      'dedupeKey',
      'TEXT',
    );
    await _ensureTableColumn(
      db,
      _notificationsHistoryTable,
      'acknowledgedAt',
      'TEXT',
    );
  }

  Future<void> _ensureFailureTriggersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_failureTriggersTable (
        id TEXT PRIMARY KEY,
        reason TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  /// Canonical trigger names a failure can be attributed to — matches
  /// [BehaviorEngine]'s survey-trigger vocabulary ('Stres', 'Kahve', 'Sosyal
  /// Ortam', 'Alkol') so a logged failure and a survey answer feed the risky-
  /// trigger profile identically. 'unknown' is the fifth option (the user
  /// genuinely doesn't know) and is never counted toward any trigger.
  static const List<String> failureTriggerReasons = [
    'Stres',
    'Kahve',
    'Yemek',
    'Alkol',
    'Telefon',
    'Arac',
    'Is Molasi',
    'Sosyal Ortam',
    'Can Sikintisi',
    'Aliskanlik',
    'no_specific_reason',
    'unknown',
  ];

  Future<void> saveFailureTrigger(String reason) async {
    if (!failureTriggerReasons.contains(reason)) {
      return;
    }
    final db = await database;
    final now = DateTime.now();
    await db.insert(_failureTriggersTable, {
      'id': 'ftrig_${now.microsecondsSinceEpoch}',
      'reason': reason,
      'createdAt': now.toIso8601String(),
    });
  }

  /// Extra weight for the risky-trigger score, from failures the user
  /// explained directly rather than only ever through a weekly survey
  /// answer. Same +5-per-hit shape [BehaviorEngine.calculateTriggerScores]
  /// already uses for a survey trigger selection, so a logged failure counts
  /// the same as reporting it a week later would have.
  Future<Map<String, int>> loadFailureTriggerScoreBoost() async {
    final db = await database;
    final rows = await db.query(_failureTriggersTable, columns: ['reason']);
    final smokingRows = await db.query(
      _smokingEventsTable,
      columns: ['trigger'],
      where: 'trigger IS NOT NULL',
    );
    final boost = <String, int>{};
    for (final row in [...rows, ...smokingRows]) {
      final reason = (row['reason'] ?? row['trigger']) as String?;
      if (reason == null || reason == 'unknown') continue;
      boost[reason] = (boost[reason] ?? 0) + 5;
    }
    return boost;
  }

  Future<void> _ensureAdaptiveTaskStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_adaptiveTaskStateTable (
        id TEXT PRIMARY KEY,
        selfControlScore REAL NOT NULL,
        difficultyLevel REAL NOT NULL,
        dailyTaskCapacity REAL NOT NULL,
        postponeRate REAL NOT NULL,
        movingSuccessRate REAL NOT NULL,
        movingFailureRate REAL NOT NULL,
        avgResponseMinutes REAL NOT NULL,
        successStreak INTEGER NOT NULL,
        failureStreak INTEGER NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureAdaptiveTaskEventTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_adaptiveTaskEventTable (
        id TEXT PRIMARY KEY,
        taskTitle TEXT NOT NULL,
        scheduledAt TEXT NOT NULL,
        respondedAt TEXT NOT NULL,
        outcome TEXT NOT NULL,
        plannedDurationMinutes INTEGER NOT NULL,
        responseDelayMinutes INTEGER NOT NULL,
        hourBucket INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureAdaptiveHourlyProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_adaptiveHourlyProfileTable (
        hour INTEGER PRIMARY KEY,
        strainScore REAL NOT NULL,
        successCount INTEGER NOT NULL,
        failureCount INTEGER NOT NULL,
        deferCount INTEGER NOT NULL,
        avgResponseMinutes REAL NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _ensureIndexes(Database db) async {
    // app_events: sıralama ve tür filtreleri için
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_events_completedAt ON $_tableName (completedAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_events_type ON $_tableName (type)',
    );
    // sensor_usage_events: tarih aralığı sorguları için
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sensor_usage_createdAt ON $_sensorUsageTable (createdAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_breath_results_createdAt ON $_breathTestResultsTable (createdAt)',
    );
    // behavior_snapshots: son snapshot'a erişim için
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_behavior_snapshot_createdAt ON $_behaviorSnapshotTable (createdAt)',
    );
    // task_followups: bekleyen görevler için
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_task_followups_status_scheduledAt ON $_taskFollowUpTable (status, scheduledAt)',
    );
    // protocol_violations: çözülmemiş ihlaller için
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_protocol_violations_resolved_createdAt ON $_protocolViolationTable (resolved, createdAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_adaptive_task_events_createdAt ON $_adaptiveTaskEventTable (createdAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_adaptive_task_events_outcome ON $_adaptiveTaskEventTable (outcome)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_adaptive_task_events_hourBucket ON $_adaptiveTaskEventTable (hourBucket)',
    );
  }

  Future<void> _ensureColumn(
    Database db,
    String columnName,
    String columnType,
  ) async {
    try {
      await db.execute(
        'ALTER TABLE $_tableName ADD COLUMN $columnName $columnType',
      );
    } catch (_) {
      // Column already exists on upgraded databases.
    }
  }

  Future<void> _ensureTableColumn(
    Database db,
    String table,
    String columnName,
    String columnType,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnName $columnType');
    } catch (_) {
      // Column already exists.
    }
  }

  Future<List<SurveyRecord>> loadSurveyHistory() async {
    final db = await database;
    final rows = await db.query(_tableName, orderBy: 'completedAt ASC');
    return rows
        .map(
          (row) => SurveyRecord.fromJson({
            ...row,
            'completedAt': row['completedAt'] as String,
          }),
        )
        .toList();
  }

  /// Whether the user has ever completed the one-time initial survey.
  /// This is the single source of truth for "has onboarding's survey step
  /// been done" — used to decide whether Splash/TrialInfo should route to
  /// SurveyPage or straight to the returning-user flow. It intentionally
  /// does NOT require a breath test too; for the stricter "registration is
  /// fully complete" question (survey + breath test), see
  /// [loadInitialRegistrationCompleted] instead — the two are different
  /// questions and must stay distinct rather than being approximated by
  /// each other.
  Future<bool> hasCompletedInitialSurvey({List<SurveyRecord>? records}) async {
    final effectiveRecords = records ?? await loadSurveyHistory();
    return effectiveRecords.any((record) => record.type == 'initial');
  }

  Future<void> saveSurveyHistory(List<SurveyRecord> records) async {
    final db = await database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(
        _tableName,
        record.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveSurveyRecord(SurveyRecord record) async {
    try {
      final db = await database;
      await db.insert(
        _tableName,
        record.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await updateLastSurveyDate(record.completedAt);
      await markBehaviorDirty();
    } catch (error, stackTrace) {
      debugPrint(
        '[StorageService] saveSurveyRecord failed: id=${record.id}, type=${record.type}, error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> saveSurveyDetail({
    required String recordId,
    required List<String> triggers,
    required List<String> healthConditions,
    String? firstCigaretteRange,
    String? smokeFreeRange,
    String? profession,
    String? sleepTime,
    String? wakeTime,
    String? stressLevel,
    String? quitReason,
    String? workStart,
    String? workEnd,
    String? workplaceSmokingRule,
    List<String>? workingDays,
    List<Map<String, String>>? breakWindows,
    String? weekendSmokingPattern,
    Map<String, dynamic>? weeklyPayload,
    int? age,
    int? smokingYears,
    int? cigarettesPerPack,
  }) async {
    try {
      final db = await database;
      await db.insert(_surveyDetailsTable, {
        'recordId': recordId,
        'triggerJson': jsonEncode(triggers),
        'healthJson': jsonEncode(healthConditions),
        'firstCigaretteRange': firstCigaretteRange,
        'smokeFreeRange': smokeFreeRange,
        'profession': profession,
        'sleepTime': sleepTime,
        'wakeTime': wakeTime,
        'stressLevel': stressLevel,
        'quitReason': quitReason,
        'workStart': workStart,
        'workEnd': workEnd,
        'workplaceSmokingRule': workplaceSmokingRule,
        'workingDaysJson': workingDays == null ? null : jsonEncode(workingDays),
        'breakWindowsJson': breakWindows == null
            ? null
            : jsonEncode(breakWindows),
        'weekendSmokingPattern': weekendSmokingPattern,
        'weeklyJson': weeklyPayload == null ? null : jsonEncode(weeklyPayload),
        'age': age,
        'smokingYears': smokingYears,
        'cigarettesPerPack': cigarettesPerPack,
        'createdAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await markBehaviorDirty();
    } catch (error, stackTrace) {
      debugPrint(
        '[StorageService] saveSurveyDetail failed: recordId=$recordId, error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Best-effort JSON-list decode: returns `null` (rather than throwing) on
  /// missing/empty/malformed input, so a corrupted column can't crash a
  /// dashboard/profile read — callers fall back to an empty collection.
  List<dynamic>? _tryDecodeJsonList(String? raw, {required String field}) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is List<dynamic> ? decoded : null;
    } catch (error, stackTrace) {
      debugPrint(
        '[StorageService] Failed to decode $field as JSON list: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Best-effort JSON-map decode counterpart to [_tryDecodeJsonList].
  Map<String, dynamic>? _tryDecodeJsonMap(
    String? raw, {
    required String field,
  }) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (error, stackTrace) {
      debugPrint(
        '[StorageService] Failed to decode $field as JSON map: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<Map<String, List<String>>> loadTriggerMapByRecordId() async {
    final db = await database;
    final rows = await db.query(_surveyDetailsTable);
    final result = <String, List<String>>{};
    for (final row in rows) {
      final recordId = row['recordId'] as String;
      final raw = row['triggerJson'] as String?;
      final decoded = _tryDecodeJsonList(raw, field: 'triggerJson');
      result[recordId] = decoded == null
          ? const []
          : decoded.map((item) => item.toString()).toList();
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>>
  loadSurveyContextByRecordId() async {
    final db = await database;
    final rows = await db.query(_surveyDetailsTable);
    final result = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final recordId = row['recordId'] as String;
      final healthRaw = row['healthJson'] as String?;
      final weeklyRaw = row['weeklyJson'] as String?;
      final workingDaysRaw = row['workingDaysJson'] as String?;
      final breakWindowsRaw = row['breakWindowsJson'] as String?;
      final decodedHealth = _tryDecodeJsonList(healthRaw, field: 'healthJson');
      final healthConditions = decodedHealth == null
          ? <String>[]
          : decodedHealth.map((item) => item.toString()).toList();
      final weeklyPayload =
          _tryDecodeJsonMap(weeklyRaw, field: 'weeklyJson') ??
          <String, dynamic>{};
      final decodedWorkingDays = _tryDecodeJsonList(
        workingDaysRaw,
        field: 'workingDaysJson',
      );
      final workingDays = decodedWorkingDays == null
          ? <String>[]
          : decodedWorkingDays.map((item) => item.toString()).toList();
      final decodedBreakWindows = _tryDecodeJsonList(
        breakWindowsRaw,
        field: 'breakWindowsJson',
      );
      final breakWindows = decodedBreakWindows == null
          ? <Map<String, String>>[]
          : decodedBreakWindows
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => {
                    'start': item['start']?.toString() ?? '',
                    'end': item['end']?.toString() ?? '',
                  },
                )
                .toList();

      result[recordId] = {
        'profession': row['profession'] as String?,
        'sleepTime': row['sleepTime'] as String?,
        'wakeTime': row['wakeTime'] as String?,
        'workStart': row['workStart'] as String?,
        'workEnd': row['workEnd'] as String?,
        'workplaceSmokingRule': row['workplaceSmokingRule'] as String?,
        'workingDays': workingDays,
        'breakWindows': breakWindows,
        'weekendSmokingPattern': row['weekendSmokingPattern'] as String?,
        'firstCigaretteRange': row['firstCigaretteRange'] as String?,
        'smokeFreeRange': row['smokeFreeRange'] as String?,
        'stressLevel': row['stressLevel'] as String?,
        'quitReason': row['quitReason'] as String?,
        'healthConditions': healthConditions,
        'weeklyPayload': weeklyPayload,
        'age': row['age'] as int?,
        'smokingYears': row['smokingYears'] as int?,
        'cigarettesPerPack': row['cigarettesPerPack'] as int?,
      };
    }

    return result;
  }

  Future<void> saveUserProfileSnapshot(UserProfileSnapshot snapshot) async {
    try {
      final db = await database;
      await db.insert(_profileSnapshotTable, {
        'id': snapshot.id,
        'createdAt': snapshot.createdAt.toIso8601String(),
        'riskScore': snapshot.riskScore,
        'packsPerDay': snapshot.packsPerDay,
        'firstCigaretteRange': snapshot.firstCigaretteRange,
        'smokeFreeRange': snapshot.smokeFreeRange,
        'consecutiveSmokingHabit': snapshot.consecutiveSmokingHabit,
        'consecutiveSmokingCount': snapshot.consecutiveSmokingCount,
        'triggerJson': jsonEncode(snapshot.triggers),
        'healthJson': jsonEncode(snapshot.healthConditions),
        'profession': snapshot.profession,
        'sleepTime': snapshot.sleepTime,
        'wakeTime': snapshot.wakeTime,
        'latestExhaleSeconds': snapshot.latestExhaleSeconds,
        'latestInhaleSeconds': snapshot.latestInhaleSeconds,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (error, stackTrace) {
      debugPrint(
        '[StorageService] saveUserProfileSnapshot failed: id=${snapshot.id}, error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> saveLanguageSelectionHistory(String languageCode) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert(_languageHistoryTable, {
      'id': 'lang_${now.microsecondsSinceEpoch}',
      'languageCode': languageCode,
      'selectedAt': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveSensorUsageEvent(SensorUsageEvent event) async {
    final db = await database;
    await db.insert(_sensorUsageTable, {
      'id': event.id,
      'createdAt': event.createdAt.toIso8601String(),
      'activityState': event.activityState,
      'accelerometerMagnitude': event.accelerometerMagnitude,
      'gyroscopeMagnitude': event.gyroscopeMagnitude,
      'ambientMeanDecibel': event.ambientMeanDecibel,
      'ambientPeakDecibel': event.ambientPeakDecibel,
      'mealSoundLikelihood': event.mealSoundLikelihood,
      'screenUnlockCount': event.screenUnlockCount,
      'appUsageMinutes': event.appUsageMinutes,
      'idleMinutes': event.idleMinutes,
      'charging': event.charging ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await markBehaviorDirty();
  }

  Future<void> saveBreathTestResult(BreathTestResult result) async {
    final db = await database;
    await db.insert(
      _breathTestResultsTable,
      result.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await markBehaviorDirty();
  }

  Future<List<BreathTestResult>> loadBreathTestResults({int limit = 50}) async {
    final db = await database;
    // Fetch the most recent `limit` rows (DESC), then reverse back to
    // chronological (ASC) order so callers relying on `.last` as "the
    // newest result" keep working. Ordering ASC-then-LIMIT would instead
    // return the oldest rows once the table exceeds `limit` entries.
    final rows = await db.query(
      _breathTestResultsTable,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    final results = rows.map((row) => BreathTestResult.fromJson(row)).toList();
    return results.reversed.toList();
  }

  Future<BreathTestResult?> loadLatestBreathTestResult() async {
    final rows = await loadBreathTestResults(limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    return rows.last;
  }

  Future<void> saveCoughTestRecord(CoughTestRecord record) async {
    final db = await database;
    await db.insert(
      _coughTestRecordsTable,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await markBehaviorDirty();
  }

  Future<List<CoughTestRecord>> loadCoughTestRecords({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      _coughTestRecordsTable,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    final results = rows.map((row) => CoughTestRecord.fromJson(row)).toList();
    return results.reversed.toList();
  }

  Future<CoughTestRecord?> loadLatestCoughTestRecord() async {
    final rows = await loadCoughTestRecords(limit: 1);
    if (rows.isEmpty) {
      return null;
    }
    return rows.last;
  }

  /// Whether at least one cough test was completed since [since] — used to
  /// gate the weekly survey's save action rather than a standalone
  /// scheduled reminder (see WeeklySurveyPage).
  ///
  /// Compares in Dart after parsing, not as a raw SQL string comparison —
  /// createdAt rows are written with CoughTestRecord.toJson()'s plain
  /// `createdAt.toIso8601String()` (no `.toUtc()`, so the string is in the
  /// device's local time with no zone suffix), but the previous version
  /// compared that string directly against `since.toUtc().toIso8601String()`.
  /// Two ISO8601 strings in different zones aren't lexicographically
  /// comparable as if they were the same clock, so the effective threshold
  /// silently drifted by the device's UTC offset. loadSleepProbeEventsBetween
  /// already gets this right the same way this now does: parse each row's
  /// timestamp back into a real DateTime, then compare in UTC numerically.
  Future<bool> hasCoughTestSince(DateTime since) async {
    final db = await database;
    final rows = await db.query(
      _coughTestRecordsTable,
      columns: ['createdAt'],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    final latestCreatedAt = DateTime.parse(rows.first['createdAt'] as String);
    return !latestCreatedAt.toUtc().isBefore(since.toUtc());
  }

  Future<void> saveBreathProgressRecord(BreathProgressRecord record) async {
    final db = await database;
    final json = record.toJson();
    json['isNoisyEnvironment'] = record.isNoisyEnvironment ? 1 : 0;
    await db.insert(
      _breathProgressRecordsTable,
      json,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Chronological (ASC) order — BreathTrendEngine.summarize expects
  /// records sorted oldest-first (see StepTrendEngine/breath engines'
  /// convention) and re-sorts defensively anyway, but returning them
  /// already sorted keeps every caller's expectations consistent.
  Future<List<BreathProgressRecord>> loadBreathProgressRecords({
    int limit = 500,
  }) async {
    final db = await database;
    final rows = await db.query(
      _breathProgressRecordsTable,
      orderBy: 'completedAt DESC',
      limit: limit,
    );
    final records = rows
        .map(
          (row) => BreathProgressRecord.fromJson({
            ...row,
            'isNoisyEnvironment': row['isNoisyEnvironment'] == 1,
          }),
        )
        .toList();
    return records.reversed.toList();
  }

  Future<void> saveBreathNoiseBaseline(BreathNoiseBaseline baseline) async {
    final db = await database;
    await db.insert(_breathNoiseBaselinesTable, {
      'id': 'noise_${baseline.measuredAt.microsecondsSinceEpoch}',
      ...baseline.toJson(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Most recent [limit] baseline readings (chronological order) —
  /// BreathNoiseEngine.computeReferenceLevel only needs the most recent
  /// referenceSampleCount of these, but re-selects that window itself so
  /// this can return a slightly larger history without coupling the two.
  Future<List<BreathNoiseBaseline>> loadRecentBreathNoiseBaselines({
    int limit = 20,
  }) async {
    final db = await database;
    final rows = await db.query(
      _breathNoiseBaselinesTable,
      orderBy: 'measuredAt DESC',
      limit: limit,
    );
    final baselines = rows
        .map((row) => BreathNoiseBaseline.fromJson(row))
        .toList();
    return baselines.reversed.toList();
  }

  Future<void> saveSetting(
    String key,
    String value, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    await db.insert(_settingsTable, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> loadSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      _settingsTable,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String;
  }

  static const String _missedTaskTitleKey = 'missed_task_title';
  static const String _adaptiveObservationStartedAtKey =
      'adaptive_observation_started_at';

  /// Returns the moment the app first became eligible to collect adaptive
  /// planning data. Existing installs are initialized on their next HomePage
  /// open, so the rollout never schedules a barrier retroactively.
  Future<DateTime> ensureAdaptiveObservationStartedAt({DateTime? now}) async {
    final stored = await loadSetting(_adaptiveObservationStartedAtKey);
    final parsed = stored == null ? null : DateTime.tryParse(stored);
    if (parsed != null) {
      return parsed;
    }
    final startedAt = now ?? DateTime.now();
    await saveSetting(
      _adaptiveObservationStartedAtKey,
      startedAt.toIso8601String(),
    );
    return startedAt;
  }

  Future<DateTime?> loadAdaptiveObservationStartedAt() async {
    final stored = await loadSetting(_adaptiveObservationStartedAtKey);
    return stored == null ? null : DateTime.tryParse(stored);
  }

  /// Duration-barrier tasks begin only after a full 24-hour observation
  /// period and after the next calendar day's wake-up time. This prevents a
  /// freshly installed app from issuing a generic plan before it has learned
  /// the user's first smoking pattern.
  bool isAdaptivePlanningEligible({
    required DateTime now,
    required DateTime observationStartedAt,
    required String wakeTime,
  }) {
    if (now.isBefore(observationStartedAt.add(const Duration(hours: 24)))) {
      return false;
    }
    final startedDate = DateTime(
      observationStartedAt.year,
      observationStartedAt.month,
      observationStartedAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    if (!today.isAfter(startedDate)) {
      return false;
    }
    final parts = wakeTime.split(':');
    final hour = int.tryParse(parts.first) ?? 7;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final wakeAt = DateTime(now.year, now.month, now.day, hour, minute);
    return !now.isBefore(wakeAt);
  }

  /// Remembers a task the overdue-grace branch in HomePage closed out
  /// without ever showing it, so the home screen can offer it back on next
  /// open instead of it just vanishing. One slot, not a list — the same
  /// simplification `_lastSleepActivityNotificationKey` and similar
  /// single-pending-item settings already make elsewhere in this file.
  Future<void> saveMissedTaskTitle(String taskTitle) async {
    await saveSetting(_missedTaskTitleKey, taskTitle);
  }

  Future<String?> loadMissedTaskTitle() async {
    final value = await loadSetting(_missedTaskTitleKey);
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> clearMissedTaskTitle() async {
    await saveSetting(_missedTaskTitleKey, '');
  }

  /// How many of today's tasks never actually reached the user: `missed`
  /// adaptive-outcome events (overdue-grace closures, watchdog no-response)
  /// plus `expired` task_assignments rows (native delivery-gate queue
  /// limit). Both are the app's own delivery delay, not something the user
  /// did — this is purely a count for the daily-review summary line and the
  /// reliability-prompt trigger, not a learning-engine input.
  /// Total smoke-free time this calendar month, summed from every
  /// successfully-completed barrier's own planned duration — the concrete
  /// number [craving_sos_page.dart]/[home_page.dart] show right after a
  /// barrier is won, so the payoff for getting through one is stated in
  /// hours, not just left implicit in a streak count.
  Future<int> monthlySmokeFreeMinutes({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month);
    final events = await loadRecentAdaptiveTaskEvents();
    var total = 0;
    for (final event in events) {
      if (event.outcome == AdaptiveTaskOutcome.success &&
          !event.respondedAt.isBefore(monthStart)) {
        total += event.plannedDurationMinutes;
      }
    }
    return total;
  }

  Future<int> countTodaysUndeliveredTasks({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final events = await loadRecentAdaptiveTaskEvents();
    final missedToday = events
        .where(
          (e) =>
              e.outcome == AdaptiveTaskOutcome.missed &&
              !e.respondedAt.isBefore(dayStart) &&
              e.respondedAt.isBefore(dayEnd),
        )
        .length;

    final assignments = await loadTaskAssignmentsForDay(today);
    final expiredToday = assignments
        .where((a) => a.state == TaskLifecycleState.expired)
        .length;

    return missedToday + expiredToday;
  }

  Future<void> markBehaviorDirty() async {
    await saveSetting(_behaviorDirtyKey, '1');
  }

  Future<void> clearBehaviorDirty() async {
    await saveSetting(_behaviorDirtyKey, '0');
  }

  Future<bool> isBehaviorDirty() async {
    final value = await loadSetting(_behaviorDirtyKey);
    if (value == null) {
      return true;
    }
    return value == '1';
  }

  Future<List<SensorUsageEvent>> loadRecentSensorUsage({
    int limit = 120,
  }) async {
    final db = await database;
    final rows = await db.query(
      _sensorUsageTable,
      orderBy: 'createdAt ASC',
      limit: limit,
    );
    return rows.map((row) {
      return SensorUsageEvent(
        id: row['id'] as String,
        createdAt: DateTime.parse(row['createdAt'] as String),
        activityState: row['activityState'] as String,
        accelerometerMagnitude: (row['accelerometerMagnitude'] as num)
            .toDouble(),
        gyroscopeMagnitude: (row['gyroscopeMagnitude'] as num).toDouble(),
        ambientMeanDecibel:
            (row['ambientMeanDecibel'] as num?)?.toDouble() ?? 0,
        ambientPeakDecibel:
            (row['ambientPeakDecibel'] as num?)?.toDouble() ?? 0,
        mealSoundLikelihood:
            (row['mealSoundLikelihood'] as num?)?.toDouble() ?? 0,
        screenUnlockCount: (row['screenUnlockCount'] as num).toInt(),
        appUsageMinutes: (row['appUsageMinutes'] as num).toInt(),
        idleMinutes: (row['idleMinutes'] as num).toInt(),
        charging: ((row['charging'] as num?)?.toInt() ?? 0) == 1,
      );
    }).toList();
  }

  Future<List<SensorUsageEvent>> loadSensorUsageBetween({
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final db = await database;
    final rows = await db.query(
      _sensorUsageTable,
      where: 'createdAt >= ? AND createdAt <= ?',
      whereArgs: [startAt.toIso8601String(), endAt.toIso8601String()],
      orderBy: 'createdAt ASC',
    );

    return rows.map((row) {
      return SensorUsageEvent(
        id: row['id'] as String,
        createdAt: DateTime.parse(row['createdAt'] as String),
        activityState: row['activityState'] as String,
        accelerometerMagnitude: (row['accelerometerMagnitude'] as num)
            .toDouble(),
        gyroscopeMagnitude: (row['gyroscopeMagnitude'] as num).toDouble(),
        ambientMeanDecibel:
            (row['ambientMeanDecibel'] as num?)?.toDouble() ?? 0,
        ambientPeakDecibel:
            (row['ambientPeakDecibel'] as num?)?.toDouble() ?? 0,
        mealSoundLikelihood:
            (row['mealSoundLikelihood'] as num?)?.toDouble() ?? 0,
        screenUnlockCount: (row['screenUnlockCount'] as num).toInt(),
        appUsageMinutes: (row['appUsageMinutes'] as num).toInt(),
        idleMinutes: (row['idleMinutes'] as num).toInt(),
        charging: ((row['charging'] as num?)?.toInt() ?? 0) == 1,
      );
    }).toList();
  }

  /// Filters in Dart rather than via a SQL `WHERE createdAt >= ?` clause
  /// because probe rows are written natively as UTC ISO strings while
  /// [startAt]/[endAt] are typically local wall-clock times — comparing the
  /// two representations as raw strings would silently misfilter by the
  /// timezone offset. `DateTime.parse` + `.toUtc()` normalizes both sides.
  Future<List<SleepProbeEvent>> loadSleepProbeEventsBetween({
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final db = await database;
    final rows = await db.query(_sleepProbeTable, orderBy: 'createdAt ASC');
    final startUtc = startAt.toUtc();
    final endUtc = endAt.toUtc();

    return rows
        .map((row) {
          return SleepProbeEvent(
            id: row['id'] as String,
            createdAt: DateTime.parse(row['createdAt'] as String),
            screenOff: ((row['screenOff'] as num?)?.toInt() ?? 0) == 1,
            charging: ((row['charging'] as num?)?.toInt() ?? 0) == 1,
          );
        })
        .where((event) {
          final eventUtc = event.createdAt.toUtc();
          return !eventUtc.isBefore(startUtc) && !eventUtc.isAfter(endUtc);
        })
        .toList();
  }

  /// Resolves the sleep window used for risk scoring: the passively
  /// estimated window from overnight probes when Sleep Intelligence is on
  /// and last night had enough coverage to trust, otherwise the user's
  /// static survey [fallbackSleepTime]/[fallbackWakeTime] unchanged. Looks
  /// back 20 hours (not a fixed calendar night) so it doesn't need to
  /// reason about which side of midnight the configured window falls on —
  /// SleepIntelligenceEngine finds the best matching rest period within
  /// whatever probes exist in that span.
  Future<({String? sleepTime, String? wakeTime})> resolveEffectiveSleepWindow({
    required String? fallbackSleepTime,
    required String? fallbackWakeTime,
  }) async {
    final enabled = (await loadSetting('sleep_intelligence_enabled')) == '1';
    if (!enabled) {
      return (sleepTime: fallbackSleepTime, wakeTime: fallbackWakeTime);
    }

    final windowStart = int.tryParse(
      (await loadSetting('sleep_probe_window_start_minute')) ?? '',
    );
    final windowEnd = int.tryParse(
      (await loadSetting('sleep_probe_window_end_minute')) ?? '',
    );
    if (windowStart == null || windowEnd == null) {
      return (sleepTime: fallbackSleepTime, wakeTime: fallbackWakeTime);
    }
    final interval =
        int.tryParse(
          (await loadSetting('sleep_probe_interval_minutes')) ?? '',
        ) ??
        45;

    final probes = await loadSleepProbeEventsBetween(
      startAt: DateTime.now().subtract(const Duration(hours: 20)),
      endAt: DateTime.now(),
    );

    final estimate = _sleepIntelligenceEngine.estimateSleepWindow(
      probes: probes,
      windowStartMinute: windowStart,
      windowEndMinute: windowEnd,
      intervalMinutes: interval,
      fallbackSleepTime: fallbackSleepTime ?? '23:00',
      fallbackWakeTime: fallbackWakeTime ?? '07:00',
    );

    return (sleepTime: estimate.sleepTime, wakeTime: estimate.wakeTime);
  }

  Future<List<SignificantPlace>> loadSignificantPlaces() async {
    final db = await database;
    final rows = await db.query(
      _significantPlacesTable,
      orderBy: 'visitCount DESC',
    );
    return rows.map((row) {
      return SignificantPlace(
        id: row['id'] as String,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        visitCount: (row['visitCount'] as num).toInt(),
        firstSeenAt: DateTime.parse(row['firstSeenAt'] as String),
        lastSeenAt: DateTime.parse(row['lastSeenAt'] as String),
      );
    }).toList();
  }

  /// Replaces the entire place set in one transaction — [PlaceClusteringEngine]
  /// always returns the full updated (<=8-row) list, so a delete+reinsert is
  /// simpler and just as cheap as diffing at this size.
  Future<void> saveSignificantPlaces(List<SignificantPlace> places) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_significantPlacesTable);
      for (final place in places) {
        await txn.insert(_significantPlacesTable, {
          'id': place.id,
          'latitude': place.latitude,
          'longitude': place.longitude,
          'visitCount': place.visitCount,
          'firstSeenAt': place.firstSeenAt.toIso8601String(),
          'lastSeenAt': place.lastSeenAt.toIso8601String(),
        });
      }
    });
  }

  Future<List<LocationVisitEvent>> loadLocationVisitEvents({
    int limit = 100,
  }) async {
    final db = await database;
    final rows = await db.query(
      _locationVisitEventsTable,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map((row) {
      return LocationVisitEvent(
        id: row['id'] as String,
        placeId: row['placeId'] as String,
        transitionType: row['transitionType'] as String,
        createdAt: DateTime.parse(row['createdAt'] as String),
      );
    }).toList();
  }

  Future<void> saveStepCounterSample(StepCounterSample sample) async {
    final db = await database;
    await db.insert(_stepCounterSamplesTable, {
      'id': sample.id,
      'createdAt': sample.createdAt.toIso8601String(),
      'cumulativeSteps': sample.cumulativeSteps,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StepCounterSample>> loadStepCounterSamples({
    DateTime? since,
  }) async {
    final db = await database;
    final rows = await db.query(
      _stepCounterSamplesTable,
      orderBy: 'createdAt ASC',
    );
    final samples = rows.map((row) {
      return StepCounterSample(
        id: row['id'] as String,
        createdAt: DateTime.parse(row['createdAt'] as String),
        cumulativeSteps: (row['cumulativeSteps'] as num).toInt(),
      );
    });
    if (since == null) {
      return samples.toList();
    }
    final sinceUtc = since.toUtc();
    return samples
        .where((sample) => !sample.createdAt.toUtc().isBefore(sinceUtc))
        .toList();
  }

  /// 'started' is written the moment a task is accepted (see
  /// notification_service.dart's ACTION_TASK_DONE handler) — it is not an
  /// outcome, just an acceptance event, and every accepted task writes one
  /// regardless of how it later resolves. Counting it here used to sink
  /// completion rates toward 50% even for a user who never failed a task,
  /// since 'started' matched none of the success substrings and fell into
  /// the failure bucket by default.
  static const _taskResultNonOutcomeValues = {'started'};

  Future<List<TaskHistory>> loadTaskHistory() async {
    final records = await loadSurveyHistory();
    return records
        .where(
          (record) =>
              record.type == 'task_result' &&
              (record.taskTitle?.isNotEmpty ?? false) &&
              !_taskResultNonOutcomeValues.contains(
                (record.taskResult ?? '').toLowerCase(),
              ),
        )
        .map((record) {
          final resultText = (record.taskResult ?? '').toLowerCase();
          // Checked before the 'basar' substring below: 'basarisiz'
          // ('unsuccessful') contains 'basar' ('success') as a prefix, so
          // without this a failure written in that form would be counted as
          // a success. Nothing currently writes 'basarisiz', but the
          // substring match alone would silently invert the moment
          // something did.
          final failed = resultText.contains('basarisiz');
          final completed =
              !failed &&
              (resultText.contains('success') ||
                  resultText.contains('basar') ||
                  resultText.contains('tamam'));
          return TaskHistory(
            taskId: record.id,
            taskTitle: record.taskTitle ?? 'Task',
            completed: completed,
            date: record.completedAt,
          );
        })
        .toList();
  }

  Future<Map<String, int>> loadTaskOutcomeSummary() async {
    final taskHistory = await loadTaskHistory();
    var successCount = 0;
    var failureCount = 0;
    var recentSuccessCount = 0;
    var recentFailureCount = 0;

    for (final item in taskHistory) {
      if (item.completed) {
        successCount += 1;
      } else {
        failureCount += 1;
      }
    }

    final recent = taskHistory.length > 10
        ? taskHistory.sublist(taskHistory.length - 10)
        : taskHistory;
    for (final item in recent) {
      if (item.completed) {
        recentSuccessCount += 1;
      } else {
        recentFailureCount += 1;
      }
    }

    return {
      'successCount': successCount,
      'failureCount': failureCount,
      'recentSuccessCount': recentSuccessCount,
      'recentFailureCount': recentFailureCount,
      'totalBarrierOutcomes': successCount + failureCount,
    };
  }

  Future<void> saveBehaviorSnapshot(Map<String, dynamic> snapshot) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert(_behaviorSnapshotTable, {
      'id': 'behavior_${now.microsecondsSinceEpoch}',
      'createdAt': now.toIso8601String(),
      'snapshotJson': jsonEncode(snapshot),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveTaskResult({
    required String taskTitle,
    required String taskResult,
    required DateTime completedAt,
  }) async {
    final languageCode = await LanguageService.loadSelectedLanguageCode();
    final record = SurveyRecord(
      id: 'task_${completedAt.millisecondsSinceEpoch}',
      completedAt: completedAt,
      type: 'task_result',
      title: AppTexts.textForCode(languageCode, 'taskResultTitle'),
      name: '',
      packsPerDay: '1 paketten az',
      exhaleTestSeconds: 0,
      inhaleTestSeconds: 0,
      riskScore: 0,
      riskLevel: 'BİLİNMEYEN',
      taskTitle: taskTitle,
      taskResult: taskResult,
    );
    await saveSurveyRecord(record);
    await markBehaviorDirty();
  }

  Future<void> saveTaskFollowUp({
    required String taskTitle,
    required DateTime scheduledAt,
  }) async {
    final db = await database;
    final now = DateTime.now();
    await db.insert(_taskFollowUpTable, {
      'id': 'followup_${now.microsecondsSinceEpoch}',
      'taskTitle': taskTitle,
      'scheduledAt': scheduledAt.toIso8601String(),
      'status': 'pending',
      'createdAt': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AdaptiveTaskState> loadAdaptiveTaskState({
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    final rows = await db.query(
      _adaptiveTaskStateTable,
      where: 'id = ?',
      whereArgs: ['default'],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return AdaptiveTaskState.fromJson(rows.first);
    }

    final initial = AdaptiveTaskState.initial();
    await saveAdaptiveTaskState(initial, executor: executor);
    return initial;
  }

  Future<void> saveAdaptiveTaskState(
    AdaptiveTaskState state, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    await db.insert(
      _adaptiveTaskStateTable,
      state.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AdaptiveHourlyProfileEntry>> loadAdaptiveHourlyProfile({
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    final rows = await db.query(
      _adaptiveHourlyProfileTable,
      orderBy: 'hour ASC',
    );
    if (rows.isNotEmpty) {
      return rows
          .map((row) => AdaptiveHourlyProfileEntry.fromJson(row))
          .toList();
    }

    final seeded = List<AdaptiveHourlyProfileEntry>.generate(
      24,
      (index) => AdaptiveHourlyProfileEntry.initial(index),
    );
    final batch = db.batch();
    for (final entry in seeded) {
      batch.insert(
        _adaptiveHourlyProfileTable,
        entry.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    return seeded;
  }

  Future<void> saveAdaptiveHourlyProfileEntry(
    AdaptiveHourlyProfileEntry entry, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    await db.insert(
      _adaptiveHourlyProfileTable,
      entry.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveAdaptiveTaskEvent(
    AdaptiveTaskEvent event, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    await db.insert(
      _adaptiveTaskEventTable,
      event.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AdaptiveTaskEvent>> loadRecentAdaptiveTaskEvents({
    int limit = 200,
  }) async {
    final db = await database;
    final rows = await db.query(
      _adaptiveTaskEventTable,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows
        .map(
          (row) => AdaptiveTaskEvent(
            id: row['id'] as String,
            taskTitle: row['taskTitle'] as String,
            scheduledAt: DateTime.parse(row['scheduledAt'] as String),
            respondedAt: DateTime.parse(row['respondedAt'] as String),
            outcome: row['outcome'] as String,
            plannedDurationMinutes: (row['plannedDurationMinutes'] as num)
                .toInt(),
            responseDelayMinutes: (row['responseDelayMinutes'] as num).toInt(),
            hourBucket: (row['hourBucket'] as num).toInt(),
          ),
        )
        .toList();
  }

  static const _adaptivePlanDateKey = 'adaptive_plan_cache_date';
  static const _adaptivePlanJsonKey = 'adaptive_plan_cache_json';

  /// The current no-smoking barrier, and the day the week it belongs to
  /// began. Persisted rather than recomputed because it's a running figure:
  /// it starts from the user's own smoking gap and then moves a step a week
  /// from wherever it got to, so recomputing from the survey each time would
  /// throw away every week of progress.
  static const _barrierMinutesKey = 'current_barrier_minutes';
  static const _barrierWeekStartKey = 'current_barrier_week_start';

  /// Mentor-granted temporary relief, set by [applyMentorFollowUpChoice] —
  /// both take effect starting tomorrow, never today, so they can never
  /// collide with a plan/tasks already delivered for the current day.
  static const _mentorTaskReliefUntilKey = 'mentor_task_relief_until';
  static const _mentorBarrierReliefDateKey = 'mentor_barrier_relief_date';

  /// Cigarettes the user logged since [since], or null when they logged
  /// nothing at all.
  ///
  /// The distinction matters: null means "we have no idea", which the weekly
  /// review answers by falling back to task success. Returning 0 instead
  /// would read as a perfect week and stretch the barrier for someone who had
  /// simply stopped pressing the button.
  Future<int?> countSmokingEventsSince(DateTime since) async {
    final db = await database;
    final rows = await db.query(
      _smokingEventsTable,
      columns: ['id'],
      where: 'timestamp >= ?',
      whereArgs: [since.toIso8601String()],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.length;
  }

  /// Share of tasks answered since [since] that were seen through.
  ///
  /// Unanswered and postponed tasks count against it — a task the user let
  /// lapse is not evidence the barrier was met. Returns 0 when no tasks were
  /// issued at all, so a silent week can't earn an increase.
  Future<double> taskSuccessRateSince(DateTime since) async {
    final db = await database;
    final rows = await db.query(
      _adaptiveTaskEventTable,
      columns: ['outcome'],
      where: 'createdAt >= ?',
      whereArgs: [since.toIso8601String()],
    );
    if (rows.isEmpty) {
      return 0;
    }
    final successes = rows
        .where((row) => row['outcome'] == AdaptiveTaskOutcome.success)
        .length;
    return successes / rows.length;
  }

  /// Reads the survey answers the barrier arithmetic needs.
  Future<SmokingWindowInput> loadSmokingWindowInput() async {
    final relevantSurveyRecords = await _loadRelevantSurveyRecords();
    final contextMap = await loadSurveyContextByRecordId();
    final profile = _buildMergedProfileContext(
      surveyRecords: relevantSurveyRecords,
      contextMap: contextMap,
    );

    final latestSurvey = relevantSurveyRecords.isEmpty
        ? null
        : relevantSurveyRecords.last;
    final dailyCigarettes = latestSurvey == null
        ? 20
        : SurveyRecord.packsToLegacyCigarettes(latestSurvey.packsPerDay);

    final breakWindows =
        (profile['breakWindows'] as List<Map<String, String>>? ??
        const <Map<String, String>>[]);

    return SmokingWindowInput(
      wakeTime: (profile['wakeTime'] as String?) ?? '07:00',
      sleepTime: (profile['sleepTime'] as String?) ?? '23:00',
      workStart: profile['workStart'] as String?,
      workEnd: profile['workEnd'] as String?,
      workplaceRule: profile['workplaceSmokingRule'] as String?,
      breaks: breakWindows
          .map((w) => (w['start'] ?? '', w['end'] ?? ''))
          .where((pair) => pair.$1.isNotEmpty && pair.$2.isNotEmpty)
          .toList(growable: false),
      dailyCigarettes: dailyCigarettes,
    );
  }

  /// The barrier in force today, evolving it first if a week has passed.
  ///
  /// The first call seeds it from the survey — a quarter above the gap the
  /// user's own answers imply. Every seventh day after that it's re-judged
  /// against how the week actually went, then held steady until the next
  /// review. Deliberately not re-judged daily: a single bad day is noise, and
  /// moving the target underneath someone mid-week means they never find out
  /// whether they could have met it.
  Future<int> loadCurrentBarrierMinutes({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final input = await loadSmokingWindowInput();
    final stored = int.tryParse(await loadSetting(_barrierMinutesKey) ?? '');

    if (stored == null) {
      final seeded = _smokingIntervalService.startingBarrierMinutes(input);
      await saveSetting(_barrierMinutesKey, seeded.toString());
      await saveSetting(_barrierWeekStartKey, today.toIso8601String());
      return seeded;
    }

    final weekStart =
        DateTime.tryParse(await loadSetting(_barrierWeekStartKey) ?? '') ??
        today;
    if (today.difference(weekStart).inDays < 7) {
      return stored;
    }

    final target = _smokingIntervalService.impliedDailyTarget(
      input: input,
      barrierMinutes: stored,
    );
    final evolved = _smokingIntervalService.evolveWeeklyBarrierMinutes(
      currentMinutes: stored,
      goodWeek: _smokingIntervalService.isGoodWeek(
        loggedCigarettes: await countSmokingEventsSince(weekStart),
        targetCigarettes: target * 7,
        taskSuccessRate: await taskSuccessRateSince(weekStart),
      ),
    );

    await saveSetting(_barrierMinutesKey, evolved.toString());
    await saveSetting(_barrierWeekStartKey, today.toIso8601String());
    return evolved;
  }

  /// The three figures the home page reports: how many days running the user
  /// stayed at or under target, how many cigarettes that adds up to not
  /// smoking, and how far the barrier has moved from their natural gap.
  ///
  /// Replaces a counter that read `now - quitDate` and never once asked
  /// whether the user had smoked. Every figure here comes from a logged
  /// cigarette or an answered task, and days with neither are treated as
  /// unknown rather than quietly counted as good.
  Future<ReductionProgress> loadReductionProgress({
    DateTime? now,
    int lookbackDays = 400,
  }) async {
    final today = now ?? DateTime.now();
    final input = await loadSmokingWindowInput();
    final barrier = await loadCurrentBarrierMinutes(now: today);
    final natural = _smokingIntervalService.naturalIntervalMinutes(input);
    final target = _smokingIntervalService.impliedDailyTarget(
      input: input,
      barrierMinutes: barrier,
    );

    final since = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: lookbackDays));
    final smokedByDay = await _countByDay(
      table: _smokingEventsTable,
      timestampColumn: 'timestamp',
      since: since,
    );
    final taskDays = await _taskSuccessRateByDay(since: since);

    var longestCompletedBarrierMinutes = 0;
    for (final event in await loadRecentAdaptiveTaskEvents()) {
      if (event.outcome == AdaptiveTaskOutcome.success &&
          event.plannedDurationMinutes > longestCompletedBarrierMinutes) {
        longestCompletedBarrierMinutes = event.plannedDurationMinutes;
      }
    }

    var streak = 0;
    var avoided = 0;
    var evidenceDays = 0;
    var streakOpen = true;

    for (var back = 0; back <= lookbackDays; back++) {
      final day = _dayKey(today.subtract(Duration(days: back)));
      final smoked = smokedByDay[day];
      final successRate = taskDays[day];

      if (smoked == null && successRate == null) {
        // No evidence either way. Today can legitimately be empty — it may
        // only be nine in the morning — so an empty today doesn't end
        // anything. An empty day further back does: we can't credit a day we
        // know nothing about, and counting it would bring back exactly the
        // bug this replaced.
        if (back > 0) streakOpen = false;
        continue;
      }

      evidenceDays++;
      if (smoked != null) {
        avoided += max(0, input.dailyCigarettes - smoked);
      }

      // A logged count is direct evidence and outranks task outcomes. Task
      // outcomes are the fallback for the many users who never press the
      // quick-log button; the 0.6 threshold matches the weekly review's.
      final metTarget = smoked != null ? smoked <= target : successRate! >= 0.6;
      if (streakOpen) {
        if (metTarget) {
          streak++;
        } else {
          streakOpen = false;
        }
      }
    }

    return ReductionProgress(
      targetStreakDays: streak,
      cigarettesAvoided: avoided,
      naturalIntervalMinutes: natural,
      currentBarrierMinutes: barrier,
      dailyTarget: target,
      baselineDaily: input.dailyCigarettes,
      loggedToday: smokedByDay[_dayKey(today)],
      evidenceDays: evidenceDays,
      longestCompletedBarrierMinutes: longestCompletedBarrierMinutes,
    );
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Rows per calendar day, keyed by local date. Grouped in Dart rather than
  /// SQL because the timestamps are stored as ISO strings in local time and
  /// SQLite's date functions would reinterpret them as UTC.
  Future<Map<String, int>> _countByDay({
    required String table,
    required String timestampColumn,
    required DateTime since,
  }) async {
    final db = await database;
    final rows = await db.query(
      table,
      columns: [timestampColumn],
      where: '$timestampColumn >= ?',
      whereArgs: [since.toIso8601String()],
    );
    final counts = <String, int>{};
    for (final row in rows) {
      final parsed = DateTime.tryParse(row[timestampColumn] as String? ?? '');
      if (parsed == null) continue;
      final key = _dayKey(parsed);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, double>> _taskSuccessRateByDay({
    required DateTime since,
  }) async {
    final db = await database;
    final rows = await db.query(
      _adaptiveTaskEventTable,
      columns: ['createdAt', 'outcome'],
      where: 'createdAt >= ?',
      whereArgs: [since.toIso8601String()],
    );
    final total = <String, int>{};
    final succeeded = <String, int>{};
    for (final row in rows) {
      final parsed = DateTime.tryParse(row['createdAt'] as String? ?? '');
      if (parsed == null) continue;
      final key = _dayKey(parsed);
      total[key] = (total[key] ?? 0) + 1;
      if (row['outcome'] == AdaptiveTaskOutcome.success) {
        succeeded[key] = (succeeded[key] ?? 0) + 1;
      }
    }
    return {
      for (final entry in total.entries)
        entry.key: (succeeded[entry.key] ?? 0) / entry.value,
    };
  }

  /// The daily task plan (how many tasks, when, how long) is generated from
  /// the behavior engine's *current* learned state (success rate,
  /// difficulty, hourly strain profile) — that connection is deliberate and
  /// must stay live. What must NOT happen is regenerating a fresh *random*
  /// plan on every app launch: `buildDailyAdaptivePlan` rolls randomness
  /// into both the task count and each task's timing, so re-running it
  /// mid-day (e.g. every time the process restarts) silently reshuffles
  /// which tasks exist — the exact reason the mandatory-task screen kept
  /// treating already-known tasks as unfamiliar. Caching the plan for the
  /// current calendar day fixes that without breaking the adaptive
  /// connection: a new plan is still generated once per day, from whatever
  /// the behavior engine has learned as of that morning.
  static const _interventionIntensityKey = 'intervention_intensity';

  /// 'gentle' / 'balanced' (default) / 'strict' — chosen once during
  /// onboarding, how aggressively the discipline protocol should interrupt
  /// the user during the day. Kept as a plain string setting (like the
  /// duration-barrier preferences) rather than an enum so old saved values
  /// never fail to parse across app versions.
  static const _budgetDateKey = 'notification_budget_date';
  static const _budgetSentKey = 'notification_budget_offered_sent';
  static const _budgetLastSentKey = 'notification_budget_last_sent';

  /// How many *offered* notifications have gone out today, and when anything
  /// was last sent.
  ///
  /// The count resets by date rather than by a rolling window: the budget the
  /// user chose is a daily allowance, and a rolling window would let a quiet
  /// evening silently reopen the morning's spend.
  Future<(int, DateTime?)> loadNotificationBudgetState({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey = _dayKey(today);
    final storedDate = await loadSetting(_budgetDateKey);
    if (storedDate != todayKey) {
      return (0, null);
    }
    final sent = int.tryParse(await loadSetting(_budgetSentKey) ?? '') ?? 0;
    final lastSent = DateTime.tryParse(
      await loadSetting(_budgetLastSentKey) ?? '',
    );
    return (sent, lastSent);
  }

  /// Records that a notification was sent. [countsAgainstBudget] is false for
  /// the kinds the user is owed — they still move the spacing clock, because
  /// two notifications a minute apart are one interruption regardless of who
  /// sent them, but they must not consume the allowance.
  Future<void> recordNotificationSent({
    required bool countsAgainstBudget,
    DateTime? at,
  }) async {
    final when = at ?? DateTime.now();
    final todayKey = _dayKey(when);
    final storedDate = await loadSetting(_budgetDateKey);
    var sent = storedDate == todayKey
        ? (int.tryParse(await loadSetting(_budgetSentKey) ?? '') ?? 0)
        : 0;
    if (countsAgainstBudget) {
      sent += 1;
    }
    await saveSetting(_budgetDateKey, todayKey);
    await saveSetting(_budgetSentKey, sent.toString());
    await saveSetting(_budgetLastSentKey, when.toIso8601String());
  }

  /// Whether the user wants a given *offered* notification kind at all.
  ///
  /// Only [NotificationKind]s the app merely offers are ever asked about here
  /// — the ones the user is owed (a due task, a dose they scheduled
  /// themselves) are not a preference to switch off, they are a promise the
  /// app already made. Defaults to on: someone who has never opened this
  /// screen gets the same behaviour as before it existed.
  Future<bool> isNotificationKindEnabled(String kindName) async {
    final raw = await loadSetting('notification_kind_enabled_$kindName');
    return raw != '0';
  }

  Future<void> setNotificationKindEnabled(String kindName, bool enabled) async {
    await saveSetting(
      'notification_kind_enabled_$kindName',
      enabled ? '1' : '0',
    );
  }

  /// How many health-condition tips the user wants per day.
  ///
  /// Defaults to 3 — up from the previous hardcoded 1 — for someone who has
  /// never opened the setting. Clamped to 1-5 wherever it's used since the
  /// picker only offers that range.
  Future<int> loadDailyHealthTipCount() async {
    final raw = await loadSetting('daily_health_tip_count');
    return int.tryParse(raw ?? '') ?? 3;
  }

  Future<void> setDailyHealthTipCount(int value) async {
    await saveSetting('daily_health_tip_count', value.toString());
  }

  Future<String> loadInterventionIntensity() async {
    final raw = await loadSetting(_interventionIntensityKey);
    if (raw == 'gentle' || raw == 'strict') {
      return raw!;
    }
    return 'balanced';
  }

  Future<void> saveInterventionIntensity(String value) async {
    await saveSetting(_interventionIntensityKey, value);
  }

  /// Translates the chosen intensity into the adaptive plan's starting
  /// daily task count — the single biggest lever over how often the user
  /// gets interrupted. [DisciplineProtocolService.buildDailyAdaptivePlan]
  /// still adapts this up/down from success/failure rate on top of
  /// whichever baseline this returns.
  Future<int> loadInterventionBaselineTaskCount() async {
    final intensity = await loadInterventionIntensity();
    switch (intensity) {
      case 'gentle':
        return 3;
      case 'strict':
        return 7;
      default:
        return 5;
    }
  }

  /// True when the user has switched the barrier off entirely.
  ///
  /// Two settings can say so: `duration_barrier_enabled` (the on/off switch
  /// in coach_mode_page.dart and the top-level Settings row that mirrors
  /// it) and the legacy `duration_barrier_preference == 'off'` value
  /// ai_chat_page.dart's AI tool call can still write. Both are checked so
  /// neither write path is silently ignored. Consent, not tuning: this must
  /// stop a barrier task from being generated at all, not just adjust one —
  /// see buildAdaptiveNoSmokePlan, which checks this before doing any of
  /// the (otherwise wasted) barrier-length/task-count work below.
  Future<bool> _isDurationBarrierDisabled() async {
    final enabledRaw = await loadSetting('duration_barrier_enabled');
    if (enabledRaw == '0') {
      return true;
    }
    final preferenceRaw = await loadSetting('duration_barrier_preference');
    return preferenceRaw == 'off';
  }

  Future<AdaptiveTaskPlan> buildAdaptiveNoSmokePlan({
    required DateTime now,
    required DateTime sleepAt,
    required List<String> riskyHours,
  }) async {
    // Checked first, before any of the (otherwise wasted) barrier-length/
    // task-count work below: this is a consent switch, not a tuning knob,
    // and must be able to produce an empty plan on its own.
    if (await _isDurationBarrierDisabled()) {
      return const AdaptiveTaskPlan(
        targetTaskCount: 0,
        baseDurationMinutes: 0,
        items: [],
      );
    }

    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cachedDate = await loadSetting(_adaptivePlanDateKey);
    if (cachedDate == todayKey) {
      final cachedJson = await loadSetting(_adaptivePlanJsonKey);
      if (cachedJson != null) {
        try {
          return AdaptiveTaskPlan.fromJson(
            jsonDecode(cachedJson) as Map<String, dynamic>,
          );
        } catch (_) {
          // Fall through and regenerate if the cached JSON is somehow
          // unreadable (e.g. a future app version changed the shape).
        }
      }
    }

    final state = await loadAdaptiveTaskState();
    final hourly = await loadAdaptiveHourlyProfile();
    final windowInput = await loadSmokingWindowInput();
    // The pre-sleep routine lands 1 hour before sleepAt (see
    // TaskAssignmentService.buildSleepRoutinePlanItem) — a normal
    // ADAPTIVE_NO_SMOKE task landing in that same narrow stretch would ask
    // the user to start a fresh commitment right as the routine is about to
    // interrupt them anyway.
    final blockedWindows = [
      ..._smokingIntervalService.blockedTaskWindows(windowInput),
      _sleepRoutineBlockedWindow(sleepAt),
    ];
    final barrierMinutes = await loadCurrentBarrierMinutes(now: now);
    final reliefUntilRaw = await loadSetting(_mentorTaskReliefUntilKey);
    final reliefDateRaw = await loadSetting(_mentorBarrierReliefDateKey);
    final effectiveBarrierMinutes =
        MentorReliefService.applyBarrierReliefIfActive(
          baseMinutes: barrierMinutes,
          now: now,
          reliefDate: reliefDateRaw == null
              ? null
              : DateTime.tryParse(reliefDateRaw),
          minBarrierMinutes: SmokingIntervalService.minBarrierMinutes,
        );
    final baseTaskCount = _smokingIntervalService.dailyTaskCount(
      input: windowInput,
      movingSuccessRate: state.movingSuccessRate,
      movingFailureRate: state.movingFailureRate,
      postponeRate: state.postponeRate,
    );
    // User-facing control, independent of the duration axis:
    // duration_barrier_frequency_preference only ever shifts how many
    // barrier tasks land in the day, never their length — the length comes
    // from SmokingIntervalService alone. Clamped to the same 4-8 range
    // dailyTaskCount itself already enforces, so this can't push the count
    // outside what that service considers a sane day.
    final frequencyRaw = await loadSetting(
      'duration_barrier_frequency_preference',
    );
    final frequencyAdjustedCount =
        switch (frequencyRaw) {
          'az' => baseTaskCount - 1,
          'cok' => baseTaskCount + 1,
          _ => baseTaskCount,
        }.clamp(
          SmokingIntervalService.minDailyTasks,
          SmokingIntervalService.maxDailyTasks,
        );
    final effectiveTaskCount = MentorReliefService.applyTaskReliefIfActive(
      baseCount: frequencyAdjustedCount,
      now: now,
      reliefUntil: reliefUntilRaw == null
          ? null
          : DateTime.tryParse(reliefUntilRaw),
    );
    final plan = _disciplineProtocolService.buildDailyAdaptivePlan(
      now: now,
      sleepAt: sleepAt,
      riskyHours: riskyHours,
      barrierMinutes: effectiveBarrierMinutes,
      targetTaskCount: effectiveTaskCount,
      state: state,
      hourlyProfiles: hourly,
      blockedWindows: blockedWindows,
    );
    await saveSetting(_adaptivePlanDateKey, todayKey);
    await saveSetting(_adaptivePlanJsonKey, jsonEncode(plan.toJson()));
    return plan;
  }

  /// The narrow stretch `[sleepAt-70min, sleepAt-50min]` normal tasks may
  /// not land in, clearing room around the pre-sleep routine's own
  /// `sleepAt-60min` slot. Returned as "HH:mm" clock strings, the same shape
  /// `blockedTaskWindows` already produces, since `blockedWindows` only ever
  /// compares clock time, not a specific calendar date.
  (String, String) _sleepRoutineBlockedWindow(DateTime sleepAt) {
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final start = sleepAt.subtract(const Duration(minutes: 70));
    final end = sleepAt.subtract(const Duration(minutes: 50));
    return (hhmm(start), hhmm(end));
  }

  /// Whether today's adaptive plan target has already been met by
  /// successfully-completed tasks. Used to decide, when phone activity is
  /// detected during the user's sleep window, whether to fire a full
  /// mandatory task (quota not yet met -- there's still real work to do
  /// today) or just a small advisory tip (quota already met -- no need to
  /// escalate). Falls back to "not met" if no plan has been cached yet for
  /// today, since there's nothing to have completed.
  Future<bool> isDailyTaskQuotaMet({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final cachedDate = await loadSetting(_adaptivePlanDateKey);
    if (cachedDate != todayKey) {
      return false;
    }
    final cachedJson = await loadSetting(_adaptivePlanJsonKey);
    if (cachedJson == null) {
      return false;
    }

    int targetTaskCount;
    try {
      final plan = AdaptiveTaskPlan.fromJson(
        jsonDecode(cachedJson) as Map<String, dynamic>,
      );
      targetTaskCount = plan.targetTaskCount;
    } catch (_) {
      return false;
    }

    final events = await loadRecentAdaptiveTaskEvents(limit: 200);
    final successfulToday = events.where(
      (event) =>
          event.outcome == AdaptiveTaskOutcome.success &&
          event.respondedAt.year == today.year &&
          event.respondedAt.month == today.month &&
          event.respondedAt.day == today.day,
    );
    return successfulToday.length >= targetTaskCount;
  }

  static const _notifiedTaskTitlesDateKey = 'notified_task_titles_date';
  static const _notifiedTaskTitlesJsonKey = 'notified_task_titles_json';
  static const _minimumTaskNotificationsDateKey =
      'minimum_task_notifications_ensured_date';

  String _todayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  /// Which task titles have already had their trigger notification
  /// scheduled today — persisted (not just in-memory) so a process restart
  /// mid-day doesn't forget and reschedule duplicates. Same root-cause
  /// pattern as [buildAdaptiveNoSmokePlan]'s caching: the in-memory-only
  /// version of this guard reset on every relaunch, so every time the app
  /// was reopened it re-scheduled a fresh notification for every task
  /// still marked 'new', stacking on top of whatever was already pending
  /// from earlier that day.
  Future<Set<String>> loadNotifiedTaskTitlesToday({DateTime? now}) async {
    final todayKey = _todayKey(now ?? DateTime.now());
    final cachedDate = await loadSetting(_notifiedTaskTitlesDateKey);
    if (cachedDate != todayKey) {
      return <String>{};
    }
    final cachedJson = await loadSetting(_notifiedTaskTitlesJsonKey);
    if (cachedJson == null) {
      return <String>{};
    }
    try {
      return (jsonDecode(cachedJson) as List<dynamic>)
          .map((e) => e.toString())
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> markTaskTitleNotifiedToday(
    String taskTitle, {
    DateTime? now,
  }) async {
    final todayKey = _todayKey(now ?? DateTime.now());
    final existing = await loadNotifiedTaskTitlesToday(now: now);
    existing.add(taskTitle);
    await saveSetting(_notifiedTaskTitlesDateKey, todayKey);
    await saveSetting(
      _notifiedTaskTitlesJsonKey,
      jsonEncode(existing.toList()),
    );
  }

  /// Guards `_ensureMinimumFiveNotificationsUntilSleep` (home_page.dart) —
  /// without this, that function scheduled a fresh batch of >=5 additional
  /// notifications on *every* app open with no persisted memory of having
  /// already done so that day, the other half of the same duplicate-
  /// notification bug the title-based guard above fixes.
  Future<bool> hasEnsuredMinimumTaskNotificationsToday({DateTime? now}) async {
    final todayKey = _todayKey(now ?? DateTime.now());
    final cachedDate = await loadSetting(_minimumTaskNotificationsDateKey);
    return cachedDate == todayKey;
  }

  Future<void> markMinimumTaskNotificationsEnsuredToday({DateTime? now}) async {
    await saveSetting(
      _minimumTaskNotificationsDateKey,
      _todayKey(now ?? DateTime.now()),
    );
  }

  Future<Duration> resolveAdaptivePostponeDelay({int baseMinutes = 10}) async {
    final state = await loadAdaptiveTaskState();
    return _disciplineProtocolService.computeAdaptivePostponeDelay(
      state: state,
      baseMinutes: baseMinutes,
    );
  }

  /// [executor] lets a caller that already has its own transaction open
  /// (see [transitionTaskAssignment]) fold this outcome's writes into it,
  /// rather than opening a second, separate one — sqflite doesn't support
  /// nested transactions, and the two are meant to be one atomic unit
  /// there: without this, a process kill between the task's terminal-state
  /// write and this call landing would leave the task stuck in a terminal
  /// state (transitionTaskAssignment's own guard refuses to touch a
  /// terminal row again) with the outcome it should have produced
  /// permanently lost, never retried.
  Future<void> recordAdaptiveTaskOutcome({
    required String taskTitle,
    required String outcome,
    required int plannedDurationMinutes,
    DateTime? scheduledAt,
    DateTime? respondedAt,
    DatabaseExecutor? executor,
  }) async {
    final responded = respondedAt ?? DateTime.now();
    final scheduled =
        scheduledAt ??
        responded.subtract(Duration(minutes: plannedDurationMinutes));
    final responseDelay = responded
        .difference(scheduled)
        .inMinutes
        .clamp(1, 720)
        .toInt();

    final state = await loadAdaptiveTaskState(executor: executor);
    final hourly = await loadAdaptiveHourlyProfile(executor: executor);

    final nextState = _disciplineProtocolService.evolveStateFromOutcome(
      current: state,
      outcome: outcome,
      responseDelayMinutes: responseDelay,
    );

    final hourBucket = scheduled.hour.clamp(0, 23);
    final currentEntry = hourly.firstWhere(
      (item) => item.hour == hourBucket,
      orElse: () => AdaptiveHourlyProfileEntry.initial(hourBucket),
    );
    final nextEntry = _disciplineProtocolService.evolveHourlyProfileFromOutcome(
      current: currentEntry,
      outcome: outcome,
      responseDelayMinutes: responseDelay,
    );

    final event = AdaptiveTaskEvent(
      id: 'adaptive_${responded.microsecondsSinceEpoch}',
      taskTitle: taskTitle,
      scheduledAt: scheduled,
      respondedAt: responded,
      outcome: outcome,
      plannedDurationMinutes: plannedDurationMinutes,
      responseDelayMinutes: responseDelay,
      hourBucket: hourBucket,
    );

    // All four writes describe one logical outcome — run them in a single
    // transaction so a process kill mid-sequence can't leave the adaptive
    // state, hourly profile, and event log out of sync with each other.
    Future<void> writeAll(DatabaseExecutor txn) async {
      await saveAdaptiveTaskState(nextState, executor: txn);
      await saveAdaptiveHourlyProfileEntry(nextEntry, executor: txn);
      await saveAdaptiveTaskEvent(event, executor: txn);
      await saveSetting(_behaviorDirtyKey, '1', executor: txn);
    }

    if (executor != null) {
      await writeAll(executor);
      return;
    }
    final db = await database;
    await db.transaction((txn) async {
      await writeAll(txn);
    });
  }

  Future<void> saveProtocolViolation({
    required String type,
    required String severity,
    String source = 'app_flow',
    String? taskTitle,
    required String details,
    DateTime? createdAt,
    bool resolved = false,
  }) async {
    final db = await database;
    final now = createdAt ?? DateTime.now();
    await db.insert(_protocolViolationTable, {
      'id': 'vio_${now.microsecondsSinceEpoch}',
      'type': type,
      'severity': severity,
      'source': source,
      'taskTitle': taskTitle,
      'details': details,
      // UTC, matching NativeViolationStore.tryInsertNoResponseViolation's
      // formatIsoUtc on the Kotlin side — both writers share this table and
      // it's read back with plain string ORDER BY/comparisons, so a local
      // vs. UTC mismatch here would sort rows out of true chronological
      // order.
      'createdAt': now.toUtc().toIso8601String(),
      'resolved': resolved ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ProtocolViolation>> loadProtocolViolations({
    int limit = 250,
  }) async {
    final db = await database;
    final rows = await db.query(
      _protocolViolationTable,
      orderBy: 'createdAt DESC',
      limit: limit,
    );

    return rows
        .map(
          (row) => ProtocolViolation(
            id: row['id'] as String,
            type: row['type'] as String,
            severity: row['severity'] as String,
            source: (row['source'] as String?) ?? 'app_flow',
            taskTitle: row['taskTitle'] as String?,
            details: row['details'] as String,
            createdAt: DateTime.parse(row['createdAt'] as String),
            resolved: ((row['resolved'] as num?)?.toInt() ?? 0) == 1,
          ),
        )
        .toList();
  }

  /// When the mandatory task screen was last actually shown to the user —
  /// reuses the existing `mandatory_gate` violation log (already written
  /// every time it's shown) instead of a separate, parallel timestamp, so
  /// this stays backed by the same persisted history the behavior/protocol
  /// engines already read. Used to gate against showing it again too soon
  /// after a fresh app relaunch.
  Future<DateTime?> loadLastMandatoryGateShownAt() async {
    final db = await database;
    final rows = await db.query(
      _protocolViolationTable,
      columns: ['createdAt'],
      where: 'type = ?',
      whereArgs: ['mandatory_gate'],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rows.first['createdAt'] as String);
  }

  Future<List<Map<String, dynamic>>> loadPendingTaskFollowUps() async {
    final db = await database;
    final rows = await db.query(
      _taskFollowUpTable,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'scheduledAt ASC',
    );

    return rows
        .map(
          (row) => {
            'id': row['id'] as String,
            'taskTitle': row['taskTitle'] as String,
            'scheduledAt': DateTime.parse(row['scheduledAt'] as String),
            'status': row['status'] as String,
            'createdAt': DateTime.parse(row['createdAt'] as String),
          },
        )
        .toList();
  }

  /// Resolves only the single oldest pending row for [taskTitle]. Multiple
  /// pending rows can share a title (the same recurring task scheduled more
  /// than once), so resolving by title alone must never close more than the
  /// one occurrence being answered.
  Future<void> resolveTaskFollowUpByTitle(String taskTitle) async {
    final db = await database;
    final rows = await db.query(
      _taskFollowUpTable,
      columns: ['id'],
      where: 'taskTitle = ? AND status = ?',
      whereArgs: [taskTitle, 'pending'],
      orderBy: 'scheduledAt ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return;
    }
    await db.update(
      _taskFollowUpTable,
      {'status': 'resolved'},
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
  }

  Future<Map<String, String>> loadConsecutiveSmokingSummary() async {
    final records = await _loadRelevantSurveyRecords();
    if (records.isEmpty) {
      return {
        'latest': 'noRecordYet',
        'previous': 'noRecordYet',
        'trend': 'noRecordYet',
        'status': 'noRecordYet',
      };
    }

    final current = records.last;
    final previous = records.length > 1 ? records[records.length - 2] : null;

    final latestLabel = _behaviorEngine.summarizeConsecutiveSmoking(
      habit: current.consecutiveSmokingHabit,
      count: current.consecutiveSmokingCount,
    );
    final previousLabel = previous == null
        ? 'firstEvaluation'
        : _behaviorEngine.summarizeConsecutiveSmoking(
            habit: previous.consecutiveSmokingHabit,
            count: previous.consecutiveSmokingCount,
          );
    final trend = previous == null
        ? 'noRecordYet'
        : _behaviorEngine.evaluateConsecutiveSmokingTrend(
            previousHabit: previous.consecutiveSmokingHabit,
            previousCount: previous.consecutiveSmokingCount,
            currentHabit: current.consecutiveSmokingHabit,
            currentCount: current.consecutiveSmokingCount,
          );

    return {
      'latest': latestLabel,
      'previous': previousLabel,
      'trend': trend,
      'status': _behaviorEngine.evaluateConsecutiveSmokingStatus(
        habit: current.consecutiveSmokingHabit,
        count: current.consecutiveSmokingCount,
      ),
    };
  }

  Future<void> updateLastSurveyDate(DateTime date) async {
    await saveSetting('last_survey_date', date.toIso8601String());
  }

  Future<DateTime?> loadLastSurveyDate() async {
    final value = await loadSetting('last_survey_date');
    if (value == null) {
      return null;
    }
    return DateTime.parse(value);
  }

  Future<DateTime?> loadLastWeeklyOrInitialSurveyDate() async {
    final records = await loadSurveyHistory();
    for (final record in records.reversed) {
      if (record.type == 'weekly' || record.type == 'initial') {
        return record.completedAt;
      }
    }
    return null;
  }

  Future<bool> isWeeklySurveyOverdue({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final lastSurveyDate = await loadLastWeeklyOrInitialSurveyDate();
    if (lastSurveyDate == null) {
      return false;
    }
    final elapsed = DateTime.now().difference(lastSurveyDate);
    return elapsed >= maxAge;
  }

  Future<DateTime?> loadWeeklySurveyDueDate({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final lastSurveyDate = await loadLastWeeklyOrInitialSurveyDate();
    if (lastSurveyDate == null) {
      return null;
    }
    return lastSurveyDate.add(maxAge);
  }

  /// Bugün kullanıcıya haftalık anket hatırlatıcısı gösterildi mi?
  Future<bool> hasWeeklySurveyBeenPromptedToday() async {
    final raw = await loadSetting('last_weekly_survey_prompt_at');
    if (raw == null || raw.trim().isEmpty) {
      return false;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return false;
    }
    final now = DateTime.now();
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  /// Bugün için haftalık anket hatırlatıcısının gösterildiğini işaretle.
  Future<void> markWeeklySurveyPromptedToday() async {
    await saveSetting(
      'last_weekly_survey_prompt_at',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> saveSleepTime(String sleepTime) async {
    await saveSetting('sleep_time', sleepTime);
  }

  Future<void> saveInitialRegistrationCompleted(bool completed) async {
    await saveSetting(_registrationCompletedKey, completed ? '1' : '0');
    await saveSetting(_isProfileCompletedKey, completed ? '1' : '0');
  }

  Future<void> saveIsProfileCompleted(bool completed) async {
    await saveSetting(_isProfileCompletedKey, completed ? '1' : '0');
  }

  Future<bool> loadIsProfileCompleted() async {
    final value = await loadSetting(_isProfileCompletedKey);
    return value == '1';
  }

  Future<bool> loadInitialRegistrationCompleted() async {
    final profileCompleted = await loadIsProfileCompleted();
    if (profileCompleted) {
      return true;
    }

    final value = await loadSetting(_registrationCompletedKey);
    if (value != null) {
      return value == '1';
    }

    // Do not infer completion from behavior snapshots.
    // A snapshot can exist right after breath test save, before first-task
    // scheduling and completion flags are written.
    return false;
  }

  Future<String?> loadSleepTime() async {
    return loadSetting('sleep_time');
  }

  Future<BehaviorDashboard?> loadLatestBehaviorSnapshot() async {
    final db = await database;
    final rows = await db.query(
      _behaviorSnapshotTable,
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }

    final raw = rows.first['snapshotJson'] as String;
    final data = _tryDecodeJsonMap(raw, field: 'snapshotJson');
    if (data == null) {
      // Corrupted cache entry — treat as "no snapshot available" so the
      // caller (loadBehaviorDashboard) falls through to a fresh
      // recomputation instead of crashing on a bad cached blob.
      return null;
    }
    final planData =
        data['plan'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return BehaviorDashboard(
      riskScore: (data['riskScore'] as num?)?.toInt() ?? 0,
      riskyTriggers: (data['riskyTriggers'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      riskyHours: (data['riskyHours'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      breathTrend: data['breathTrend']?.toString() ?? 'Stable',
      breathTrendLast3: data['breathTrendLast3']?.toString() ?? 'stable',
      breathTrendRiskAdjustment:
          (data['breathTrendRiskAdjustment'] as num?)?.toInt() ?? 0,
      progressSummary: data['progressSummary']?.toString() ?? 'Stable',
      todaysTasks: (data['todaysTasks'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      coachCommands: (data['coachCommands'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      commandSuccessScores:
          (data['commandSuccessScores'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .map(
                (key, value) =>
                    MapEntry(key, (value as num?)?.toDouble() ?? 0.5),
              ),
      commandCategoryScores:
          (data['commandCategoryScores'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .map(
                (key, value) =>
                    MapEntry(key, (value as num?)?.toDouble() ?? 0.5),
              ),
      commandMixMode: data['commandMixMode']?.toString() ?? 'balanced',
      weeklySurveyRiskScore:
          (data['weeklySurveyRiskScore'] as num?)?.toInt() ?? 40,
      weeklySurveyRiskLevel:
          data['weeklySurveyRiskLevel']?.toString() ?? 'medium',
      weeklyTopRiskDrivers:
          (data['weeklyTopRiskDrivers'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      riskExplanation: (data['riskExplanation'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      learnedWeights:
          (data['learnedWeights'] as Map<String, dynamic>? ??
                  const <String, dynamic>{})
              .map(
                (key, value) =>
                    MapEntry(key, (value as num?)?.toDouble() ?? 1.0),
              ),
      predictedRiskWindow:
          data['predictedRiskWindow']?.toString() ?? '20:00-22:00',
      predictionConfidence:
          (data['predictionConfidence'] as num?)?.toInt() ?? 50,
      predictedTrigger: data['predictedTrigger']?.toString() ?? 'Stres',
      plan: AdaptivePlan(
        generatedAt:
            DateTime.tryParse(planData['generatedAt']?.toString() ?? '') ??
            DateTime.now(),
        targetDays: (planData['targetDays'] as num?)?.toInt() ?? 180,
        currentWeek: (planData['currentWeek'] as num?)?.toInt() ?? 1,
        currentDay: (planData['currentDay'] as num?)?.toInt() ?? 1,
        daysRemaining: (planData['daysRemaining'] as num?)?.toInt() ?? 179,
        weeklyRiskTarget: (planData['weeklyRiskTarget'] as num?)?.toInt() ?? 50,
        difficulty: planData['difficulty']?.toString() ?? 'medium',
        cadenceLevel: planData['cadenceLevel']?.toString() ?? 'one_day',
        focusAreas: (planData['focusAreas'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
      ),
    );
  }

  Future<Map<String, double>> loadBreathMetrics() async {
    final records = await loadSurveyHistory();
    final breathRecords = records
        .where((record) => record.type == 'breath_test')
        .toList();

    if (breathRecords.isEmpty) {
      return {'dailyAverage': 0, 'weeklyAverage': 0, 'monthlyAverage': 0};
    }

    final now = DateTime.now();
    final todayRecords = breathRecords
        .where(
          (record) =>
              record.completedAt.year == now.year &&
              record.completedAt.month == now.month &&
              record.completedAt.day == now.day,
        )
        .toList();
    final weekRecords = breathRecords
        .where(
          (record) =>
              record.completedAt.isAfter(now.subtract(const Duration(days: 7))),
        )
        .toList();
    final monthRecords = breathRecords
        .where(
          (record) => record.completedAt.isAfter(
            now.subtract(const Duration(days: 30)),
          ),
        )
        .toList();

    double calculateAverage(List<SurveyRecord> list) {
      if (list.isEmpty) {
        return 0;
      }
      final values = list
          .map(
            (record) =>
                ((record.exhaleTestSeconds + record.inhaleTestSeconds) / 2),
          )
          .toList();
      return values.reduce((a, b) => a + b) / values.length;
    }

    return {
      'dailyAverage': calculateAverage(todayRecords),
      'weeklyAverage': calculateAverage(weekRecords),
      'monthlyAverage': calculateAverage(monthRecords),
    };
  }

  Future<Map<String, dynamic>> loadBreathProgressReport() async {
    final records = await loadSurveyHistory();
    final breathRecords =
        records.where((record) => record.type == 'breath_test').toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (breathRecords.isEmpty) {
      return {
        'latestAverage': 0.0,
        'previousAverage': 0.0,
        'deltaFromPrevious': 0.0,
        'deltaFromMonthlyAverage': 0.0,
        'hasPrevious': false,
      };
    }

    final latest = breathRecords.last;
    final latestAverage =
        ((latest.exhaleTestSeconds + latest.inhaleTestSeconds) / 2).toDouble();
    final previous = breathRecords.length > 1
        ? breathRecords[breathRecords.length - 2]
        : null;
    final previousAverage = previous == null
        ? 0.0
        : ((previous.exhaleTestSeconds + previous.inhaleTestSeconds) / 2)
              .toDouble();
    final metrics = await loadBreathMetrics();
    final monthlyAverage = (metrics['monthlyAverage'] ?? 0.0).toDouble();

    return {
      'latestAverage': latestAverage,
      'previousAverage': previousAverage,
      'deltaFromPrevious': previous == null
          ? 0.0
          : latestAverage - previousAverage,
      'deltaFromMonthlyAverage': latestAverage - monthlyAverage,
      'hasPrevious': previous != null,
    };
  }

  /// Merges profile context (work schedule, health data, latest weekly
  /// payload, etc.) across all prior initial/weekly survey records into a
  /// single map, the same way [loadBehaviorDashboard] does internally. Used
  /// wherever a risk calculation needs the user's up-to-date profile context
  /// without duplicating the merge logic (e.g. weekly survey risk scoring).
  /// The chronic conditions the user reported in the survey.
  ///
  /// Used to pick which health tip rides along with a medication reminder.
  /// Empty when nothing was reported — which the caller must treat as "say
  /// nothing", not as a reason to fall back to generic advice.
  Future<List<String>> loadHealthConditions() async {
    try {
      final profile = await loadMergedProfileContext();
      final raw = profile['healthConditions'];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList(growable: false);
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> loadMergedProfileContext() async {
    final relevantSurveyRecords = await _loadRelevantSurveyRecords();
    final contextMap = await loadSurveyContextByRecordId();
    return _buildMergedProfileContext(
      surveyRecords: relevantSurveyRecords,
      contextMap: contextMap,
    );
  }

  /// Predicts the user's likely smoking hours for today from structural
  /// survey data (+ weekly-survey trigger/meal data when available). See
  /// [SmokingTimePredictionEngine] for the underlying model.
  Future<SmokingTimePrediction> loadSmokingTimePrediction({
    DateTime? now,
  }) async {
    final profileContext = await loadMergedProfileContext();
    final records = await loadSurveyHistory();
    final languageCode = await LanguageService.loadSelectedLanguageCode();
    final latestSurvey = records.reversed.firstWhere(
      (record) => _surveyTypes.contains(record.type),
      orElse: () => SurveyRecord(
        id: 'fallback',
        completedAt: DateTime.fromMillisecondsSinceEpoch(0),
        type: 'initial',
        title: AppTexts.textForCode(languageCode, 'initialSurvey'),
        name: '',
        packsPerDay: '1 paketten az',
        exhaleTestSeconds: 0,
        inhaleTestSeconds: 0,
        riskScore: 0,
        riskLevel: 'BİLİNMEYEN',
      ),
    );
    final today = now ?? DateTime.now();
    final isWeekend =
        today.weekday == DateTime.saturday || today.weekday == DateTime.sunday;

    final prior = _smokingTimePredictionEngine.predict(
      profileContext: profileContext,
      packsPerDay: latestSurvey.packsPerDay,
      isWeekend: isWeekend,
    );

    // Weekdays and weekends are shaped differently, so a weekend prediction
    // is calibrated against weekend entries only — folding in weekday
    // afternoons would flatten out exactly the difference being predicted.
    final logged = await loadSmokingEvents(
      since: today.subtract(const Duration(days: 90)),
      limit: 2000,
    );
    final relevant = logged
        .where((event) {
          final weekend =
              event.timestamp.weekday == DateTime.saturday ||
              event.timestamp.weekday == DateTime.sunday;
          return weekend == isWeekend;
        })
        .map((event) => event.timestamp)
        .toList(growable: false);

    return _smokingTimePredictionEngine.calibrateWithLoggedEvents(
      prior: prior,
      loggedTimes: relevant,
    );
  }

  // ---------------------------------------------------------------------
  // Task assignments
  // ---------------------------------------------------------------------

  Future<void> saveTaskAssignment(
    TaskAssignment task, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    await db.insert(
      _taskAssignmentsTable,
      task.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<TaskAssignment?> loadTaskAssignment(
    String id, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await database;
    final rows = await db.query(
      _taskAssignmentsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TaskAssignment.fromJson(rows.first);
  }

  /// The task a canonical title most recently belongs to.
  ///
  /// Notification payloads still carry only `ADAPTIVE_NO_SMOKE:<minutes>`, so
  /// an answer arriving from a notification has to be matched back to a row
  /// by title. The same duration recurs across days (and, with jitter,
  /// occasionally within the same day), so more than one row can share a
  /// title — an in-flight (non-terminal) row is preferred over a resolved
  /// one, since an answer can only ever be about a task still actually
  /// awaiting one; a plain "most recent by scheduledAt" would otherwise
  /// sometimes hand back an already-succeeded/failed row from later in the
  /// day instead of the still-open one the response was actually about.
  /// [TaskAssignment.transitionTaskAssignment]'s own terminal-state guard
  /// already prevents *that* wrong match from corrupting a finished task,
  /// but this still preferred one, non-terminal row can accidentally
  /// mutate the wrong currently-open task — only genuinely simultaneous
  /// same-title in-flight tasks (not fully eliminated by this) remain
  /// unresolved without threading the assignment id itself through the
  /// notification payload, a larger change.
  /// Falls back to the most recent row of any state when nothing
  /// non-terminal exists, matching every caller that legitimately wants a
  /// completed task's own row (e.g. displaying its final outcome).
  Future<TaskAssignment?> loadLatestTaskAssignmentByTitle(String title) async {
    final db = await database;
    final nonTerminalRows = await db.query(
      _taskAssignmentsTable,
      where:
          'canonicalTitle = ? AND state NOT IN (${List.filled(TaskLifecycleState.terminal.length, '?').join(',')})',
      whereArgs: [title, ...TaskLifecycleState.terminal],
      orderBy: 'scheduledAt DESC',
      limit: 1,
    );
    if (nonTerminalRows.isNotEmpty) {
      return TaskAssignment.fromJson(nonTerminalRows.first);
    }

    final rows = await db.query(
      _taskAssignmentsTable,
      where: 'canonicalTitle = ?',
      whereArgs: [title],
      orderBy: 'scheduledAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TaskAssignment.fromJson(rows.first);
  }

  /// The barrier currently running, if any — the one row in `accepted`.
  /// SOS opened without a task attached to it (the home-screen menu,
  /// self-challenge, a coach nudge) uses this to find out whether a barrier
  /// is actually mid-countdown and needs suspending rather than resetting.
  Future<TaskAssignment?> loadActiveAcceptedBarrier() async {
    final db = await database;
    final rows = await db.query(
      _taskAssignmentsTable,
      where: 'state = ?',
      whereArgs: [TaskLifecycleState.accepted],
      orderBy: 'barrierStartedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TaskAssignment.fromJson(rows.first);
  }

  Future<List<TaskAssignment>> loadTaskAssignmentsForDay(DateTime day) async {
    final db = await database;
    final key = _planDateKey(day);
    final rows = await db.query(
      _taskAssignmentsTable,
      where: 'planDate = ?',
      whereArgs: [key],
      orderBy: 'scheduledAt ASC',
    );
    return rows.map(TaskAssignment.fromJson).toList();
  }

  /// Tasks still waiting on something — not yet delivered, or delivered and
  /// unanswered. Used to reconcile after the process was killed.
  Future<List<TaskAssignment>> loadOpenTaskAssignments() async {
    final db = await database;
    final rows = await db.query(
      _taskAssignmentsTable,
      where: 'state NOT IN (?, ?, ?, ?, ?, ?)',
      whereArgs: [
        TaskLifecycleState.succeeded,
        TaskLifecycleState.failedDeclined,
        TaskLifecycleState.failedSmoked,
        TaskLifecycleState.failedMissed,
        TaskLifecycleState.expired,
        TaskLifecycleState.barrierUnknown,
      ],
      orderBy: 'scheduledAt ASC',
    );
    return rows.map(TaskAssignment.fromJson).toList();
  }

  /// Closes out any `accepted` barrier whose confirmation window has been
  /// open longer than [NotificationService.barrierResolutionDeadline] —
  /// both the first confirmation prompt and its later reminder went
  /// unanswered, so asking now would draw on a moment the user can no
  /// longer accurately recall. Closed as [TaskLifecycleState.barrierUnknown]
  /// rather than a real outcome, and — same as `expired` — never reported
  /// to the learning engine (`outcomeFor` returns null for it).
  ///
  /// Called on every app open; a no-op most of the time since it only ever
  /// matches a barrier the user genuinely never responded to.
  Future<List<TaskAssignment>> closeStaleAcceptedBarriers({
    required Duration deadline,
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).subtract(deadline);
    final db = await database;
    final rows = await db.query(
      _taskAssignmentsTable,
      where: 'state = ?',
      whereArgs: [TaskLifecycleState.accepted],
    );
    final stale = rows
        .map(TaskAssignment.fromJson)
        .where(
          // barrierEndsAt is when the confirmation prompt actually fired
          // (barrierStartedAt + the barrier's own duration) — the deadline
          // counts from there, not from acceptance, so it lines up with
          // scheduleBarrierResolutionReminder's delay + deadline math.
          (task) => (task.barrierEndsAt ?? task.scheduledAt).isBefore(cutoff),
        )
        .toList();
    for (final task in stale) {
      await transitionTaskAssignment(
        id: task.id,
        state: TaskLifecycleState.barrierUnknown,
      );
    }
    return stale;
  }

  /// Closes out any `sosActive` task the user never came back to resume.
  ///
  /// `sosActive`'s only exits are the two manual resume choices
  /// `CravingSosPage` offers ("resume in N minutes" / "resume the running
  /// barrier") — there is no automatic one, so a session abandoned by
  /// closing the app, backgrounding it and never returning, or the page
  /// itself crashing, previously sat in `sosActive` forever: never
  /// resolved, never counted against the daily plan as finished, silently
  /// occupying a slot in the daily quota indefinitely. Closed as
  /// [TaskLifecycleState.sosAbandoned], kept out of the learning signal
  /// the same way `expired`/`barrierUnknown` are.
  ///
  /// Called on every app open, alongside [closeStaleAcceptedBarriers]; a
  /// no-op most of the time since it only ever matches a session the user
  /// genuinely never returned to.
  Future<List<TaskAssignment>> closeStaleAbandonedSosSessions({
    required Duration deadline,
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now()).subtract(deadline);
    final db = await database;
    final rows = await db.query(
      _taskAssignmentsTable,
      where: 'state = ?',
      whereArgs: [TaskLifecycleState.sosActive],
    );
    final stale = rows
        .map(TaskAssignment.fromJson)
        .where(
          (task) => (task.sosStartedAt ?? task.scheduledAt).isBefore(cutoff),
        )
        .toList();
    for (final task in stale) {
      await transitionTaskAssignment(
        id: task.id,
        state: TaskLifecycleState.sosAbandoned,
      );
    }
    return stale;
  }

  static String _planDateKey(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }

  /// Moves a task to [state] and, when that state is terminal, reports it to
  /// the learning engine exactly once.
  ///
  /// Going through here rather than letting callers write outcomes directly
  /// is what stops a task from being counted twice — a notification answered
  /// just as the watchdog fires used to be able to record both an answer and
  /// a miss for the same task.
  ///
  /// The read (loadTaskAssignment), the state-machine decision, the write
  /// (saveTaskAssignment), and the outcome report (recordAdaptiveTaskOutcome)
  /// all run inside one transaction now — previously each ran against the
  /// database independently, so the foreground app, a notification action in
  /// the background isolate, and the native watchdog's drain could all read
  /// the same row before any of them wrote it back, and whichever write
  /// landed last silently discarded the others' transitions. Wrapping the
  /// whole read-modify-write in a transaction gives SQLite's own write
  /// serialization the job of ordering concurrent callers instead of leaving
  /// it to whichever one happened to finish last. It also closes the second
  /// gap this used to have: the terminal-state write and the outcome report
  /// used to be two separate, unguarded operations, so a process kill
  /// between them left the task stuck terminal (the isTerminal guard above
  /// refuses to touch it again) with its outcome permanently lost — now
  /// either both happen or neither does.
  Future<TaskAssignment?> transitionTaskAssignment({
    required String id,
    required String state,
    DateTime? at,
    int? postponeMinutes,
    int? sosMinutes,
    String? gateReason,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final existing = await loadTaskAssignment(id, executor: txn);
      if (existing == null ||
          existing.isTerminal ||
          !TaskLifecycleState.canTransition(existing.state, state)) {
        return existing;
      }

      final now = at ?? DateTime.now();
      var updated = existing.copyWith(
        state: state,
        respondedAt: TaskLifecycleState.terminal.contains(state) ? now : null,
      );

      if (state == TaskLifecycleState.delivered &&
          existing.deliveredAt == null) {
        updated = updated.copyWith(deliveredAt: now);
      }
      if (state == TaskLifecycleState.retrying) {
        updated = updated.copyWith(attemptCount: existing.attemptCount + 1);
      }
      if (state == TaskLifecycleState.postponed && postponeMinutes != null) {
        updated = updated.copyWith(
          postponeCount: existing.postponeCount + 1,
          totalPostponedMinutes:
              existing.totalPostponedMinutes + postponeMinutes,
          scheduledAt: now.add(Duration(minutes: postponeMinutes)),
        );
      }
      if (state == TaskLifecycleState.sosActive) {
        updated = updated.copyWith(
          sosCount: existing.sosCount + 1,
          sosStartedAt: now,
        );
      }
      if (sosMinutes != null) {
        updated = updated.copyWith(
          sosTotalMinutes: existing.sosTotalMinutes + sosMinutes,
        );
      }
      if (state == TaskLifecycleState.pendingDelivery) {
        updated = updated.copyWith(
          gateDeferCount: existing.gateDeferCount + 1,
          gateReason: gateReason,
        );
      }
      // Only stamped on the *first* arrival at `accepted` — resuming into it
      // from `sosActive` (the barrier-was-running case, see
      // TaskLifecycleState._allowedTransitions) must leave these alone so the
      // barrier resumes at whatever time was actually left on it, not a fresh
      // full window starting now.
      if (state == TaskLifecycleState.accepted &&
          existing.state != TaskLifecycleState.sosActive) {
        updated = updated.copyWith(
          barrierStartedAt: now,
          barrierEndsAt: now.add(Duration(minutes: existing.durationMinutes)),
        );
      }

      await saveTaskAssignment(updated, executor: txn);

      final outcome = updated.outcome;
      if (outcome != null) {
        await recordAdaptiveTaskOutcome(
          taskTitle: updated.canonicalTitle,
          outcome: outcome,
          plannedDurationMinutes: updated.durationMinutes,
          scheduledAt: updated.barrierStartedAt ?? updated.scheduledAt,
          respondedAt: now,
          executor: txn,
        );
      }
      return updated;
    });
  }

  /// How today's logged cigarette count compares to what the user's survey
  /// answers imply, for the pre-sleep routine's discrepancy question.
  Future<SmokingCountDiscrepancy> evaluateTodaySmokingDiscrepancy({
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final loggedToday = await loadSmokingEventsForDay(today);
    final windowInput = await loadSmokingWindowInput();
    return _smokingCountDiscrepancyEngine.evaluate(
      loggedCount: loggedToday.length,
      declaredDailyAverage: windowInput.dailyCigarettes,
    );
  }

  /// Everything the pre-sleep routine's final "today's progress" step shows,
  /// gathered in one place so the widget doesn't have to know which tables
  /// or engines each figure comes from.
  Future<DailyProgressReport> buildDailyProgressReport({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final results = await Future.wait([
      loadReductionProgress(now: today),
      taskSuccessRateSince(today.subtract(const Duration(days: 7))),
      loadCurrentBarrierMinutes(now: today),
      loadLatestBreathRecord(),
      loadBehaviorDashboard(),
      loadLatestCoughTestRecord(),
      loadSmokingEventsForDay(today),
    ]);

    final breathRecord = results[3] as SurveyRecord?;
    final dashboard = results[4] as BehaviorDashboard;
    final smokedToday = results[6] as List<SmokingEvent>;

    return DailyProgressReport(
      reductionProgress: results[0] as ReductionProgress,
      taskSuccessRateLast7Days: results[1] as double,
      currentBarrierMinutes: results[2] as int,
      lastBreathTestAt: breathRecord?.completedAt,
      breathTrend: dashboard.breathTrendLast3,
      todaySmokedCount: smokedToday.length,
      latestCoughTest: results[5] as CoughTestRecord?,
    );
  }

  Future<void> saveSmokingEvent(SmokingEvent event) async {
    final db = await database;
    await db.insert(
      _smokingEventsTable,
      event.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await markBehaviorDirty();
  }

  /// Convenience wrapper for the optional real-time quick-log button.
  /// Returns the created event's id so an accidental tap can be undone via
  /// [deleteSmokingEvent].
  /// Records a cigarette. [timestamp] lets the native quick-log button replay
  /// presses it queued while no Flutter engine was alive, so the moment kept
  /// is when the user actually pressed rather than when the app got round to
  /// reading it.
  Future<String> logSmokingNow({
    DateTime? timestamp,
    String? placeId,
    String? trigger,
  }) async {
    final at = timestamp ?? DateTime.now();
    final id = 'smoke_${at.microsecondsSinceEpoch}';
    await saveSmokingEvent(
      SmokingEvent(
        id: id,
        timestamp: at,
        source: 'quick_log',
        approximate: false,
        placeId: placeId,
        trigger: trigger,
      ),
    );
    return id;
  }

  Future<void> updateSmokingEventTrigger({
    required String id,
    required String trigger,
  }) async {
    if (!failureTriggerReasons.contains(trigger)) return;
    final db = await database;
    await db.update(
      _smokingEventsTable,
      {'trigger': trigger},
      where: 'id = ?',
      whereArgs: [id],
    );
    await markBehaviorDirty();
  }

  Future<List<SmokingEvent>> loadSmokingEventsWithoutTrigger() async {
    final db = await database;
    final rows = await db.query(
      _smokingEventsTable,
      where: 'trigger IS NULL AND source = ?',
      whereArgs: ['quick_log'],
      orderBy: 'timestamp ASC',
    );
    return rows.map((row) => SmokingEvent.fromJson(row)).toList();
  }

  Future<void> deleteSmokingEvent(String id) async {
    final db = await database;
    await db.delete(_smokingEventsTable, where: 'id = ?', whereArgs: [id]);
    await markBehaviorDirty();
  }

  /// Convenience wrapper for the bedtime daily-recall check-in: logs one
  /// recalled event per selected hour on the given day.
  Future<void> logRecalledSmokingHours({
    required DateTime day,
    required List<int> hours,
  }) async {
    for (final hour in hours) {
      final timestamp = DateTime(
        day.year,
        day.month,
        day.day,
        hour.clamp(0, 23),
      );
      await saveSmokingEvent(
        SmokingEvent(
          id: 'smoke_recall_${timestamp.millisecondsSinceEpoch}_$hour',
          timestamp: timestamp,
          source: 'daily_recall',
          approximate: true,
        ),
      );
    }
  }

  Future<List<SmokingEvent>> loadSmokingEvents({
    DateTime? since,
    int limit = 500,
  }) async {
    final db = await database;
    final rows = await db.query(
      _smokingEventsTable,
      where: since == null ? null : 'timestamp >= ?',
      whereArgs: since == null ? null : [since.toIso8601String()],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows
        .map((row) => SmokingEvent.fromJson(row))
        .toList()
        .reversed
        .toList();
  }

  Future<List<SmokingEvent>> loadSmokingEventsForDay(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return database.then((db) async {
      final rows = await db.query(
        _smokingEventsTable,
        where: 'timestamp >= ? AND timestamp < ?',
        whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
        orderBy: 'timestamp ASC',
      );
      return rows.map((row) => SmokingEvent.fromJson(row)).toList();
    });
  }

  Future<void> saveMentorMessage(MentorMessage message) async {
    final db = await database;
    await db.insert(
      _mentorMessagesTable,
      message.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MentorMessage>> loadMentorMessages({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      _mentorMessagesTable,
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map((row) => MentorMessage.fromJson(row)).toList();
  }

  Future<MentorMessage?> loadLatestMentorMessage() async {
    final messages = await loadMentorMessages(limit: 1);
    return messages.isEmpty ? null : messages.first;
  }

  Future<void> markMentorMessageRead(String id) async {
    final db = await database;
    await db.update(
      _mentorMessagesTable,
      {'read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> replyToMentorMessage(String id, String reply) async {
    final db = await database;
    await db.update(
      _mentorMessagesTable,
      {'read': 1, 'userReply': reply},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Attaches the "Ne tür yardım istersin?" follow-up question to a message
  /// the user just replied "Zorlanıyorum" to. Kept separate from
  /// [replyToMentorMessage] so that function stays reply-agnostic and
  /// callers explicitly opt into this branchier, struggling-only behavior.
  Future<void> attachMentorFollowUpQuestion(String messageId) async {
    final db = await database;
    await db.update(
      _mentorMessagesTable,
      {
        'followUpQuestion': MentorMessageCodes.followUpStrugglingQuestion,
        'followUpQuickReplies': [
          MentorMessageCodes.quickReplyReduceTasks,
          MentorMessageCodes.quickReplyEaseBarrier,
          MentorMessageCodes.quickReplyJustTalking,
        ].join('|'),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Applies the user's answer to the "Zorlanıyorum" follow-up question.
  /// [choice] is one of MentorMessageCodes.{quickReplyReduceTasks,
  /// quickReplyEaseBarrier,quickReplyJustTalking}.
  ///
  /// Both relief settings start tomorrow, never today — the daily adaptive
  /// plan may already be cached and its tasks already delivered for today
  /// (see buildAdaptiveNoSmokePlan's daily cache), so easing today's plan
  /// retroactively would either be a no-op or collide with tasks the user
  /// already saw. Starting tomorrow needs no cache invalidation at all.
  Future<void> applyMentorFollowUpChoice(
    String messageId,
    String choice,
  ) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    switch (choice) {
      case MentorMessageCodes.quickReplyReduceTasks:
        await saveSetting(
          _mentorTaskReliefUntilKey,
          tomorrow.add(const Duration(days: 7)).toIso8601String(),
        );
        break;
      case MentorMessageCodes.quickReplyEaseBarrier:
        await saveSetting(
          _mentorBarrierReliefDateKey,
          tomorrow.toIso8601String(),
        );
        break;
      case MentorMessageCodes.quickReplyJustTalking:
        break;
    }

    final db = await database;
    await db.update(
      _mentorMessagesTable,
      {'followUpReply': choice},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Buckets recent [SmokingEvent]s into this-week / last-week day-part
  /// counts (morning/afternoon/evening/night), for [MentorMessageBuilder]'s
  /// week-over-week callback.
  /// [startOfThisWeek] on the result is the boundary
  /// [MentorMessageBuilder.buildHistoricalNote] needs (via its own
  /// `startOfThisWeek`/`now` parameters) to tell "zero events this week
  /// because the user improved" apart from "zero events because this day
  /// part hasn't happened yet this week" — see that method's doc comment.
  Future<
    ({
      Map<String, int> lastWeek,
      Map<String, int> thisWeek,
      DateTime startOfThisWeek,
    })
  >
  _loadSmokingDayPartComparison({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final startOfThisWeek = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));

    final events = await loadSmokingEvents(since: startOfLastWeek);
    final lastWeekCounts = <String, int>{};
    final thisWeekCounts = <String, int>{};

    for (final event in events) {
      final dayPart = MentorMessageBuilder.dayPartForHour(event.timestamp.hour);
      if (event.timestamp.isBefore(startOfThisWeek)) {
        lastWeekCounts[dayPart] = (lastWeekCounts[dayPart] ?? 0) + 1;
      } else {
        thisWeekCounts[dayPart] = (thisWeekCounts[dayPart] ?? 0) + 1;
      }
    }

    return (
      lastWeek: lastWeekCounts,
      thisWeek: thisWeekCounts,
      startOfThisWeek: startOfThisWeek,
    );
  }

  /// Generates and persists today's mentor message from the app's existing
  /// coaching signals (behavior dashboard risk/hours, recent task success
  /// rate, week-over-week smoking-event pattern). Safe to call repeatedly —
  /// callers are expected to only surface this once per day (see
  /// HomePage's daily cadence).
  Future<MentorMessage> generateDailyMentorMessage({DateTime? now}) async {
    final dashboard = await loadBehaviorDashboard();
    final taskOutcomeSummary = await loadTaskOutcomeSummary();
    final successCount = taskOutcomeSummary['recentSuccessCount'] ?? 0;
    final failureCount = taskOutcomeSummary['recentFailureCount'] ?? 0;
    final totalOutcomes = successCount + failureCount;
    final recentSuccessRate = totalOutcomes == 0
        ? 0.5
        : successCount / totalOutcomes;

    final dayPartComparison = await _loadSmokingDayPartComparison(now: now);
    final historicalNote = _mentorMessageBuilder.buildHistoricalNote(
      lastWeekDayPartCounts: dayPartComparison.lastWeek,
      thisWeekDayPartCounts: dayPartComparison.thisWeek,
      startOfThisWeek: dayPartComparison.startOfThisWeek,
      now: now ?? DateTime.now(),
    );

    final message = _mentorMessageBuilder.buildDailyMessage(
      riskScore: dashboard.riskScore,
      recentSuccessRate: recentSuccessRate,
      riskyHours: dashboard.riskyHours,
      historicalNote: historicalNote,
      breathTrend: dashboard.breathTrendLast3,
      now: now,
    );
    await saveMentorMessage(message);
    return message;
  }

  Future<MentorMessage> generateWeeklyMentorMessage({DateTime? now}) async {
    final dashboard = await loadBehaviorDashboard();
    final taskOutcomeSummary = await loadTaskOutcomeSummary();
    final successCount = taskOutcomeSummary['recentSuccessCount'] ?? 0;
    final failureCount = taskOutcomeSummary['recentFailureCount'] ?? 0;
    final totalOutcomes = successCount + failureCount;
    final recentSuccessRate = totalOutcomes == 0
        ? 0.5
        : successCount / totalOutcomes;

    final dayPartComparison = await _loadSmokingDayPartComparison(now: now);
    final historicalNote = _mentorMessageBuilder.buildHistoricalNote(
      lastWeekDayPartCounts: dayPartComparison.lastWeek,
      thisWeekDayPartCounts: dayPartComparison.thisWeek,
      startOfThisWeek: dayPartComparison.startOfThisWeek,
      now: now ?? DateTime.now(),
    );

    final message = _mentorMessageBuilder.buildWeeklyMessage(
      weeklyRiskScore: dashboard.weeklySurveyRiskScore,
      weeklyRiskLevel: dashboard.weeklySurveyRiskLevel,
      recentSuccessRate: recentSuccessRate,
      completedTasksThisWeek: successCount,
      historicalNote: historicalNote,
      now: now,
    );
    await saveMentorMessage(message);
    return message;
  }

  Future<Map<String, dynamic>> loadLatestTaskTimingContext() async {
    final relevantSurveyRecords = await _loadRelevantSurveyRecords();
    final contextMap = await loadSurveyContextByRecordId();
    final mergedProfileContext = _buildMergedProfileContext(
      surveyRecords: relevantSurveyRecords,
      contextMap: contextMap,
    );
    final sensorEvents = await loadRecentSensorUsage(limit: 1);
    final latestSensor = sensorEvents.isEmpty ? null : sensorEvents.last;
    final now = DateTime.now();

    final sleepTime = mergedProfileContext['sleepTime'] as String?;
    final wakeTime = mergedProfileContext['wakeTime'] as String?;
    final workStartRaw = mergedProfileContext['workStart'] as String?;
    final workEndRaw = mergedProfileContext['workEnd'] as String?;
    final inferredWork = _inferWorkWindow(
      wakeTime: wakeTime,
      workStart: workStartRaw,
      workEnd: workEndRaw,
    );
    final workStart = inferredWork['workStart'];
    final workEnd = inferredWork['workEnd'];
    final workplaceSmokingRule =
        mergedProfileContext['workplaceSmokingRule'] as String?;
    final workingDays =
        (mergedProfileContext['workingDays'] as List<String>? ??
                const <String>[])
            .toSet();
    final breakWindows =
        (mergedProfileContext['breakWindows'] as List<Map<String, String>>? ??
        const <Map<String, String>>[]);
    final weekendSmokingPattern = mergedProfileContext['weekendSmokingPattern']
        ?.toString();

    final isPhoneBusy =
        latestSensor != null &&
        (latestSensor.appUsageMinutes >= 10 ||
            latestSensor.screenUnlockCount >= 8);
    final isLongIdle =
        latestSensor != null &&
        latestSensor.idleMinutes >= 20 &&
        latestSensor.appUsageMinutes <= 3;
    final isDriving =
        latestSensor != null &&
        (latestSensor.activityState == 'driving' ||
            (latestSensor.accelerometerMagnitude > 1.1 &&
                latestSensor.gyroscopeMagnitude > 0.8 &&
                latestSensor.screenUnlockCount <= 2));

    final isSleepWindow = _isWithinWindow(
      now: now,
      startTime: sleepTime,
      endTime: wakeTime,
    );
    final todayKey = _weekdayKey(now.weekday);
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final effectiveWorkingDays = workingDays.isEmpty
        ? <String>{'Mon', 'Tue', 'Wed', 'Thu', 'Fri'}
        : workingDays;
    final isTodayWorkingDay = effectiveWorkingDays.isEmpty
        ? !isWeekend
        : effectiveWorkingDays.contains(todayKey);
    final rawWorkWindow = _isWithinWindow(
      now: now,
      startTime: workStart,
      endTime: workEnd,
    );
    final isWorkWindow = isTodayWorkingDay && rawWorkWindow;
    final isBreakWindow = breakWindows.any(
      (window) => _isWithinWindow(
        now: now,
        startTime: window['start'],
        endTime: window['end'],
      ),
    );
    final minutesUntilNextBreak = _minutesUntilNextBreak(
      now: now,
      breakWindows: breakWindows,
    );

    return {
      'sleepTime': sleepTime,
      'wakeTime': wakeTime,
      'workStart': workStart,
      'workEnd': workEnd,
      'workplaceSmokingRule': workplaceSmokingRule,
      'workingDays': effectiveWorkingDays.toList(),
      'breakWindows': breakWindows,
      'weekendSmokingPattern': weekendSmokingPattern,
      'isPhoneBusy': isPhoneBusy,
      'isLongIdle': isLongIdle,
      'isDriving': isDriving,
      'isSleepWindow': isSleepWindow,
      'isWorkWindow': isWorkWindow,
      'isTodayWorkingDay': isTodayWorkingDay,
      'isBreakWindow': isBreakWindow,
      'minutesUntilNextBreak': minutesUntilNextBreak,
      'isWeekend': isWeekend,
      'isActiveDuringSleep': isSleepWindow && isPhoneBusy,
      'minutesUntilWake': _minutesUntilWindowEnds(now: now, endTime: wakeTime),
      'minutesUntilWorkEnd': _minutesUntilWindowEnds(
        now: now,
        endTime: workEnd,
      ),
      'idleMinutes': latestSensor?.idleMinutes ?? 0,
      'appUsageMinutes': latestSensor?.appUsageMinutes ?? 0,
      'screenUnlockCount': latestSensor?.screenUnlockCount ?? 0,
    };
  }

  Future<SurveyRecord?> loadLatestBreathRecord() async {
    final records = await loadSurveyHistory();
    return records.reversed
        .where((record) => record.type == 'breath_test')
        .firstOrNull;
  }

  Future<List<SurveyRecord>> _loadRelevantSurveyRecords() async {
    final records = await loadSurveyHistory();
    return records
        .where((record) => _surveyTypes.contains(record.type))
        .toList();
  }

  Future<BehaviorDashboard> loadBehaviorDashboard() async {
    final dirty = await isBehaviorDirty();
    if (!dirty) {
      final snapshot = await loadLatestBehaviorSnapshot();
      if (snapshot != null) {
        return snapshot;
      }
    }

    final existingSnapshot = await loadLatestBehaviorSnapshot();

    final records = await loadSurveyHistory();
    final triggerMap = await loadTriggerMapByRecordId();
    final contextMap = await loadSurveyContextByRecordId();
    final sensorEvents = await loadRecentSensorUsage();
    final taskHistory = await loadTaskHistory();

    final surveyRecords =
        records.where((record) => _surveyTypes.contains(record.type)).toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    final breathRecords =
        records.where((record) => record.type == 'breath_test').toList()
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    final triggerScores = _behaviorEngine
        .calculateTriggerScoresFromSurveyRecords(surveyRecords, triggerMap);
    final failureTriggerBoost = await loadFailureTriggerScoreBoost();
    for (final entry in failureTriggerBoost.entries) {
      triggerScores[entry.key] = (triggerScores[entry.key] ?? 0) + entry.value;
    }
    final riskyTriggers = _behaviorEngine.calculateRiskyTriggers(triggerScores);
    final recentSmokingEvents = await loadSmokingEvents(
      since: DateTime.now().subtract(const Duration(days: 28)),
    );

    final repeatedSmokingPlaceIds = _behaviorEngine.findRepeatedSmokingPlaceIds(
      recentSmokingEvents.map((event) => event.placeId).toList(),
    );
    // Native geofences persist ENTER events even while Flutter is closed.
    // Consume those events here as an additional, bounded signal: an arrival
    // at a place where smoking has repeatedly happened keeps the daily plan
    // location-aware after the app is reopened, without creating one task per
    // geofence event.
    final locationVisitCutoff = DateTime.now().subtract(
      const Duration(days: 28),
    );
    final recentRiskPlaceVisits = (await loadLocationVisitEvents(limit: 200))
        .where(
          (event) =>
              event.transitionType == 'enter' &&
              event.createdAt.isAfter(locationVisitCutoff) &&
              repeatedSmokingPlaceIds.contains(event.placeId),
        )
        .length;

    final riskyHours = _behaviorEngine.calculateRiskyHoursFromTimestamps(
      surveyTimes: surveyRecords.map((record) => record.completedAt).toList(),
      appUsageTimes: sensorEvents
          .where(
            (event) =>
                event.appUsageMinutes >= 5 || event.screenUnlockCount >= 6,
          )
          .map((event) => event.createdAt)
          .toList(),
      taskFailureTimes: taskHistory
          .where((task) => !task.completed)
          .map((task) => task.date)
          .toList(),
      breathTestTimes: breathRecords
          .map((record) => record.completedAt)
          .toList(),
      // The one direct signal in this list. Until now risky hours were
      // inferred entirely from proxies — when surveys happened to be filled
      // in, when the phone was busy, when tasks failed — while the moments
      // the user had actually reported smoking sat unused in the database.
      // That left the day's tasks aimed at the app's usage pattern rather
      // than the habit they exist to interrupt.
      smokingTimes: recentSmokingEvents
          .map((event) => event.timestamp)
          .toList(),
    );

    final smokingTrend = _behaviorEngine.calculateSmokingTrendFromRecords(
      records,
    );
    final breathTrend = _behaviorEngine.calculateBreathTrendFromRecords(
      records,
    );
    final consecutiveTrend = _behaviorEngine
        .evaluateConsecutiveSmokingTrendFromRecords(records);
    final baseRisk = records.isEmpty ? 40 : records.last.riskScore;

    final latestSurvey = surveyRecords.isNotEmpty ? surveyRecords.last : null;
    final mergedProfileContext = _buildMergedProfileContext(
      surveyRecords: surveyRecords,
      contextMap: contextMap,
    );
    final latestContext = mergedProfileContext;
    final effectiveSleepWindow = await resolveEffectiveSleepWindow(
      fallbackSleepTime: latestContext['sleepTime'] as String?,
      fallbackWakeTime: latestContext['wakeTime'] as String?,
    );
    final profileAdjustment = _behaviorEngine.calculateProfileRiskAdjustment(
      profession: latestContext['profession'] as String?,
      sleepTime: effectiveSleepWindow.sleepTime,
      wakeTime: effectiveSleepWindow.wakeTime,
      healthConditions:
          (latestContext['healthConditions'] as List<String>?) ??
          const <String>[],
      packsPerDay: latestSurvey?.packsPerDay ?? '1 paketten az',
      consecutiveHabit: latestSurvey?.consecutiveSmokingHabit,
      consecutiveCount: latestSurvey?.consecutiveSmokingCount,
      hasBreathTests: breathRecords.isNotEmpty,
    );

    final learnedWeights = _behaviorEngine.learnDynamicWeightsFromRecentHistory(
      taskHistory: taskHistory,
      breathRecords: breathRecords,
      surveyRecords: surveyRecords,
    );

    final dynamicCoreRisk = _behaviorEngine.calculateDynamicRiskScore(
      baseRiskScore: baseRisk,
      smokingTrend: smokingTrend,
      breathTrend: breathTrend,
      consecutiveTrend: consecutiveTrend,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      learnedWeights: learnedWeights,
    );

    final personalizedAdjustment = _behaviorEngine
        .calculatePersonalizedRiskAdjustment(
          surveyRecords: surveyRecords,
          breathRecords: breathRecords,
          latestContext: latestContext,
          sensorEvents: sensorEvents,
        );

    final taskAdjustment = _taskOutcomeRiskAdjustment(taskHistory);
    final taskPerformanceRisk = _taskPerformanceRiskScore(taskHistory);

    final breathResults = await loadBreathTestResults(limit: 50);
    final latestBreathScore = breathResults.isNotEmpty
        ? breathResults.last.breathScore
        : _legacyBreathScoreEstimate(breathRecords);
    final breathTrendAnalysis = _breathTestEngine.analyzeTrend(breathResults);

    final behaviorRisk =
        (dynamicCoreRisk + personalizedAdjustment + profileAdjustment)
            .clamp(0, 100)
            .toDouble();

    final weeklyPayload =
        (latestContext['weeklyPayload'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final weeklyEvaluation = _behaviorEngine.evaluateWeeklySurveyRisk(
      weeklyPayload,
      profileContext: {
        ...latestContext,
        'packsPerDay': latestSurvey?.packsPerDay,
        'riskyTriggers': riskyTriggers,
      },
    );
    final weeklyRiskScore =
        (weeklyEvaluation['weeklyRiskScore'] as num?)?.toInt() ?? 40;
    final weeklyRiskLevel =
        weeklyEvaluation['weeklyRiskLevel']?.toString() ?? 'medium';
    final respiratoryBurden =
        (weeklyEvaluation['respiratoryBurden'] as num?)?.toInt() ?? 25;
    final respiratoryState =
        weeklyEvaluation['respiratoryState']?.toString() ?? 'stable';
    final weeklyTopRiskDrivers =
        (weeklyEvaluation['topRiskDrivers'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList();

    // With no task history yet, the 15% task-performance slot has nothing
    // real to measure — it was falling back to a flat 55 "guess". Rather
    // than let that guess distort the score, its weight is folded into
    // survey/behavior (evenly) instead. Breath weight is deliberately left
    // untouched either way — it always has a real reading by this point
    // (see BreathTestService.processBreathTest).
    final hasTaskHistory = taskHistory.isNotEmpty;
    final surveyWeight = hasTaskHistory ? 0.40 : 0.475;
    final behaviorWeight = hasTaskHistory ? 0.25 : 0.325;
    final taskWeight = hasTaskHistory ? 0.15 : 0.0;

    var dynamicRisk = _breathTestEngine.calculateFinalRisk(
      surveyRisk: weeklyRiskScore.toDouble(),
      behaviorRisk: behaviorRisk,
      taskPerformanceRisk: taskPerformanceRisk.toDouble(),
      breathScore: latestBreathScore,
      trendAdjustment: breathTrendAnalysis.riskAdjustment,
      surveyWeight: surveyWeight,
      behaviorWeight: behaviorWeight,
      taskWeight: taskWeight,
    );

    // Weekly self-report extremes still add bounded safety adjustments.
    final lapseCount = (weeklyPayload['lapseCount'] as num?)?.toInt() ?? 0;
    final cravingMax = (weeklyPayload['cravingMax'] as num?)?.toInt() ?? 0;
    final selfEfficacy = (weeklyPayload['selfEfficacy'] as num?)?.toInt() ?? 0;
    final completionRate =
        ((weeklyPayload['task']
                    as Map<String, dynamic>?)?['weeklyCompletionRate']
                as num?)
            ?.toInt() ??
        0;
    if (lapseCount >= 3 && cravingMax >= 8) {
      dynamicRisk = (dynamicRisk + 12).clamp(0, 100).toInt();
    }
    if (lapseCount == 0 && selfEfficacy >= 8 && completionRate >= 8) {
      dynamicRisk = (dynamicRisk - 8).clamp(0, 100).toInt();
    }

    final isFirstProfile =
        existingSnapshot == null &&
        surveyRecords.any((record) => record.type == 'initial') &&
        breathRecords.isNotEmpty;

    final taskRates = _behaviorEngine.calculateTaskSuccessRateMap(taskHistory);
    final taskOutcomeSummary = await loadTaskOutcomeSummary();
    final recentSuccessCount = taskOutcomeSummary['recentSuccessCount'] ?? 0;
    final recentFailureCount = taskOutcomeSummary['recentFailureCount'] ?? 0;
    final adaptiveEvents = await loadRecentAdaptiveTaskEvents();
    final barrierOutcomeSummary = _summarizeDurationBarrierOutcomes(
      adaptiveEvents,
      taskHistory,
    );
    final recentBarrierSuccessCount =
        barrierOutcomeSummary['recentSuccessCount'] ?? 0;
    final recentBarrierFailureCount =
        barrierOutcomeSummary['recentFailureCount'] ?? 0;
    final totalBarrierOutcomes =
        (barrierOutcomeSummary['successCount'] ?? 0) +
        (barrierOutcomeSummary['failureCount'] ?? 0);
    final barrierSuccessRate = totalBarrierOutcomes == 0
        ? 0.5
        : (barrierOutcomeSummary['successCount'] ?? 0) / totalBarrierOutcomes;
    final recentTaskCompletionRate = _recentTaskCompletionRate(taskHistory);
    final dailyBarrierScore =
        (0.6 * barrierSuccessRate) + (0.4 * recentTaskCompletionRate);
    final barrierPreferenceRaw =
        (await loadSetting('duration_barrier_preference')) ?? 'neutral';
    final barrierFrequencyRaw =
        (await loadSetting('duration_barrier_frequency_preference')) ?? 'orta';
    final barrierEnabled =
        ((await loadSetting('duration_barrier_enabled')) ?? '1') == '1';

    if (recentBarrierFailureCount >= recentBarrierSuccessCount + 2) {
      dynamicRisk = (dynamicRisk + 6).clamp(0, 100).toInt();
    } else if (recentBarrierSuccessCount >= recentBarrierFailureCount + 2) {
      dynamicRisk = (dynamicRisk - 4).clamp(0, 100).toInt();
    }

    // Phase 11: step count and heart rate feeding the actual risk score,
    // not just reports/UI. Both read from local data already collected by
    // the existing native probes (Phase 7/9) — no new I/O here. Bounded
    // and small, same scale as the other adjustments above.
    final stepSamples = await loadStepCounterSamples(
      since: DateTime.now().subtract(const Duration(days: 8)),
    );
    final dailySteps = _stepTrendEngine.computeDailySteps(stepSamples);
    final sedentaryToday = _stepTrendEngine.isMostRecentDaySedentary(
      dailySteps,
    );
    if (sedentaryToday) {
      dynamicRisk = (dynamicRisk + 3).clamp(0, 100).toInt();
    }

    final wearableRiskAdjustment = await _loadCachedWearableRiskAdjustment();
    if (wearableRiskAdjustment > 0) {
      dynamicRisk = (dynamicRisk + wearableRiskAdjustment)
          .clamp(0, 100)
          .toInt();
    }

    // Cough test + snoring test signals — bounded adjustments applied the
    // same way as the barrier/steps/wearable ones above, rather than as new
    // inputs to _breathTestEngine.calculateFinalRisk (that blend has a
    // fixed 4-weight formula with one caller; adding a 5th input would mean
    // rebalancing all the weights). Snoring is wired into risk scoring for
    // the first time here — it previously only surfaced as a Settings-page
    // counter.
    final coughRecords = await loadCoughTestRecords(limit: 20);
    final coughAdjustment = _behaviorEngine.calculateCoughRiskAdjustment(
      recentRecords: coughRecords,
    );
    if (coughAdjustment != 0) {
      dynamicRisk = (dynamicRisk + coughAdjustment).clamp(0, 100).toInt();
    }

    final recentSnoreLikelyCount = await countRecentSnoreLikelyEvents(
      since: DateTime.now().subtract(const Duration(days: 7)),
    );
    final snoringAdjustment = _behaviorEngine.calculateSnoringRiskAdjustment(
      recentSnoreLikelyCount: recentSnoreLikelyCount,
    );
    if (snoringAdjustment != 0) {
      dynamicRisk = (dynamicRisk + snoringAdjustment).clamp(0, 100).toInt();
    }

    final startDate = surveyRecords.isNotEmpty
        ? surveyRecords.first.completedAt
        : DateTime.now();
    final adaptivePlan = _behaviorEngine.buildAdaptivePlan180(
      startDate: startDate,
      riskScore: dynamicRisk,
      breathTrend: breathTrend,
      smokingTrend: smokingTrend,
      riskyTriggers: riskyTriggers,
    );

    final baseAdaptiveTaskCount = recentFailureCount >= recentSuccessCount + 3
        ? 5
        : recentFailureCount > recentSuccessCount
        ? 4
        : recentSuccessCount >= recentFailureCount + 4
        ? 2
        : 3;
    // Repeated smoking at a learned place, or a recent geofence arrival at
    // that place, is a direct user-specific signal. Add at most one task so
    // location awareness never overwhelms the user.
    final hasRecentRiskLocationSignal =
        repeatedSmokingPlaceIds.isNotEmpty || recentRiskPlaceVisits > 0;
    final adaptiveTaskCount = hasRecentRiskLocationSignal
        ? min(5, baseAdaptiveTaskCount + 1)
        : baseAdaptiveTaskCount;
    final baseTasks = _behaviorEngine.generateAdaptiveTasks(
      riskScore: dynamicRisk,
      taskSuccessRates: taskRates,
      isFirstProfile: isFirstProfile,
      count: isFirstProfile ? 1 : adaptiveTaskCount,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      recentSmokingCount: recentSmokingEvents.length,
    );
    final progressiveCadenceTask = _behaviorEngine
        .generateProgressiveCadenceTask180(
          plan: adaptivePlan,
          recentSuccessCount: recentSuccessCount,
          recentFailureCount: recentFailureCount,
        );

    final todaysTasks = <String>{
      if (!isFirstProfile) progressiveCadenceTask,
      ...baseTasks,
    }.toList();

    final prediction = _predictionEngine.predictNextRisk(
      riskyHours: riskyHours,
      riskyTriggers: riskyTriggers,
      riskScore: dynamicRisk,
      sensorEvents: sensorEvents,
    );

    final orderedTasks = _mentorEngine.prioritizeTasks(
      tasks: todaysTasks,
      riskScore: dynamicRisk,
      primaryTrigger: riskyTriggers.isNotEmpty ? riskyTriggers.first : null,
      predictedWindow: prediction['nextRiskWindow']?.toString(),
    );

    final coachCommands = _mentorEngine.buildActionCommands(
      riskScore: dynamicRisk,
      breathTrend: breathTrend,
      smokingTrend: smokingTrend,
      consecutiveTrend: consecutiveTrend,
      weeklyRiskTarget: adaptivePlan.weeklyRiskTarget,
      riskyHours: riskyHours,
      predictedWindow: prediction['nextRiskWindow']?.toString(),
      predictedTrigger: prediction['nextRiskTrigger']?.toString(),
      weeklyPayload: weeklyPayload,
    );
    final optimizedCommands = _mentorEngine.optimizeActionCommands(
      commands: coachCommands,
      taskHistory: taskHistory,
      previousScores:
          existingSnapshot?.commandSuccessScores ?? const <String, double>{},
    );
    final optimizedCoachCommands =
        (optimizedCommands['commands'] as List<dynamic>)
            .map((item) => item.toString())
            .toList();
    final commandSuccessScores =
        (optimizedCommands['scores'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
    final commandCategoryScores =
        (optimizedCommands['categoryScores'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
    final commandMixMode = _resolveCommandMixMode(
      riskScore: dynamicRisk,
      weeklyRiskTarget: adaptivePlan.weeklyRiskTarget,
      recentSuccessCount: recentSuccessCount,
      recentFailureCount: recentFailureCount,
    );
    final adaptiveCommandCount = _resolveAdaptiveCommandCount(
      weeklyPayload: weeklyPayload,
      riskScore: dynamicRisk,
      recentSuccessCount: recentSuccessCount,
      recentFailureCount: recentFailureCount,
    );
    final balancedCoachCommands = _mentorEngine.rebalanceCommandMix(
      orderedCommands: optimizedCoachCommands,
      commandScores: commandSuccessScores,
      categoryScores: commandCategoryScores,
      mode: commandMixMode,
      maxCount: adaptiveCommandCount,
    );
    final riskExplanation = _behaviorEngine.buildRiskExplanation(
      baseRisk: baseRisk,
      dynamicCoreRisk: dynamicCoreRisk,
      personalizedAdjustment: personalizedAdjustment,
      profileAdjustment: profileAdjustment,
      taskAdjustment: taskAdjustment,
      finalRisk: dynamicRisk,
    );
    riskExplanation.add(
      'Yeni risk formulu: survey ${weeklyRiskScore.toStringAsFixed(0)} *${surveyWeight.toStringAsFixed(3)} + behavior ${behaviorRisk.toStringAsFixed(0)} *${behaviorWeight.toStringAsFixed(3)} + task ${taskPerformanceRisk.toString()} *${taskWeight.toStringAsFixed(3)} + breath ${latestBreathScore.toStringAsFixed(1)} *0.20',
    );
    riskExplanation.add(
      'Nefes trendi: ortalama ${breathTrendAnalysis.averageBreathScore.toStringAsFixed(1)}, son3 ${breathTrendAnalysis.trendLast3}, son7 ${breathTrendAnalysis.trendLast7}, trend duzeltme ${breathTrendAnalysis.riskAdjustment >= 0 ? '+' : ''}${breathTrendAnalysis.riskAdjustment}',
    );
    riskExplanation.add(
      'Haftalik anket skoru: $weeklyRiskScore ($weeklyRiskLevel)',
    );
    riskExplanation.add(
      'Respiratuar yuk: $respiratoryBurden / durum: $respiratoryState',
    );
    riskExplanation.add('Komut dengeleme modu: $commandMixMode');
    riskExplanation.add('Gunluk komut adedi: $adaptiveCommandCount');
    riskExplanation.add(
      'Gunluk bariyer skoru: %${(dailyBarrierScore * 100).round()} (formul: 0.6*bariyer + 0.4*gorev)',
    );
    riskExplanation.add(
      'Sure bariyeri uyumu: %${(barrierSuccessRate * 100).round()} (son: $recentBarrierSuccessCount basarili / $recentBarrierFailureCount basarisiz)',
    );
    riskExplanation.add(
      'Sure bariyeri tercihi: $barrierPreferenceRaw / siklik: $barrierFrequencyRaw / aktif: ${barrierEnabled ? 'evet' : 'hayir'}',
    );
    riskExplanation.add(
      'Adim aktivitesi: ${sedentaryToday ? 'bugun belirgin dusuk (+3)' : 'normal'}',
    );
    if (wearableRiskAdjustment > 0) {
      riskExplanation.add(
        'Bileklik nabzi: kisisel esikten yuksek okuma (+$wearableRiskAdjustment)',
      );
    }

    final dashboard = _behaviorEngine.buildDashboard(
      riskScore: dynamicRisk,
      records: records,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      todaysTasks: orderedTasks,
      coachCommands: balancedCoachCommands,
      commandSuccessScores: commandSuccessScores,
      commandCategoryScores: commandCategoryScores,
      commandMixMode: commandMixMode,
      weeklySurveyRiskScore: weeklyRiskScore,
      weeklySurveyRiskLevel: weeklyRiskLevel,
      weeklyTopRiskDrivers: weeklyTopRiskDrivers,
      riskExplanation: riskExplanation,
      learnedWeights: learnedWeights,
      prediction: prediction,
      plan: adaptivePlan,
      breathTrendLast3: breathTrendAnalysis.trendLast3,
      breathTrendRiskAdjustment: breathTrendAnalysis.riskAdjustment,
    );

    await saveBehaviorSnapshot({
      'riskScore': dashboard.riskScore,
      'riskyTriggers': dashboard.riskyTriggers,
      'riskyHours': dashboard.riskyHours,
      'breathTrend': dashboard.breathTrend,
      'breathTrendLast3': dashboard.breathTrendLast3,
      'breathTrendRiskAdjustment': dashboard.breathTrendRiskAdjustment,
      'progressSummary': dashboard.progressSummary,
      'todaysTasks': dashboard.todaysTasks,
      'coachCommands': dashboard.coachCommands,
      'commandSuccessScores': dashboard.commandSuccessScores,
      'commandCategoryScores': dashboard.commandCategoryScores,
      'commandMixMode': dashboard.commandMixMode,
      'weeklySurveyRiskScore': dashboard.weeklySurveyRiskScore,
      'weeklySurveyRiskLevel': dashboard.weeklySurveyRiskLevel,
      'weeklyTopRiskDrivers': dashboard.weeklyTopRiskDrivers,
      'riskExplanation': dashboard.riskExplanation,
      'learnedWeights': dashboard.learnedWeights,
      'predictedRiskWindow': dashboard.predictedRiskWindow,
      'predictionConfidence': dashboard.predictionConfidence,
      'predictedTrigger': dashboard.predictedTrigger,
      'plan': {
        'generatedAt': dashboard.plan.generatedAt.toIso8601String(),
        'targetDays': dashboard.plan.targetDays,
        'currentWeek': dashboard.plan.currentWeek,
        'currentDay': dashboard.plan.currentDay,
        'daysRemaining': dashboard.plan.daysRemaining,
        'weeklyRiskTarget': dashboard.plan.weeklyRiskTarget,
        'difficulty': dashboard.plan.difficulty,
        'cadenceLevel': dashboard.plan.cadenceLevel,
        'focusAreas': dashboard.plan.focusAreas,
      },
    });
    await clearBehaviorDirty();

    return dashboard;
  }

  int _taskOutcomeRiskAdjustment(List<TaskHistory> taskHistory) {
    if (taskHistory.isEmpty) {
      return 0;
    }

    final recent = taskHistory.length > 5
        ? taskHistory.sublist(taskHistory.length - 5)
        : taskHistory;
    var adjustment = 0;
    for (final item in recent) {
      adjustment += item.completed ? -2 : 3;
    }
    return adjustment.clamp(-6, 12);
  }

  int _taskPerformanceRiskScore(List<TaskHistory> taskHistory) {
    if (taskHistory.isEmpty) {
      return 55;
    }

    final sorted = [...taskHistory]..sort((a, b) => a.date.compareTo(b.date));
    final recent = sorted.length > 14
        ? sorted.sublist(sorted.length - 14)
        : sorted;
    final successCount = recent.where((item) => item.completed).length;
    final successRate = successCount / recent.length;

    var risk = ((1 - successRate) * 100).round();
    final streakWindow = recent.length > 5
        ? recent.sublist(recent.length - 5)
        : recent;
    if (streakWindow.every((item) => item.completed)) {
      risk -= 4;
    } else if (streakWindow.every((item) => !item.completed)) {
      risk += 6;
    }

    return risk.clamp(0, 100);
  }

  double _legacyBreathScoreEstimate(List<SurveyRecord> breathRecords) {
    if (breathRecords.isEmpty) {
      return 55;
    }

    final latest = breathRecords.last;
    final blowRisk = _breathTestEngine.blowDurationRisk(
      latest.inhaleTestSeconds.toDouble(),
    );

    final estimatedStability = 0.65;
    final estimatedIntensity = _breathTestEngine.estimateBlowIntensity(
      holdDuration: latest.exhaleTestSeconds.toDouble(),
      blowDuration: latest.inhaleTestSeconds.toDouble(),
    );

    return _breathTestEngine.breathScore(
      blowRisk: blowRisk,
      stabilityRisk: _breathTestEngine.stabilityRisk(estimatedStability),
      intensityRisk: _breathTestEngine.intensityRisk(estimatedIntensity),
    );
  }

  String _resolveCommandMixMode({
    required int riskScore,
    required int weeklyRiskTarget,
    required int recentSuccessCount,
    required int recentFailureCount,
  }) {
    final targetGap = riskScore - weeklyRiskTarget;
    if (riskScore >= 70 ||
        targetGap >= 15 ||
        recentFailureCount > recentSuccessCount) {
      return 'aggressive';
    }

    if (riskScore <= 45 &&
        targetGap <= 5 &&
        recentSuccessCount >= recentFailureCount + 2) {
      return 'protective';
    }

    return 'balanced';
  }

  int _resolveAdaptiveCommandCount({
    required Map<String, dynamic> weeklyPayload,
    required int riskScore,
    required int recentSuccessCount,
    required int recentFailureCount,
  }) {
    var count = 4;
    final task =
        weeklyPayload['task'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final burden = (task['commandBurdenLevel']?.toString() ?? 'orta')
        .toLowerCase();
    final adherence = (task['dailyTaskAdherenceLevel']?.toString() ?? 'orta')
        .toLowerCase();

    if (burden == 'cok') {
      count -= 1;
    } else if (burden == 'az') {
      count += 1;
    }

    if (adherence == 'az') {
      count -= 1;
    } else if (adherence == 'cok') {
      count += 1;
    }

    if (recentSuccessCount >= recentFailureCount + 3) {
      count += 1;
    } else if (recentFailureCount > recentSuccessCount + 1) {
      count -= 1;
    }

    if (riskScore >= 75) {
      count = count < 4 ? 4 : count;
    }

    if (count < 2) {
      return 2;
    }
    if (count > 5) {
      return 5;
    }
    return count;
  }

  /// Legacy title patterns a duration-barrier task could have been saved
  /// under before the `ADAPTIVE_NO_SMOKE:<minutes>` canonical-code refactor
  /// (see [MentorCommandCodes.isDurationBarrierCommand], the single current
  /// source of truth). Kept only so old rows already in a user's history
  /// still count -- nothing writes titles in this shape any more.
  static bool _isLegacyBarrierTitle(String title) {
    return title.toUpperCase().contains('SURE-BARIYERI') ||
        title.toLowerCase().contains('sure bariyeri') ||
        RegExp(r'Sonraki\s+\d+\s+dakika', caseSensitive: false).hasMatch(title);
  }

  /// Duration-barrier outcomes for the risk/mentor pipeline, read from
  /// [AdaptiveTaskEvent] -- the table every real ADAPTIVE_NO_SMOKE
  /// acceptance/confirmation actually writes to via
  /// [recordAdaptiveTaskOutcome] -- plus any legacy [TaskHistory] rows saved
  /// under the pre-refactor title patterns. `missed`/`deferred` outcomes are
  /// excluded on purpose: a barrier the user never got to answer is neutral,
  /// not a failure, the same principle [TaskLifecycleState.expired] and
  /// [TaskLifecycleState.barrierUnknown] already follow.
  Map<String, int> _summarizeDurationBarrierOutcomes(
    List<AdaptiveTaskEvent> adaptiveEvents,
    List<TaskHistory> taskHistory,
  ) {
    final canonicalOutcomes =
        adaptiveEvents
            .where(
              (event) =>
                  MentorCommandCodes.isDurationBarrierCommand(
                    event.taskTitle,
                  ) &&
                  (event.outcome == AdaptiveTaskOutcome.success ||
                      event.outcome == AdaptiveTaskOutcome.smoked),
            )
            .toList()
          ..sort((a, b) => a.respondedAt.compareTo(b.respondedAt));

    final legacyOutcomes = taskHistory
        .where((item) => _isLegacyBarrierTitle(item.taskTitle))
        .toList();

    var successCount = 0;
    var failureCount = 0;
    for (final event in canonicalOutcomes) {
      if (event.outcome == AdaptiveTaskOutcome.success) {
        successCount += 1;
      } else {
        failureCount += 1;
      }
    }
    for (final item in legacyOutcomes) {
      if (item.completed) {
        successCount += 1;
      } else {
        failureCount += 1;
      }
    }

    // "Recent" is the last 8 across both sources combined, canonical events
    // taken as more current since legacy rows all predate the refactor.
    final recentBooleans = <bool>[
      ...legacyOutcomes.map((item) => item.completed),
      ...canonicalOutcomes.map(
        (event) => event.outcome == AdaptiveTaskOutcome.success,
      ),
    ];
    final recent = recentBooleans.length > 8
        ? recentBooleans.sublist(recentBooleans.length - 8)
        : recentBooleans;
    var recentSuccessCount = 0;
    var recentFailureCount = 0;
    for (final completed in recent) {
      if (completed) {
        recentSuccessCount += 1;
      } else {
        recentFailureCount += 1;
      }
    }

    return {
      'successCount': successCount,
      'failureCount': failureCount,
      'recentSuccessCount': recentSuccessCount,
      'recentFailureCount': recentFailureCount,
    };
  }

  double _recentTaskCompletionRate(List<TaskHistory> taskHistory) {
    if (taskHistory.isEmpty) {
      return 0.5;
    }

    final recent = taskHistory.length > 10
        ? taskHistory.sublist(taskHistory.length - 10)
        : taskHistory;
    if (recent.isEmpty) {
      return 0.5;
    }

    final completed = recent.where((item) => item.completed).length;
    return completed / recent.length;
  }

  bool _isWithinWindow({
    required DateTime now,
    required String? startTime,
    required String? endTime,
  }) {
    if (startTime == null || endTime == null) {
      return false;
    }

    final startMinutes = _parseMinutes(startTime);
    final endMinutes = _parseMinutes(endTime);
    if (startMinutes == null || endMinutes == null) {
      return false;
    }

    final currentMinutes = now.hour * 60 + now.minute;
    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }

    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }

  Map<String, dynamic> _buildMergedProfileContext({
    required List<SurveyRecord> surveyRecords,
    required Map<String, Map<String, dynamic>> contextMap,
  }) {
    final merged = <String, dynamic>{};
    final sorted = [...surveyRecords]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    for (final record in sorted) {
      final context = contextMap[record.id];
      if (context == null) {
        continue;
      }

      void setIfPresent(String key) {
        final value = context[key];
        if (value == null) {
          return;
        }
        if (value is String && value.trim().isEmpty) {
          return;
        }
        if (value is List && value.isEmpty) {
          return;
        }
        merged[key] = value;
      }

      setIfPresent('profession');
      setIfPresent('sleepTime');
      setIfPresent('wakeTime');
      setIfPresent('workStart');
      setIfPresent('workEnd');
      setIfPresent('workplaceSmokingRule');
      setIfPresent('workingDays');
      setIfPresent('breakWindows');
      setIfPresent('weekendSmokingPattern');
      setIfPresent('firstCigaretteRange');
      setIfPresent('smokeFreeRange');
      setIfPresent('stressLevel');
      setIfPresent('quitReason');
      setIfPresent('healthConditions');
      setIfPresent('cigarettesPerPack');

      final weeklyPayload = context['weeklyPayload'] as Map<String, dynamic>?;
      if (weeklyPayload != null && weeklyPayload.isNotEmpty) {
        merged['weeklyPayload'] = weeklyPayload;
        final profileUpdate =
            weeklyPayload['profileUpdate'] as Map<String, dynamic>?;
        final changed = profileUpdate?['changed'] == true;
        if (changed) {
          final workStart = profileUpdate?['workStart']?.toString();
          final workEnd = profileUpdate?['workEnd']?.toString();
          final workplaceRule = profileUpdate?['workplaceSmokingRule']
              ?.toString();
          final weekendPattern = profileUpdate?['weekendSmokingPattern']
              ?.toString();
          final workingDays =
              (profileUpdate?['workingDays'] as List<dynamic>? ??
                      const <dynamic>[])
                  .map((item) => item.toString())
                  .where((item) => item.trim().isNotEmpty)
                  .toList();
          final breakWindows =
              (profileUpdate?['breakWindows'] as List<dynamic>? ??
                      const <dynamic>[])
                  .whereType<Map<String, dynamic>>()
                  .map(
                    (item) => {
                      'start': item['start']?.toString() ?? '',
                      'end': item['end']?.toString() ?? '',
                    },
                  )
                  .where(
                    (item) =>
                        item['start']!.trim().isNotEmpty &&
                        item['end']!.trim().isNotEmpty,
                  )
                  .toList();

          if (workStart != null && workStart.trim().isNotEmpty) {
            merged['workStart'] = workStart;
          }
          if (workEnd != null && workEnd.trim().isNotEmpty) {
            merged['workEnd'] = workEnd;
          }
          if (workplaceRule != null && workplaceRule.trim().isNotEmpty) {
            merged['workplaceSmokingRule'] = workplaceRule;
          }
          if (workingDays.isNotEmpty) {
            merged['workingDays'] = workingDays;
          }
          if (breakWindows.isNotEmpty) {
            merged['breakWindows'] = breakWindows;
          }
          if (weekendPattern != null && weekendPattern.trim().isNotEmpty) {
            merged['weekendSmokingPattern'] = weekendPattern;
          }
        }
      }
    }

    return merged;
  }

  String _weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return 'Mon';
    }
  }

  int _minutesUntilNextBreak({
    required DateTime now,
    required List<Map<String, String>> breakWindows,
  }) {
    if (breakWindows.isEmpty) {
      return -1;
    }

    final currentMinutes = now.hour * 60 + now.minute;
    var best = 24 * 60;
    for (final window in breakWindows) {
      final startMinutes = _parseMinutes(window['start'] ?? '');
      if (startMinutes == null) {
        continue;
      }
      var delta = startMinutes - currentMinutes;
      if (delta < 0) {
        delta += 24 * 60;
      }
      if (delta < best) {
        best = delta;
      }
    }

    return best == 24 * 60 ? -1 : best;
  }

  int _minutesUntilWindowEnds({
    required DateTime now,
    required String? endTime,
  }) {
    final endMinutes = _parseMinutes(endTime);
    if (endMinutes == null) {
      return 0;
    }

    final currentMinutes = now.hour * 60 + now.minute;
    var delta = endMinutes - currentMinutes;
    if (delta <= 0) {
      delta += 24 * 60;
    }
    return delta;
  }

  Map<String, String?> _inferWorkWindow({
    required String? wakeTime,
    required String? workStart,
    required String? workEnd,
  }) {
    if (workStart != null &&
        workStart.trim().isNotEmpty &&
        workEnd != null &&
        workEnd.trim().isNotEmpty) {
      return {'workStart': workStart, 'workEnd': workEnd};
    }

    final wake = wakeTime ?? '07:00';
    final wakeMinutes = _parseMinutes(wake) ?? (7 * 60);
    final inferredStart = _formatMinutes((wakeMinutes + 120) % (24 * 60));
    final inferredEnd = _formatMinutes((wakeMinutes + 600) % (24 * 60));

    return {
      'workStart': (workStart == null || workStart.trim().isEmpty)
          ? inferredStart
          : workStart,
      'workEnd': (workEnd == null || workEnd.trim().isEmpty)
          ? inferredEnd
          : workEnd,
    };
  }

  String _formatMinutes(int totalMinutes) {
    final safe = ((totalMinutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    final hour = (safe ~/ 60).toString().padLeft(2, '0');
    final minute = (safe % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int? _parseMinutes(String? time) {
    if (time == null || time.isEmpty) {
      return null;
    }
    final parts = time.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return (hour * 60) + minute;
  }

  Future<void> clearAllData() async {
    final db = await database;
    // Wrapped in a transaction so an interruption mid-reset can't leave
    // some tables cleared and others not.
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS $_settingsTable (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      for (final table in <String>[
        ...cloudBackupTableNames,
        _subscriptionStateTable,
      ]) {
        await txn.delete(table);
      }
    });
  }
}
