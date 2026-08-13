import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:speech_to_text/speech_to_text.dart';

import '../core/app_texts.dart';
import '../models/medication.dart';
import '../services/ai_service.dart';
import '../services/device_permission_service.dart';
import '../services/health_connect_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'subscription_gate_page.dart';

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromUser,
    this.pendingAction,
  });

  final String text;
  final bool fromUser;
  final AiAction? pendingAction;

  _ChatMessage resolved() =>
      _ChatMessage(text: text, fromUser: fromUser, pendingAction: null);
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
  void dispose() {
    _controller.dispose();
    if (_listening) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('aiChatMicPermissionDenied'))),
      );
      return;
    }

    _textBeforeListening = _controller.text;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final separator = _textBeforeListening.isEmpty ? '' : ' ';
        final combined =
            '$_textBeforeListening$separator${result.recognizedWords}';
        _controller.text = combined;
        _controller.selection = TextSelection.collapsed(
          offset: combined.length,
        );
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _listening = false);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _history.add(AiChatTurn(role: 'user', content: text));
      _controller.clear();
      _sending = true;
    });

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
    } on AiSubscriptionRequiredException {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SubscriptionGatePage()),
      );
      return;
    } on AiServiceException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('aiChatError'))));
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

    await _storage.saveSetting('duration_barrier_preference', preference);
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
