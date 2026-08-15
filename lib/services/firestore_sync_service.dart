// Firestore cloud sync service.
//
// When the user is signed in with Google, their survey + progress data
// is synced to Firestore. On reinstall, signing in again restores it.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/survey_record.dart';

class FirestoreSyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static bool get _isGoogleUser =>
      FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'google.com') ??
      false;

  /// Upload survey records + details to Firestore.
  static Future<void> syncSurveyToCloud({
    required List<SurveyRecord> records,
    required Map<String, Map<String, dynamic>> context,
  }) async {
    if (!_isGoogleUser) return;

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
    if (!_isGoogleUser || _uid.isEmpty) {
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
    if (!_isGoogleUser || _uid.isEmpty) return false;
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
    if (!_isGoogleUser) return;
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
    if (!_isGoogleUser || _uid.isEmpty) return [];
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
