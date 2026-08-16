// Firestore cloud sync service.
//
// When the user is signed in with Google, their survey + progress data
// is synced to Firestore. On reinstall, signing in again restores it.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/survey_record.dart';
import 'storage_service.dart';

class FirestoreSyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static bool get _isCloudUser {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  static DocumentReference<Map<String, dynamic>> get _backupRoot =>
      _db
          .collection('user_data')
          .doc(_uid)
          .collection('database_backup')
          .doc('snapshot');

  /// Uploads every user-owned SQLite table in small JSON chunks. Device-only
  /// permissions and notification schedules are intentionally recreated by
  /// the new phone; the user data and learning state are not device-bound.
  static Future<void> syncLocalDatabaseBackup(StorageService storage) async {
    if (!_isCloudUser || _uid.isEmpty) return;
    try {
      final backup = await storage.exportCloudBackup();
      await _backupRoot.set({
        'schemaVersion': 1,
        'state': 'uploading',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      for (final table in StorageService.cloudBackupTableNames) {
        final tableRef = _backupRoot.collection('tables').doc(table);
        final oldChunks = await tableRef.collection('chunks').get();
        var batch = _db.batch();
        var operationCount = 0;
        Future<void> commitIfFull() async {
          if (operationCount < 450) return;
          await batch.commit();
          batch = _db.batch();
          operationCount = 0;
        }
        for (final old in oldChunks.docs) {
          batch.delete(old.reference);
          operationCount++;
          await commitIfFull();
        }
        final rows = backup[table] ?? const <Map<String, dynamic>>[];
        for (var offset = 0, chunk = 0;
            offset < rows.length;
            offset += 50, chunk++) {
          final end =
              offset + 50 < rows.length ? offset + 50 : rows.length;
          batch.set(
            tableRef.collection('chunks').doc(chunk.toString()),
            {'rowsJson': jsonEncode(rows.sublist(offset, end))},
          );
          operationCount++;
          await commitIfFull();
        }
        if (operationCount > 0) await batch.commit();
      }
      await _backupRoot.set({
        'schemaVersion': 1,
        'state': 'ready',
        'updatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('[FirestoreSync] Full local database backup synced');
    } catch (error, stackTrace) {
      debugPrint('[FirestoreSync] Full backup sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Restores the full local database backup. Returns false when the account
  /// has no full backup yet, allowing the legacy survey-only migration path.
  static Future<bool> restoreLocalDatabaseBackup(StorageService storage) async {
    if (!_isCloudUser || _uid.isEmpty) return false;
    try {
      final root = await _backupRoot.get();
      if (!root.exists || root.data()?['state'] != 'ready') return false;
      final tables = await _backupRoot.collection('tables').get();
      final backup = <String, List<Map<String, dynamic>>>{};
      for (final tableDoc in tables.docs) {
        final chunks = await tableDoc.reference.collection('chunks').get();
        final rows = <Map<String, dynamic>>[];
        for (final chunk in chunks.docs) {
          final raw = chunk.data()['rowsJson'];
          if (raw is! String) continue;
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            rows.addAll(
              decoded.whereType<Map>().map(
                (row) => Map<String, dynamic>.from(row),
              ),
            );
          }
        }
        backup[tableDoc.id] = rows;
      }
      await storage.importCloudBackup(backup);
      debugPrint('[FirestoreSync] Full local database backup restored');
      return true;
    } catch (error, stackTrace) {
      debugPrint('[FirestoreSync] Full backup restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Upload survey records + details to Firestore.
  static Future<void> syncSurveyToCloud({
    required List<SurveyRecord> records,
    required Map<String, Map<String, dynamic>> context,
  }) async {
    if (!_isCloudUser) return;

    try {
      // Save survey records as a sub-collection
      final surveyBatch = _db.batch();
      for (final record in records) {
        final ref = _db
            .collection('user_data')
            .doc(_uid)
            .collection('surveys')
            .doc(record.id);
        surveyBatch.set(ref, {
          'recordJson': jsonEncode(record.toJson()),
          'completedAt': record.completedAt.toIso8601String(),
          'type': record.type,
        });
      }

      // Save survey details as a separate doc
      if (context.isNotEmpty) {
        final contextMap = <String, dynamic>{};
        for (final entry in context.entries) {
          // Clean up complex types for Firestore compatibility
          final cleaned = <String, dynamic>{};
          for (final kv in entry.value.entries) {
            final v = kv.value;
            if (v == null) continue;
            if (v is List) {
              cleaned[kv.key] = v.map((e) => e.toString()).toList();
            } else if (v is Map) {
              cleaned[kv.key] = jsonEncode(v);
            } else {
              cleaned[kv.key] = v;
            }
          }
          contextMap[entry.key] = cleaned;
        }

        surveyBatch.set(
          _db.collection('user_data').doc(_uid).collection('meta').doc('context'),
          {'records': contextMap},
        );
      }

      await surveyBatch.commit();
      debugPrint('[FirestoreSync] Survey synced: ${records.length} records');
    } catch (error, stackTrace) {
      debugPrint('[FirestoreSync] Sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Download survey records from Firestore.
  /// Returns (records, context) — both may be empty.
  static Future<(List<SurveyRecord>, Map<String, Map<String, dynamic>>)>
  restoreFromCloud() async {
    if (!_isCloudUser || _uid.isEmpty) {
      return (
        <SurveyRecord>[],
        <String, Map<String, dynamic>>{},
      );
    }

    try {
      // Load survey records
      final surveySnap = await _db
          .collection('user_data')
          .doc(_uid)
          .collection('surveys')
          .orderBy('completedAt')
          .get();

      final records = <SurveyRecord>[];
      for (final doc in surveySnap.docs) {
        final recordJson = doc.data()['recordJson'] as String?;
        if (recordJson != null && recordJson.isNotEmpty) {
          final data = jsonDecode(recordJson);
          if (data is Map<String, dynamic>) {
            records.add(SurveyRecord.fromJson(data));
          }
        }
      }

      // Load context
      final contextSnap = await _db
          .collection('user_data')
          .doc(_uid)
          .collection('meta')
          .doc('context')
          .get();

      final context = <String, Map<String, dynamic>>{};
      if (contextSnap.exists) {
        final data = contextSnap.data() ?? {};
        final recordsData = data['records'];
        if (recordsData is Map) {
          for (final entry in recordsData.entries) {
            final v = entry.value;
            if (v is Map) {
              context[entry.key] = Map<String, dynamic>.from(v);
            }
          }
        }
      }

      debugPrint(
        '[FirestoreSync] Restored ${records.length} records from cloud',
      );
      return (records, context);
    } catch (error, stackTrace) {
      debugPrint('[FirestoreSync] Restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return (
        <SurveyRecord>[],
        <String, Map<String, dynamic>>{},
      );
    }
  }

  /// Check if there is cloud data available for the current user.
  static Future<bool> hasCloudData() async {
    if (!_isCloudUser || _uid.isEmpty) return false;
    try {
      final snap = await _db
          .collection('user_data')
          .doc(_uid)
          .collection('surveys')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Upload a single breath progress record.
  static Future<void> syncBreathProgress({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    if (!_isCloudUser) return;
    try {
      await _db
          .collection('user_data')
          .doc(_uid)
          .collection('breath_progress')
          .doc(id)
          .set({
            'json': jsonEncode(data),
            'updatedAt': DateTime.now().toIso8601String(),
          });
    } catch (error, stackTrace) {
      debugPrint('[FirestoreSync] Breath progress sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Download breath progress records from Firestore.
  static Future<List<Map<String, dynamic>>> restoreBreathProgress() async {
    if (!_isCloudUser || _uid.isEmpty) return [];
    try {
      final snap = await _db
          .collection('user_data')
          .doc(_uid)
          .collection('breath_progress')
          .orderBy('updatedAt')
          .get();

      return snap.docs
          .map((doc) {
            final raw = doc.data()['json'] as String?;
            if (raw == null) return null;
            final decoded = jsonDecode(raw);
            return decoded is Map<String, dynamic> ? decoded : null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
