import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/adaptive_plan.dart';
import '../models/behavior_dashboard.dart';
import '../models/protocol_violation.dart';
import '../models/sensor_usage_event.dart';
import '../models/survey_record.dart';
import '../models/task_history.dart';
import '../models/user_profile_snapshot.dart';
import '../engines/mentor_engine.dart';
import '../engines/prediction_engine.dart';
import 'behavior_engine.dart';

class StorageService {
  static const _tableName = 'app_events';
  static const _settingsTable = 'app_settings';
  static const _surveyDetailsTable = 'survey_details';
  static const _profileSnapshotTable = 'user_profile_snapshots';
  static const _languageHistoryTable = 'language_history';
  static const _sensorUsageTable = 'sensor_usage_events';
  static const _behaviorSnapshotTable = 'behavior_snapshots';
  static const _taskFollowUpTable = 'task_followups';
  static const _protocolViolationTable = 'protocol_violations';
  static const _behaviorDirtyKey = 'behavior_dirty';
  static const _registrationCompletedKey = 'registration_completed';
  static const _isProfileCompletedKey = 'isProfileCompleted';
  static const _surveyTypes = {'initial', 'weekly'};
  final BehaviorEngine _behaviorEngine = BehaviorEngine();
  final PredictionEngine _predictionEngine = PredictionEngine();
  final MentorEngine _mentorEngine = MentorEngine();
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = p.join(documentsDirectory.path, 'no_smoke.db');
    return openDatabase(
      path,
      version: 9,
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
        await _ensureBehaviorSnapshotTable(db);
        await _ensureTaskFollowUpTable(db);
        await _ensureProtocolViolationTable(db);
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
        await _ensureBehaviorSnapshotTable(db);
        await _ensureTaskFollowUpTable(db);
        await _ensureProtocolViolationTable(db);
        if (oldVersion < 9) {
          await _ensureIndexes(db);
        }
      },
    );
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
        screenUnlockCount INTEGER NOT NULL,
        appUsageMinutes INTEGER NOT NULL,
        idleMinutes INTEGER NOT NULL,
        charging INTEGER NOT NULL
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

  Future<Map<String, List<String>>> loadTriggerMapByRecordId() async {
    final db = await database;
    final rows = await db.query(_surveyDetailsTable);
    final result = <String, List<String>>{};
    for (final row in rows) {
      final recordId = row['recordId'] as String;
      final raw = row['triggerJson'] as String?;
      if (raw == null || raw.isEmpty) {
        result[recordId] = const [];
        continue;
      }
      final parsed = (jsonDecode(raw) as List<dynamic>)
          .map((item) => item.toString())
          .toList();
      result[recordId] = parsed;
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
      final healthConditions = healthRaw == null || healthRaw.isEmpty
          ? <String>[]
          : (jsonDecode(healthRaw) as List<dynamic>)
                .map((item) => item.toString())
                .toList();
      final weeklyPayload = weeklyRaw == null || weeklyRaw.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(weeklyRaw) as Map<String, dynamic>);
      final workingDays = workingDaysRaw == null || workingDaysRaw.isEmpty
          ? <String>[]
          : (jsonDecode(workingDaysRaw) as List<dynamic>)
                .map((item) => item.toString())
                .toList();
      final breakWindows = breakWindowsRaw == null || breakWindowsRaw.isEmpty
          ? <Map<String, String>>[]
          : (jsonDecode(breakWindowsRaw) as List<dynamic>)
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
      'screenUnlockCount': event.screenUnlockCount,
      'appUsageMinutes': event.appUsageMinutes,
      'idleMinutes': event.idleMinutes,
      'charging': event.charging ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await markBehaviorDirty();
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
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
        screenUnlockCount: (row['screenUnlockCount'] as num).toInt(),
        appUsageMinutes: (row['appUsageMinutes'] as num).toInt(),
        idleMinutes: (row['idleMinutes'] as num).toInt(),
        charging: ((row['charging'] as num?)?.toInt() ?? 0) == 1,
      );
    }).toList();
  }

  Future<List<TaskHistory>> loadTaskHistory() async {
    final records = await loadSurveyHistory();
    return records
        .where(
          (record) =>
              record.type == 'task_result' &&
              (record.taskTitle?.isNotEmpty ?? false),
        )
        .map((record) {
          final resultText = (record.taskResult ?? '').toLowerCase();
          final completed =
              resultText.contains('success') ||
              resultText.contains('basar') ||
              resultText.contains('tamam');
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
    final record = SurveyRecord(
      id: 'task_${completedAt.millisecondsSinceEpoch}',
      completedAt: completedAt,
      type: 'task_result',
      title: 'Görev Sonucu',
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
      'createdAt': now.toIso8601String(),
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

  Future<void> resolveTaskFollowUpByTitle(String taskTitle) async {
    final db = await database;
    await db.update(
      _taskFollowUpTable,
      {'status': 'resolved'},
      where: 'taskTitle = ? AND status = ?',
      whereArgs: [taskTitle, 'pending'],
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
    final data = jsonDecode(raw) as Map<String, dynamic>;
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
      progressSummary: data['progressSummary']?.toString() ?? 'Stable',
      todaysTasks: (data['todaysTasks'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      coachCommands: (data['coachCommands'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      durationBarrierCommands:
          (data['durationBarrierCommands'] as List<dynamic>? ?? const [])
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

  Future<int> calculateAdjustedRiskScore({
    required int baseScore,
    required int exhaleSeconds,
    required int inhaleSeconds,
  }) async {
    final records = await loadSurveyHistory();
    final breathRecords = records
        .where((record) => record.type == 'breath_test')
        .toList();
    var adjustedScore = baseScore;

    if (breathRecords.isNotEmpty) {
      final previousAverage =
          ((breathRecords.last.exhaleTestSeconds +
                      breathRecords.last.inhaleTestSeconds) /
                  2)
              .round();
      final currentAverage = ((exhaleSeconds + inhaleSeconds) / 2).round();
      final difference = currentAverage - previousAverage;
      adjustedScore += difference * 2;
    }

    final latestSurvey = records.reversed.firstWhere(
      (record) => _surveyTypes.contains(record.type),
      orElse: () => SurveyRecord(
        id: 'fallback',
        completedAt: DateTime.fromMillisecondsSinceEpoch(0),
        type: 'initial',
        title: 'Başlangıç',
        name: '',
        packsPerDay: '1 paketten az',
        exhaleTestSeconds: 0,
        inhaleTestSeconds: 0,
        riskScore: 0,
        riskLevel: 'BİLİNMEYEN',
      ),
    );

    if (latestSurvey.id != 'fallback') {
      adjustedScore += _behaviorEngine.calculatePackRiskContribution(
        latestSurvey.packsPerDay,
      );
      adjustedScore += _behaviorEngine.calculateConsecutiveSmokingScore(
        habit: latestSurvey.consecutiveSmokingHabit,
        count: latestSurvey.consecutiveSmokingCount,
      );
    }

    return adjustedScore.clamp(0, 100);
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
    final riskyTriggers = _behaviorEngine.calculateRiskyTriggers(triggerScores);

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
    final profileAdjustment = _behaviorEngine.calculateProfileRiskAdjustment(
      profession: latestContext['profession'] as String?,
      sleepTime: latestContext['sleepTime'] as String?,
      wakeTime: latestContext['wakeTime'] as String?,
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

    final preWeeklyRisk =
        (dynamicCoreRisk +
                personalizedAdjustment +
                profileAdjustment +
                taskAdjustment)
            .clamp(0, 100);

    final weeklyPayload =
        (latestContext['weeklyPayload'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final weeklyEvaluation = _behaviorEngine.evaluateWeeklySurveyRisk(
      weeklyPayload,
      profileContext: latestContext,
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

    var dynamicRisk = ((preWeeklyRisk * 0.7) + (weeklyRiskScore * 0.3)).round();
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
    final barrierOutcomeSummary = _summarizeDurationBarrierOutcomes(
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

    final adaptiveTaskCount = recentFailureCount >= recentSuccessCount + 3
        ? 5
        : recentFailureCount > recentSuccessCount
        ? 4
        : recentSuccessCount >= recentFailureCount + 4
        ? 2
        : 3;
    final baseTasks = _behaviorEngine.generateAdaptiveTasks(
      riskScore: dynamicRisk,
      taskSuccessRates: taskRates,
      isFirstProfile: isFirstProfile,
      count: isFirstProfile ? 1 : adaptiveTaskCount,
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
    final durationBarrierCommands = barrierEnabled
        ? _mentorEngine.buildDurationBarrierCommands(
            riskScore: dynamicRisk,
            predictedWindow: prediction['nextRiskWindow']?.toString(),
            riskyHours: riskyHours,
            recentSuccessCount: recentSuccessCount,
            recentFailureCount: recentFailureCount,
            barrierSuccessRate: barrierSuccessRate,
            recentBarrierSuccessCount: recentBarrierSuccessCount,
            recentBarrierFailureCount: recentBarrierFailureCount,
            recentTaskCompletionRate: recentTaskCompletionRate,
            packsPerDay: latestSurvey?.packsPerDay ?? '1 paketten az',
            firstCigaretteRange: latestContext['firstCigaretteRange']
                ?.toString(),
            smokeFreeRange: latestContext['smokeFreeRange']?.toString(),
            stressLevel: latestContext['stressLevel']?.toString(),
            workplaceSmokingRule: latestContext['workplaceSmokingRule']
                ?.toString(),
            barrierPreference: barrierPreferenceRaw,
            barrierFrequencyPreference: barrierFrequencyRaw,
            barrierEnabled: barrierEnabled,
          )
        : const <String>[];

    final riskExplanation = _behaviorEngine.buildRiskExplanation(
      baseRisk: baseRisk,
      dynamicCoreRisk: dynamicCoreRisk,
      personalizedAdjustment: personalizedAdjustment,
      profileAdjustment: profileAdjustment,
      taskAdjustment: taskAdjustment,
      finalRisk: dynamicRisk,
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

    final dashboard = _behaviorEngine.buildDashboard(
      riskScore: dynamicRisk,
      records: records,
      riskyTriggers: riskyTriggers,
      riskyHours: riskyHours,
      todaysTasks: orderedTasks,
      coachCommands: balancedCoachCommands,
      durationBarrierCommands: durationBarrierCommands,
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
    );

    await saveBehaviorSnapshot({
      'riskScore': dashboard.riskScore,
      'riskyTriggers': dashboard.riskyTriggers,
      'riskyHours': dashboard.riskyHours,
      'breathTrend': dashboard.breathTrend,
      'progressSummary': dashboard.progressSummary,
      'todaysTasks': dashboard.todaysTasks,
      'coachCommands': dashboard.coachCommands,
      'durationBarrierCommands': dashboard.durationBarrierCommands,
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

  Map<String, int> _summarizeDurationBarrierOutcomes(
    List<TaskHistory> taskHistory,
  ) {
    final barriers = taskHistory
        .where(
          (item) =>
              item.taskTitle.toUpperCase().contains('SURE-BARIYERI') ||
              item.taskTitle.toLowerCase().contains('sure bariyeri'),
        )
        .toList();

    var successCount = 0;
    var failureCount = 0;
    for (final item in barriers) {
      if (item.completed) {
        successCount += 1;
      } else {
        failureCount += 1;
      }
    }

    final recent = barriers.length > 8
        ? barriers.sublist(barriers.length - 8)
        : barriers;
    var recentSuccessCount = 0;
    var recentFailureCount = 0;
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.delete(_tableName);
    await db.delete(_settingsTable);
    await db.delete(_surveyDetailsTable);
    await db.delete(_profileSnapshotTable);
    await db.delete(_languageHistoryTable);
    await db.delete(_sensorUsageTable);
    await db.delete(_behaviorSnapshotTable);
    await db.delete(_taskFollowUpTable);
  }
}
