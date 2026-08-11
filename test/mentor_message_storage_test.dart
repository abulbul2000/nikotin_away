import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/core/mentor_command_codes.dart';
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
        text: 'MENTOR_DAILY_NEUTRAL_NOHOUR',
        tone: 'coach',
        quickReplies: const ['QUICK_REPLY_OK', 'QUICK_REPLY_STRUGGLING'],
        read: false,
      ),
    );

    final latest = await storage.loadLatestMentorMessage();
    expect(latest, isNotNull);
    expect(latest!.text, 'MENTOR_DAILY_NEUTRAL_NOHOUR');
    expect(latest.quickReplies, ['QUICK_REPLY_OK', 'QUICK_REPLY_STRUGGLING']);
    expect(latest.read, isFalse);
  });

  test('replyToMentorMessage marks read and stores the reply', () async {
    final storage = StorageService();
    await storage.saveMentorMessage(
      MentorMessage(
        id: 'm2',
        createdAt: DateTime(2026, 7, 21, 21, 0),
        type: 'daily',
        text: 'MENTOR_DAILY_NEUTRAL_NOHOUR',
        tone: 'coach',
        quickReplies: const ['QUICK_REPLY_OK', 'QUICK_REPLY_STRUGGLING'],
        read: false,
      ),
    );

    await storage.replyToMentorMessage('m2', 'QUICK_REPLY_OK');

    final messages = await storage.loadMentorMessages();
    expect(messages.first.read, isTrue);
    expect(messages.first.userReply, 'QUICK_REPLY_OK');
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

  test('attachMentorFollowUpQuestion sets the question and 3 options', () async {
    final storage = StorageService();
    await storage.saveMentorMessage(
      MentorMessage(
        id: 'm3',
        createdAt: DateTime(2026, 7, 21, 21, 0),
        type: 'daily',
        text: 'MENTOR_DAILY_SUPPORTIVE',
        tone: 'supportive',
        quickReplies: const ['QUICK_REPLY_OK', 'QUICK_REPLY_STRUGGLING'],
        read: false,
      ),
    );

    await storage.attachMentorFollowUpQuestion('m3');

    final loaded = await storage.loadLatestMentorMessage();
    expect(
      loaded!.followUpQuestion,
      MentorMessageCodes.followUpStrugglingQuestion,
    );
    expect(loaded.followUpQuickReplies, [
      MentorMessageCodes.quickReplyReduceTasks,
      MentorMessageCodes.quickReplyEaseBarrier,
      MentorMessageCodes.quickReplyJustTalking,
    ]);
    expect(loaded.followUpReply, isNull);
  });

  test(
    'applyMentorFollowUpChoice(reduceTasks) grants relief starting tomorrow',
    () async {
      final storage = StorageService();
      await storage.saveMentorMessage(
        MentorMessage(
          id: 'm4',
          createdAt: DateTime(2026, 7, 21, 21, 0),
          type: 'daily',
          text: 'MENTOR_DAILY_SUPPORTIVE',
          tone: 'supportive',
          quickReplies: const [],
          read: true,
        ),
      );

      final before = DateTime.now();
      await storage.applyMentorFollowUpChoice(
        'm4',
        MentorMessageCodes.quickReplyReduceTasks,
      );

      final reliefUntilRaw = await storage.loadSetting(
        'mentor_task_relief_until',
      );
      expect(reliefUntilRaw, isNotNull);
      final reliefUntil = DateTime.parse(reliefUntilRaw!);
      final tomorrow = DateTime(
        before.year,
        before.month,
        before.day + 1,
      );
      // Must start tomorrow (not today) and last roughly 7 days from there.
      expect(reliefUntil.isAfter(tomorrow), isTrue);
      expect(
        reliefUntil.difference(tomorrow).inDays,
        7,
      );

      final loaded = await storage.loadLatestMentorMessage();
      expect(loaded!.followUpReply, MentorMessageCodes.quickReplyReduceTasks);
    },
  );

  test(
    'applyMentorFollowUpChoice(easeBarrier) grants a single-day relief for tomorrow',
    () async {
      final storage = StorageService();
      await storage.saveMentorMessage(
        MentorMessage(
          id: 'm5',
          createdAt: DateTime(2026, 7, 21, 21, 0),
          type: 'daily',
          text: 'MENTOR_DAILY_SUPPORTIVE',
          tone: 'supportive',
          quickReplies: const [],
          read: true,
        ),
      );

      final before = DateTime.now();
      await storage.applyMentorFollowUpChoice(
        'm5',
        MentorMessageCodes.quickReplyEaseBarrier,
      );

      final reliefDateRaw = await storage.loadSetting(
        'mentor_barrier_relief_date',
      );
      expect(reliefDateRaw, isNotNull);
      final reliefDate = DateTime.parse(reliefDateRaw!);
      final tomorrow = DateTime(
        before.year,
        before.month,
        before.day + 1,
      );
      expect(reliefDate.year, tomorrow.year);
      expect(reliefDate.month, tomorrow.month);
      expect(reliefDate.day, tomorrow.day);

      final loaded = await storage.loadLatestMentorMessage();
      expect(loaded!.followUpReply, MentorMessageCodes.quickReplyEaseBarrier);
    },
  );

  test(
    'applyMentorFollowUpChoice(justTalking) grants no relief, only records the reply',
    () async {
      final storage = StorageService();
      await storage.saveMentorMessage(
        MentorMessage(
          id: 'm6',
          createdAt: DateTime(2026, 7, 21, 21, 0),
          type: 'daily',
          text: 'MENTOR_DAILY_SUPPORTIVE',
          tone: 'supportive',
          quickReplies: const [],
          read: true,
        ),
      );

      await storage.applyMentorFollowUpChoice(
        'm6',
        MentorMessageCodes.quickReplyJustTalking,
      );

      expect(await storage.loadSetting('mentor_task_relief_until'), isNull);
      expect(await storage.loadSetting('mentor_barrier_relief_date'), isNull);

      final loaded = await storage.loadLatestMentorMessage();
      expect(loaded!.followUpReply, MentorMessageCodes.quickReplyJustTalking);
    },
  );

  test(
    "today's cached adaptive plan is unaffected by a relief granted today "
    '(relief only ever starts tomorrow)',
    () async {
      final storage = StorageService();
      final now = DateTime(2026, 7, 21, 10, 0);
      final sleepAt = DateTime(2026, 7, 21, 23, 0);

      final firstPlan = await storage.buildAdaptiveNoSmokePlan(
        now: now,
        sleepAt: sleepAt,
        riskyHours: const [],
      );

      await storage.saveMentorMessage(
        MentorMessage(
          id: 'm7',
          createdAt: now,
          type: 'daily',
          text: 'MENTOR_DAILY_SUPPORTIVE',
          tone: 'supportive',
          quickReplies: const [],
          read: true,
        ),
      );
      await storage.applyMentorFollowUpChoice(
        'm7',
        MentorMessageCodes.quickReplyReduceTasks,
      );

      final secondPlan = await storage.buildAdaptiveNoSmokePlan(
        now: now,
        sleepAt: sleepAt,
        riskyHours: const [],
      );

      // Same calendar day, so the plan must come from cache unchanged —
      // proves the relief really does wait until tomorrow rather than
      // silently reshaping a day whose tasks may already be delivered.
      expect(secondPlan.items.length, firstPlan.items.length);
      expect(secondPlan.targetTaskCount, firstPlan.targetTaskCount);
    },
  );
}
