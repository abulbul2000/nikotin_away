import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/models/mentor_message.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp
        .createTempSync('no_smoke_mentor_message_test')
        .path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    final storage = StorageService();
    await storage.clearAllData();
  });

  test('saves and loads a mentor message with quick replies', () async {
    final storage = StorageService();
    await storage.saveMentorMessage(
      MentorMessage(
        id: 'm1',
        createdAt: DateTime(2026, 7, 21, 21, 0),
        type: 'daily',
        text: 'Bugün nasıl geçti?',
        tone: 'coach',
        quickReplies: const ['İyiyim', 'Zorlanıyorum'],
        read: false,
      ),
    );

    final latest = await storage.loadLatestMentorMessage();
    expect(latest, isNotNull);
    expect(latest!.text, 'Bugün nasıl geçti?');
    expect(latest.quickReplies, ['İyiyim', 'Zorlanıyorum']);
    expect(latest.read, isFalse);
  });

  test('replyToMentorMessage marks read and stores the reply', () async {
    final storage = StorageService();
    await storage.saveMentorMessage(
      MentorMessage(
        id: 'm2',
        createdAt: DateTime(2026, 7, 21, 21, 0),
        type: 'daily',
        text: 'Bugün nasıl geçti?',
        tone: 'coach',
        quickReplies: const ['İyiyim', 'Zorlanıyorum'],
        read: false,
      ),
    );

    await storage.replyToMentorMessage('m2', 'İyiyim');

    final messages = await storage.loadMentorMessages();
    expect(messages.first.read, isTrue);
    expect(messages.first.userReply, 'İyiyim');
  });

  test('loadMentorMessages returns newest first', () async {
    final storage = StorageService();
    await storage.saveMentorMessage(
      MentorMessage(
        id: 'older',
        createdAt: DateTime(2026, 7, 20),
        type: 'daily',
        text: 'dun',
        tone: 'neutral',
        quickReplies: const [],
        read: true,
      ),
    );
    await storage.saveMentorMessage(
      MentorMessage(
        id: 'newer',
        createdAt: DateTime(2026, 7, 21),
        type: 'daily',
        text: 'bugun',
        tone: 'neutral',
        quickReplies: const [],
        read: false,
      ),
    );

    final messages = await storage.loadMentorMessages();
    expect(messages.first.id, 'newer');
    expect(messages.last.id, 'older');
  });
}
