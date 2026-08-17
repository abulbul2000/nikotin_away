import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/core/app_texts.dart';
import 'package:no_smoke/core/mentor_command_codes.dart';
import 'package:no_smoke/pages/home_page.dart';
import 'package:no_smoke/services/language_service.dart';
import 'package:no_smoke/services/storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  static final String _documentsPath = Directory.systemTemp
      .createTempSync('no_smoke_home_mentor_card')
      .path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;
}

String _replyLabel(String code) =>
    AppTexts.localizeMentorReplyCode('tr', code);

String _messageLabel(String code) =>
    AppTexts.localizeMentorMessage('tr', code);

Widget _wrap() => const MaterialApp(
  locale: Locale('tr'),
  supportedLocales: [Locale('tr'), Locale('en')],
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: HomePage(
    name: 'Ada',
    riskScore: 10,
    riskLevel: 'DUSUK',
    mentorCardTestMode: true,
  ),
);

// These widget tests exercise the real HomePage mentor-card interaction.
// HomePage performs several sqflite/plugin-backed async reads during startup,
// so pumpUntilMentorCard gives those futures a real async turn before polling
// the rendered card.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const watchdogChannel = MethodChannel('no_smoke/watchdog');
  const stepChannel = MethodChannel('no_smoke/step_tracking');
  const locationChannel = MethodChannel('no_smoke/location_intelligence');
  const smokedLogChannel = MethodChannel('no_smoke/smoked_log_button');

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService().clearAllData();
    // HomePage reads the persisted app language, not only MaterialApp.locale.
    // Keep both the test labels and the rendered Mentor Card in Turkish.
    await LanguageService.saveSelectedLanguageCode('tr');
    for (final channel in [
      notificationsChannel,
      watchdogChannel,
      stepChannel,
      locationChannel,
      smokedLogChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  tearDown(() async {
    await StorageService().closeDatabaseConnection();
    for (final channel in [
      notificationsChannel,
      watchdogChannel,
      stepChannel,
      locationChannel,
      smokedLogChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  /// Pumps the lightweight mentor-card-only HomePage mode and waits for the
  /// async daily-message load without pumpAndSettle().
  Future<void> pumpUntilMentorCard(WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    for (var i = 0; i < 20; i += 1) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byKey(
            const ValueKey('mentor_reply_${MentorMessageCodes.quickReplyStruggling}'),
          )
              .evaluate()
              .isNotEmpty ||
          find.byKey(
            const ValueKey('mentor_reply_${MentorMessageCodes.quickReplyOk}'),
          )
              .evaluate()
              .isNotEmpty) {
        break;
      }
    }
  }

  testWidgets(
    'tapping Zorlanıyorum reveals the follow-up question and its 3 buttons',
    (tester) async {
      await pumpUntilMentorCard(tester);

      final strugglingButton = find.byKey(
        const ValueKey(
          'mentor_reply_${MentorMessageCodes.quickReplyStruggling}',
        ),
      );
      expect(strugglingButton, findsOneWidget);

      await tester.tap(strugglingButton);
      await tester.pump();

      expect(
        find.text(
          _messageLabel(MentorMessageCodes.followUpStrugglingQuestion),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'mentor_follow_up_reply_${MentorMessageCodes.quickReplyReduceTasks}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'mentor_follow_up_reply_${MentorMessageCodes.quickReplyEaseBarrier}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'mentor_follow_up_reply_${MentorMessageCodes.quickReplyNoTalk}',
          ),
        ),
        findsOneWidget,
      );
      // The original quick-reply buttons are gone now that we're answered.
      expect(
        find.byKey(
          const ValueKey(
            'mentor_reply_${MentorMessageCodes.quickReplyOk}',
          ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('tapping Görevleri azalt shows the ack text and a SnackBar', (
    tester,
  ) async {
    await pumpUntilMentorCard(tester);

    await tester.tap(
      find.byKey(
        const ValueKey(
          'mentor_reply_${MentorMessageCodes.quickReplyStruggling}',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(
        const ValueKey(
          'mentor_follow_up_reply_${MentorMessageCodes.quickReplyReduceTasks}',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text(_messageLabel(MentorMessageCodes.followUpAckReduceTasks)),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);
    // The follow-up buttons are gone now that a choice was made.
    expect(
      find.widgetWithText(
        OutlinedButton,
        _replyLabel(MentorMessageCodes.quickReplyEaseBarrier),
      ),
      findsNothing,
    );
  });

  testWidgets('tapping İyiyim never shows a follow-up question', (
    tester,
  ) async {
    await pumpUntilMentorCard(tester);

    await tester.tap(
      find.byKey(
        const ValueKey(
          'mentor_reply_${MentorMessageCodes.quickReplyOk}',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('mentor_follow_up_question')),
      findsNothing,
    );
    // "Yanitin: İyiyim" — the pre-existing "reply sent" acknowledgement,
    // proving the struggling-only follow-up branch was never taken.
    expect(
      find.byKey(const ValueKey('mentor_reply_ack')),
      findsOneWidget,
    );
  });
}
