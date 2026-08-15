import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_texts.dart';
import '../models/medication.dart';
import '../services/ai_service.dart';
import '../services/device_permission_service.dart';
import '../services/health_connect_service.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'subscription_gate_page.dart';

/// A voice command recognised locally, before any AI round-trip. Keeping this
/// whitelist narrow and explicit means an accidental phrase can only ever
/// trigger one of these known, reversible actions — everything else falls
/// through to the regular AI chat flow.
class _VoiceCommandIntent {
  const _VoiceCommandIntent(this.action, this.summaryText);

  final AiAction action;

  /// Short human-readable summary shown in the confirmation dialog.
  final String summaryText;
}

typedef _VoicePattern = ({
  RegExp pattern,
  _VoiceCommandIntent Function(Match) build,
});

final List<_VoicePattern> _voiceIntentPatterns = <_VoicePattern>[
  (
    pattern: RegExp(
      r'\b(koç modunu?|coach modunu?)\s*(kapat|devre dışı|off|kapalı)',
      caseSensitive: false,
    ),
    build: (m) => _VoiceCommandIntent(
      const AiAction(name: 'set_coach_mode', arguments: {'preference': 'off'}),
      'Koç modu kapatılacak',
    ),
  ),
  (
    pattern: RegExp(
      r'\b(koç modunu?|coach modunu?)\s*(aç|etkinleştir|on|aktif)',
      caseSensitive: false,
    ),
    build: (m) => _VoiceCommandIntent(
      const AiAction(
        name: 'set_coach_mode',
        arguments: {'preference': 'like', 'frequency': 'orta'},
      ),
      'Koç modu açılacak',
    ),
  ),
  (
    pattern: RegExp(
      r'\b(koç modunu?|coach modunu?)\s*(sevmedim|kötü|beğenmedim|nefret)',
      caseSensitive: false,
    ),
    build: (m) => _VoiceCommandIntent(
      const AiAction(
        name: 'set_coach_mode',
        arguments: {'preference': 'dislike'},
      ),
      'Koç modu kapatılacak (beğenilmedi)',
    ),
  ),
  (
    pattern: RegExp(
      r'\b(mikrofon|mikrofon erişimi|microphone)\s*(izin|erişim)',
      caseSensitive: false,
    ),
    build: (m) => _VoiceCommandIntent(
      const AiAction(
        name: 'set_permission',
        arguments: {'permission': 'microphone'},
      ),
      'Mikrofon izni istenecek',
    ),
  ),
  (
    pattern: RegExp(
      r'\b(konum|yer|location|gps)\s*(izin|erişim|aç)',
      caseSensitive: false,
    ),
    build: (m) => _VoiceCommandIntent(
      const AiAction(
        name: 'set_permission',
        arguments: {'permission': 'location'},
      ),
      'Konum izni istenecek',
    ),
  ),
  (
    pattern: RegExp(
      r'\b(adım|adım sayar|aktivite|activity)\s*(izin|erişim|aç)',
      caseSensitive: false,
    ),
    build: (m) => _VoiceCommandIntent(
      const AiAction(
        name: 'set_permission',
        arguments: {'permission': 'activityRecognition'},
      ),
      'Adım/aktivite izni istenecek',
    ),
  ),
];

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.pendingAction,
    this.voiceSummary,
  });

  final String text;
  final bool fromUser;
  final AiAction? pendingAction;

  /// If this message is a recognised voice command, its local summary text
  /// shown above the apply/dismiss buttons instead of the raw transcript.
  final String? voiceSummary;

  _ChatMessage resolved() => _ChatMessage(
    text: text,
    fromUser: fromUser,
    pendingAction: null,
    voiceSummary: voiceSummary,
  );
}

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [];
  final List<AiChatTurn> _history = [];
  final StorageService _storage = StorageService();
  final SpeechToText _speech = SpeechToText();
  bool _sending = false;
  bool _listening = false;
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    _loadSavedHistory();
  }

  Future<void> _loadSavedHistory() async {
    try {
      final raw = await _storage.loadSetting('ai_chat_history_v1');
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final turns = <AiChatTurn>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final role = item['role'];
        final content = item['content'];
        if ((role == 'user' || role == 'assistant') && content is String) {
          turns.add(AiChatTurn(role: role, content: content));
        }
      }
      if (!mounted || turns.isEmpty) return;
      final restoredTurns = turns.length > 20
          ? turns.sublist(turns.length - 20)
          : turns;
      setState(() {
        _history
          ..clear()
          ..addAll(restoredTurns);
        _messages
          ..clear()
          ..addAll(
            restoredTurns.map(
              (turn) => _ChatMessage(
                text: turn.content,
                fromUser: turn.role == 'user',
              ),
            ),
          );
      });
    } catch (error) {
      debugPrint('[AIChat] saved history restore failed: $error');
    }
  }

  Future<void> _persistHistory() async {
    try {
      final turns = _history.length > 20
          ? _history.sublist(_history.length - 20)
          : _history;
      final payload = turns
          .map((turn) => turn.toJson())
          .toList(growable: false);
      await _storage.saveSetting('ai_chat_history_v1', jsonEncode(payload));
    } catch (error) {
      debugPrint('[AIChat] saved history write failed: $error');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_listening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _startListening() async {
    // Re-initialize in case the service was stopped after a previous failure.
    final available = await _speech.initialize(
      onError: (error) {
        debugPrint('SpeechToText error: ${error.errorMsg}');
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('aiChatMicPermissionDenied')),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {
              ph.Permission.microphone.request();
            },
          ),
        ),
      );
      return;
    }

    // If a previous listening session is still active, stop it first.
    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final locale = await _resolveListeningLocale();
    _textBeforeListening = _controller.text;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        // Only use final results or non-empty partial results to avoid
        // flickering the input with empty strings.
        if (!result.finalResult && result.recognizedWords.trim().isEmpty) {
          return;
        }
        final separator = _textBeforeListening.isEmpty ? '' : ' ';
        final combined =
            '$_textBeforeListening$separator${result.recognizedWords}';
        _controller.text = combined;
        _controller.selection = TextSelection.collapsed(
          offset: combined.length,
        );
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
        localeId: locale,
      ),
    );
  }

  /// Picks a listening locale the device speech engine actually supports.
  /// Falls back to the current locale first, then English, and finally lets
  /// the platform choose when nothing works.
  Future<String?> _resolveListeningLocale() async {
    final locales = await _speech.locales();
    final localeIds = locales.map((l) => l.localeId).toList();
    final preferred = await LanguageService.loadSelectedLanguageCode();
    final candidates = <String>[
      preferred,
      'tr_TR',
      'tr',
      'en_US',
      'en',
    ];
    for (final candidate in candidates) {
      if (localeIds.contains(candidate)) return candidate;
    }
    // Fallback to any locale whose language prefix matches the preference.
    for (final id in localeIds) {
      if (id.startsWith(preferred)) return id;
    }
    return null;
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);
  }

  _VoiceCommandIntent? _matchVoiceIntent(String spokenText) {
    final lower = spokenText.trim().toLowerCase();
    for (final entry in _voiceIntentPatterns) {
      final match = entry.pattern.firstMatch(lower);
      if (match != null) {
        return entry.build(match);
      }
    }
    return null;
  }

  /// Ensures the anonymous Firebase identity exists before any callable is
  /// invoked — the aiChat Cloud Function rejects requests without auth
  /// (functions/index.js requireAuth), and the app-wide sign-in in main()
  /// is best-effort so it may not have completed by the time the user opens
  /// this page.
  Future<bool> _ensureAuth() async {
    try {
      if (auth.FirebaseAuth.instance.currentUser == null) {
        debugPrint('[AIChat] No currentUser, attempting anonymous sign-in…');
        final userCredential =
            await auth.FirebaseAuth.instance.signInAnonymously();
        debugPrint(
          '[AIChat] Anonymous sign-in result: uid=${userCredential.user?.uid}',
        );
        return userCredential.user != null;
      }
      debugPrint(
        '[AIChat] currentUser exists: uid=${auth.FirebaseAuth.instance.currentUser?.uid}',
      );
      return true;
    } catch (e) {
      debugPrint('[AIChat] Auth failed: $e');
      return false;
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    // Make sure anonymous auth is in place before touching the network.
    final authed = await _ensureAuth();
    if (!authed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firebase girişi yapılamadı. İnternet bağlantını kontrol et ve tekrar dene.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _history.add(AiChatTurn(role: 'user', content: text));
      _controller.clear();
      _sending = true;
    });

    // Local whitelist check: well-known settings phrases turn into an
    // on-device confirmation dialog without touching the network.
    final intent = _matchVoiceIntent(text);
    if (intent != null) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: '',
            fromUser: false,
            pendingAction: intent.action,
            voiceSummary: intent.summaryText,
          ),
        );
        _sending = false;
      });
      await _persistHistory();
      return;
    }

    try {
      final result = await sendMessageToAI(_history);
      if (!mounted) return;
      setState(() {
        if (result.reply.isNotEmpty) {
          _history.add(AiChatTurn(role: 'assistant', content: result.reply));
        }
        _messages.add(
          _ChatMessage(
            text: result.reply,
            fromUser: false,
            pendingAction: result.action,
          ),
        );
      });
      await _persistHistory();
    } on AiSubscriptionRequiredException {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SubscriptionGatePage()),
      );
      return;
    } on AiDailyLimitReachedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('aiChatDailyLimitReached'))),
      );
    } on AiAuthRequiredException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('aiChatAuthNotReady'))));
    } on AiServiceException catch (e) {
      if (!mounted) return;
      // Show the actual error reason instead of a generic failure message —
      // this makes network / region / server issues visible to the user.
      final detail = e.message.trim().isEmpty ? '' : '\n(${e.message})';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('aiChatError')}$detail'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _applyAction(int index, AiAction action) async {
    String resultKey;
    switch (action.name) {
      case 'set_coach_mode':
        resultKey = await _applyCoachMode(action.arguments);
        break;
      case 'set_medication_times':
        resultKey = await _applyMedicationTimes(action.arguments);
        break;
      case 'set_permission':
        resultKey = await _applyPermission(action.arguments);
        break;
      default:
        resultKey = 'aiChatActionFailed';
    }

    if (!mounted) return;
    setState(() {
      _messages[index] = _messages[index].resolved();
      _messages.add(_ChatMessage(text: context.t(resultKey), fromUser: false));
    });
  }

  Future<String> _applyCoachMode(Map<String, dynamic> args) async {
    final preference = args['preference'] as String?;
    if (preference == null ||
        !const ['like', 'neutral', 'dislike', 'off'].contains(preference)) {
      return 'aiChatActionFailed';
    }
    final frequency = args['frequency'] as String?;

    if (frequency != null && const ['az', 'orta', 'cok'].contains(frequency)) {
      await _storage.saveSetting(
        'duration_barrier_frequency_preference',
        frequency,
      );
    }
    await _storage.saveSetting(
      'duration_barrier_enabled',
      preference == 'off' ? '0' : '1',
    );
    return 'aiChatActionAppliedCoachMode';
  }

  Future<String> _applyMedicationTimes(Map<String, dynamic> args) async {
    final name = args['medicationName'] as String?;
    final rawTimes = args['times'];
    if (name == null || rawTimes is! List || rawTimes.isEmpty) {
      return 'aiChatActionFailed';
    }
    final times = rawTimes.whereType<String>().toList();
    if (times.isEmpty) return 'aiChatActionFailed';

    final medications = await _storage.loadMedications();
    Medication? match;
    for (final m in medications) {
      if (m.name.toLowerCase() == name.toLowerCase()) {
        match = m;
        break;
      }
    }
    if (match == null) return 'aiChatActionFailed';

    final updated = match.copyWith(times: times);
    await _storage.saveMedication(updated);
    final refreshed = await _storage.loadMedications();
    await NotificationService.scheduleMedicationReminders(refreshed);
    return 'aiChatActionAppliedMedication';
  }

  /// Android never lets an app revoke its own permission — this only ever
  /// triggers the OS request dialog. A user asking to turn one *off* is
  /// steered to Settings by the system prompt (functions/ai.js) before this
  /// is even called, so every branch here only grants.
  Future<String> _applyPermission(Map<String, dynamic> args) async {
    final permission = args['permission'] as String?;
    switch (permission) {
      case 'microphone':
        await ph.Permission.microphone.request();
        break;
      case 'location':
        final foreground = await ph.Permission.locationWhenInUse.request();
        if (foreground.isGranted) {
          await ph.Permission.locationAlways.request();
        }
        break;
      case 'activityRecognition':
        await ph.Permission.activityRecognition.request();
        break;
      case 'health':
        await HealthConnectService().requestPermissions();
        break;
      case 'usageAccess':
        await DevicePermissionService.requestUsageAccessPermission();
        break;
      default:
        return 'aiChatActionFailed';
    }
    return 'aiChatActionAppliedPermission';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('aiChatTitle'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.t('aiChatDisclaimer'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.fromUser
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: message.fromUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.text.isNotEmpty) Text(message.text),
                        if (message.pendingAction != null) ...[
                          const SizedBox(height: 8),
                          if (message.voiceSummary != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                message.voiceSummary!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton(
                                onPressed: () =>
                                    _applyAction(index, message.pendingAction!),
                                child: Text(context.t('aiChatActionApply')),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _messages[index] = message.resolved();
                                  });
                                },
                                child: Text(context.t('aiChatActionDismiss')),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _listening
                          ? context.t('aiChatListening')
                          : context.t('aiChatHint'),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: context.t('aiChatMicTooltip'),
                  child: GestureDetector(
                    onLongPressStart: _sending
                        ? null
                        : (_) => _startListening(),
                    onLongPressEnd: _sending ? null : (_) => _stopListening(),
                    child: Material(
                      color: _listening
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _listening ? Icons.mic : Icons.mic_none,
                          color: _listening
                              ? Theme.of(context).colorScheme.onError
                              : Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                  tooltip: context.t('aiChatSend'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
