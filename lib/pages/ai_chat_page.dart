import 'dart:convert';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
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
import '../services/tts_voice_selector.dart';
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

class _ChatConversation {
  _ChatConversation({
    required this.id,
    required this.title,
    required List<AiChatTurn> turns,
    this.pinned = false,
    this.project,
  }) : turns = List<AiChatTurn>.from(turns);

  final String id;
  String title;
  final List<AiChatTurn> turns;
  bool pinned;
  String? project;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'turns': turns.map((turn) => turn.toJson()).toList(growable: false),
    'pinned': pinned,
    if (project != null && project!.trim().isNotEmpty) 'project': project,
  };

  static _ChatConversation? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final rawTurns = raw['turns'];
    if (id is! String || title is! String || rawTurns is! List) return null;
    final turns = <AiChatTurn>[];
    for (final item in rawTurns) {
      if (item is! Map) continue;
      final role = item['role'];
      final content = item['content'];
      if ((role == 'user' || role == 'assistant') && content is String) {
        turns.add(AiChatTurn(role: role, content: content));
      }
    }
    return _ChatConversation(
      id: id,
      title: title,
      turns: turns,
      pinned: raw['pinned'] == true,
      project: raw['project'] is String ? raw['project'] as String : null,
    );
  }
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
  final List<_ChatConversation> _conversations = [];
  final StorageService _storage = StorageService();
  String? _activeConversationId;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sending = false;
  bool _listening = false;
  String _textBeforeListening = '';

  @override
  void initState() {
    super.initState();
    _configureTts();
    _loadSavedHistory();
  }

  Future<void> _configureTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (error) {
      debugPrint('[AIChat] TTS setup failed: $error');
    }
  }

  String _ttsLanguageTag(String code) {
    const regions = <String, String>{
      'tr': 'TR', 'en': 'US', 'de': 'DE', 'ar': 'SA', 'fr': 'FR',
      'es': 'ES', 'pt': 'BR', 'it': 'IT', 'pl': 'PL', 'ru': 'RU',
      'ja': 'JP', 'zh': 'CN', 'ko': 'KR', 'hi': 'IN', 'bn': 'BD',
      'pa': 'IN', 'te': 'IN', 'mr': 'IN', 'ta': 'IN', 'gu': 'IN',
      'kn': 'IN', 'ml': 'IN', 'th': 'TH', 'vi': 'VN', 'id': 'ID',
      'ms': 'MY', 'fil': 'PH', 'uk': 'UA', 'ro': 'RO', 'el': 'GR',
      'hu': 'HU', 'cs': 'CZ', 'sv': 'SE', 'da': 'DK', 'no': 'NO',
      'fi': 'FI', 'nl': 'NL', 'be': 'BY', 'sr': 'RS', 'hr': 'HR',
    };
    final normalized = code.toLowerCase();
    return '$normalized-${regions[normalized] ?? normalized.toUpperCase()}';
  }

  Future<void> _speakAssistantReply(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !mounted) return;
    try {
      final languageCode = await LanguageService.loadSelectedLanguageCode();
      final locale = _ttsLanguageTag(languageCode);
      await _tts.setLanguage(locale);
      await configureBestVoice(
        _tts,
        locale: locale,
        preferLocalVoice: false,
      );
      await _tts.stop();
      await _tts.speak(trimmed);
    } catch (error) {
      // TTS is optional and must never block text chat.
      debugPrint('[AIChat] TTS reply failed: $error');
    }
  }

  Future<void> _loadSavedHistory() async {
    try {
      final rawConversations = await _storage.loadSetting(
        'ai_chat_conversations_v1',
      );
      if (rawConversations != null && rawConversations.trim().isNotEmpty) {
        final decoded = jsonDecode(rawConversations);
        if (decoded is List) {
          _conversations
            ..clear()
            ..addAll(
              decoded
                  .map(_ChatConversation.fromJson)
                  .whereType<_ChatConversation>(),
            );
        }
      }

      // Migrate the previous single-history format into one conversation.
      if (_conversations.isEmpty) {
        final legacy = await _storage.loadSetting('ai_chat_history_v1');
        if (legacy != null && legacy.trim().isNotEmpty) {
          final decoded = jsonDecode(legacy);
          final turns = <AiChatTurn>[];
          if (decoded is List) {
            for (final item in decoded) {
              if (item is! Map) continue;
              final role = item['role'];
              final content = item['content'];
              if ((role == 'user' || role == 'assistant') && content is String) {
                turns.add(AiChatTurn(role: role, content: content));
              }
            }
          }
          if (turns.isNotEmpty) {
            _conversations.add(
              _ChatConversation(
                id: 'chat_${DateTime.now().microsecondsSinceEpoch}',
                title: _conversationTitle(turns),
                turns: turns,
              ),
            );
          }
        }
      }

      if (!mounted) return;
      if (_conversations.isNotEmpty) {
        _conversations.sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return 0;
        });
        _selectConversation(_conversations.first, notify: false);
      }
      await _persistConversations();
    } catch (error) {
      debugPrint('[AIChat] saved conversation restore failed: $error');
    }
  }

  String _conversationTitle(List<AiChatTurn> turns) {
    final firstUser = turns.firstWhere(
      (turn) => turn.role == 'user' && turn.content.trim().isNotEmpty,
      orElse: () => const AiChatTurn(role: 'assistant', content: ''),
    );
    final text = firstUser.content.trim();
    if (text.isEmpty) return 'Yeni sohbet';
    return text.length > 30 ? '${text.substring(0, 30)}…' : text;
  }

  Future<void> _persistConversations() async {
    try {
      final payload = _conversations
          .take(30)
          .map((conversation) => conversation.toJson())
          .toList(growable: false);
      await _storage.saveSetting(
        'ai_chat_conversations_v1',
        jsonEncode(payload),
      );
    } catch (error) {
      debugPrint('[AIChat] conversation write failed: $error');
    }
  }

  void _selectConversation(_ChatConversation conversation, {bool notify = true}) {
    void apply() {
      _activeConversationId = conversation.id;
      _history
        ..clear()
        ..addAll(conversation.turns);
      _messages
        ..clear()
        ..addAll(
          conversation.turns.map(
            (turn) => _ChatMessage(
              text: turn.content,
              fromUser: turn.role == 'user',
            ),
          ),
        );
    }
    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _newConversation() async {
    final conversation = _ChatConversation(
      id: 'chat_${DateTime.now().microsecondsSinceEpoch}',
      title: context.t('aiChatNewConversation'),
      turns: const [],
    );
    setState(() {
      _conversations.insert(0, conversation);
      _selectConversation(conversation, notify: false);
    });
    await _persistConversations();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _persistHistory() async {
    final activeId = _activeConversationId;
    if (activeId == null) return;
    final conversation = _conversations.cast<_ChatConversation?>().firstWhere(
      (item) => item?.id == activeId,
      orElse: () => null,
    );
    if (conversation == null) return;
    conversation.turns
      ..clear()
      ..addAll(
        _history.length > 40 ? _history.sublist(_history.length - 40) : _history,
      );
    conversation.title = _conversationTitle(conversation.turns);
    await _persistConversations();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_listening) {
      _speech.stop();
    }
    _tts.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_listening || _sending) return;

    final microphoneStatus = await ph.Permission.microphone.request();
    if (!microphoneStatus.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('aiChatMicPermissionDenied')),
          action: SnackBarAction(
            label: 'Ayarlar',
            onPressed: () => ph.openAppSettings(),
          ),
        ),
      );
      return;
    }

    // Re-initialize in case the service was stopped after a previous failure.
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _listening = false);
        }
      },
      onError: (error) {
        debugPrint('SpeechToText error: ${error.errorMsg}');
        if (!mounted) return;
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mikrofon kullanılamadı: ${error.errorMsg}')),
        );
      },
    ).timeout(const Duration(seconds: 10), onTimeout: () => false);
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('aiChatMicUnavailable')),
          action: SnackBarAction(
            label: 'Ayarlar',
            onPressed: () => ph.openAppSettings(),
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
    if (!mounted) return;
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
        // A short pause ended recognition while users were still speaking.
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 8),
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
        final userCredential = await auth.FirebaseAuth.instance
            .signInAnonymously()
            .timeout(const Duration(seconds: 15));
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

    if (_activeConversationId == null) {
      final conversation = _ChatConversation(
        id: 'chat_${DateTime.now().microsecondsSinceEpoch}',
        title: context.t('aiChatNewConversation'),
        turns: const [],
      );
      _conversations.insert(0, conversation);
      _selectConversation(conversation, notify: false);
    }

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
      final result = await sendMessageToAI(_history).timeout(
        const Duration(seconds: 30),
      );
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
      await _speakAssistantReply(result.reply);
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
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.t('aiChatError')}\nSunucu zamanında yanıt vermedi. İnternet bağlantını ve Firebase kurulumunu kontrol et.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[AIChat] unexpected send failure: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.t('aiChatError')}\nBeklenmeyen hata: $error',
          ),
          duration: const Duration(seconds: 6),
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

  String _conversationShareText(_ChatConversation conversation) {
    final buffer = StringBuffer('${conversation.title}\n\n');
    for (final turn in conversation.turns) {
      final speaker = turn.role == 'user' ? 'You' : 'AI';
      buffer.writeln('$speaker: ${turn.content}');
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  Future<void> _togglePinned(_ChatConversation conversation) async {
    setState(() => conversation.pinned = !conversation.pinned);
    _conversations.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return 0;
    });
    await _persistConversations();
  }

  Future<void> _renameConversation(_ChatConversation conversation) async {
    final controller = TextEditingController(text: conversation.title);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('aiChatRenameTitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: context.t('aiChatRenameTitle')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('aiChatMenuCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    setState(() => conversation.title = name);
    await _persistConversations();
  }

  Future<void> _shareConversation(_ChatConversation conversation) async {
    final text = _conversationShareText(conversation);
    await SharePlus.instance.share(
      ShareParams(text: text, subject: conversation.title),
    );
  }

  Future<void> _copyConversation(_ChatConversation conversation) async {
    final copy = _ChatConversation(
      id: 'chat_${DateTime.now().microsecondsSinceEpoch}',
      title: '${conversation.title} (Copy)',
      turns: conversation.turns,
      project: conversation.project,
    );
    setState(() {
      _conversations.insert(0, copy);
      _selectConversation(copy, notify: false);
    });
    await _persistConversations();
  }

  Future<void> _showConversationSummary(_ChatConversation conversation) async {
    final userTurn = conversation.turns.cast<AiChatTurn?>().firstWhere(
      (turn) => turn?.role == 'user' && turn!.content.trim().isNotEmpty,
      orElse: () => null,
    );
    final assistantTurn = conversation.turns.cast<AiChatTurn?>().lastWhere(
      (turn) => turn?.role == 'assistant' && turn!.content.trim().isNotEmpty,
      orElse: () => null,
    );
    final content = conversation.turns.isEmpty
        ? context.t('aiChatSummaryEmpty')
        : 'Messages: ${conversation.turns.length}\\n\\n'
            'First question: ${userTurn?.content ?? '-'}\\n\\n'
            'Latest mentor response: ${assistantTurn?.content ?? '-'}';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('aiChatSummaryTitle')),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(content)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(context.t('aiChatMenuCopy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('aiChatMenuCancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _moveConversationToProject(_ChatConversation conversation) async {
    final controller = TextEditingController(text: conversation.project ?? '');
    final project = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('aiChatProjectTitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(hintText: context.t('aiChatProjectHint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('aiChatMenuCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (project == null || project.isEmpty) return;
    setState(() => conversation.project = project);
    await _persistConversations();
  }

  Future<void> _reportConversation(_ChatConversation conversation) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('aiChatReportTitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: context.t('aiChatReportHint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('aiChatMenuCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.t('aiChatMenuReport')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || reason == null || reason.isEmpty) return;
    await _storage.saveSetting(
      'ai_chat_report_${conversation.id}',
      jsonEncode({'conversation': conversation.title, 'reason': reason, 'createdAt': DateTime.now().toIso8601String()}),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('aiChatReportTitle'))));
  }

  Future<void> _deleteConversation(_ChatConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('aiChatMenuDelete')),
        content: Text(context.t('aiChatDeleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('aiChatMenuCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('aiChatMenuDelete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _conversations.removeWhere((item) => item.id == conversation.id);
      if (_activeConversationId == conversation.id) {
        if (_conversations.isNotEmpty) {
          _selectConversation(_conversations.first, notify: false);
        } else {
          _activeConversationId = null;
          _history.clear();
          _messages.clear();
        }
      }
    });
    await _persistConversations();
  }

  Future<void> _showConversationMenu(
    _ChatConversation conversation,
    BuildContext rowContext,
  ) async {
    final rowBox = rowContext.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (rowBox == null || overlayBox == null) return;
    final topLeft = rowBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      overlayBox.size.width - topLeft.dx - rowBox.size.width,
      overlayBox.size.height - topLeft.dy - rowBox.size.height,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [
        PopupMenuItem(value: 'pin', child: _menuItem(Icons.push_pin_outlined, context.t(conversation.pinned ? 'aiChatMenuUnpin' : 'aiChatMenuPin'))),
        PopupMenuItem(value: 'rename', child: _menuItem(Icons.edit_outlined, context.t('aiChatMenuRename'))),
        PopupMenuItem(value: 'invite', child: _menuItem(Icons.group_add_outlined, context.t('aiChatMenuInvite'))),
        PopupMenuItem(value: 'copy', child: _menuItem(Icons.copy_outlined, context.t('aiChatMenuCopy'))),
        PopupMenuItem(value: 'summary', child: _menuItem(Icons.summarize_outlined, context.t('aiChatMenuSummary'))),
        PopupMenuItem(value: 'move', child: _menuItem(Icons.folder_outlined, context.t('aiChatMenuMove'))),
        PopupMenuItem(value: 'report', child: _menuItem(Icons.report_outlined, context.t('aiChatMenuReport'))),
        PopupMenuItem(
          value: 'delete',
          child: _menuItem(Icons.delete_outline, context.t('aiChatMenuDelete'), destructive: true),
        ),
      ],
    );
    switch (action) {
      case 'pin':
        await _togglePinned(conversation);
        break;
      case 'rename':
        await _renameConversation(conversation);
        break;
      case 'invite':
        await _shareConversation(conversation);
        break;
      case 'copy':
        await _copyConversation(conversation);
        break;
      case 'summary':
        await _showConversationSummary(conversation);
        break;
      case 'move':
        await _moveConversationToProject(conversation);
        break;
      case 'report':
        await _reportConversation(conversation);
        break;
      case 'delete':
        await _deleteConversation(conversation);
        break;
    }
  }

  Widget _menuItem(IconData icon, String label, {bool destructive = false}) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  Widget _buildConversationDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(context.t('aiChatTitle')),
              subtitle: Text(context.t('aiChatHistory')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _newConversation,
                  icon: const Icon(Icons.add),
                  label: Text(context.t('aiChatNewConversation')),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _conversations.isEmpty
                  ? Center(child: Text(context.t('aiChatNoConversations')))
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        final selected = conversation.id == _activeConversationId;
                        return ListTile(
                          selected: selected,
                          leading: Icon(
                            conversation.pinned
                                ? Icons.push_pin
                                : selected
                                    ? Icons.chat
                                    : Icons.chat_bubble_outline,
                          ),
                          title: Text(
                            conversation.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            context
                                .t('aiChatMessageCount')
                                .replaceFirst('{count}', '${conversation.turns.length}'),
                          ),
                          onTap: () {
                            _selectConversation(conversation);
                            Navigator.of(context).pop();
                          },
                          onLongPress: () => _showConversationMenu(conversation, context),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: _buildConversationDrawer(context),
      appBar: AppBar(title: Text(context.t('aiChatTitle'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.t('aiChatDisclaimer'),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
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
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHigh,
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
                  child: IconButton.filled(
                    onPressed: _sending
                        ? null
                        : () => _listening
                            ? _stopListening()
                            : _startListening(),
                    style: IconButton.styleFrom(
                      backgroundColor: _listening
                          ? colorScheme.error
                          : colorScheme.primary,
                      foregroundColor: _listening
                          ? colorScheme.onError
                          : colorScheme.onPrimary,
                      shape: const CircleBorder(),
                    ),
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
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
