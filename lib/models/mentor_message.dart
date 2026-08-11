/// A single message from the mentor persona — the user-facing voice that
/// wraps the app's coaching logic (and, for reframed violations, the
/// discipline-protocol signals) in a continuous, personalized conversation
/// rather than one-off stateless text or bare "violation recorded" alerts.
class MentorMessage {
  final String id;
  final DateTime createdAt;

  /// 'daily' | 'weekly' | 'reframed_violation'
  final String type;

  final String text;

  /// 'coach' (doing well, push a little) | 'supportive' (struggling, be
  /// gentle) | 'neutral' (not enough signal yet either way).
  final String tone;

  /// Short tap-to-answer options shown with the message (e.g. "İyiyim",
  /// "Zorlanıyorum"), if any — the lightweight, rule-based reply mechanic.
  final List<String> quickReplies;

  final bool read;

  /// The quick-reply the user tapped, if any.
  final String? userReply;

  /// A follow-up question attached after certain replies (currently just
  /// "Zorlanıyorum") — a canonical code, resolved the same way [text] is.
  /// Null until attached; never cleared back to null once set.
  final String? followUpQuestion;

  /// The answer options shown with [followUpQuestion], canonical codes like
  /// [quickReplies].
  final List<String> followUpQuickReplies;

  /// The follow-up option the user picked, if any.
  final String? followUpReply;

  const MentorMessage({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.text,
    required this.tone,
    required this.quickReplies,
    required this.read,
    this.userReply,
    this.followUpQuestion,
    this.followUpQuickReplies = const [],
    this.followUpReply,
  });

  MentorMessage copyWith({
    bool? read,
    String? userReply,
    String? followUpQuestion,
    List<String>? followUpQuickReplies,
    String? followUpReply,
  }) {
    return MentorMessage(
      id: id,
      createdAt: createdAt,
      type: type,
      text: text,
      tone: tone,
      quickReplies: quickReplies,
      read: read ?? this.read,
      userReply: userReply ?? this.userReply,
      followUpQuestion: followUpQuestion ?? this.followUpQuestion,
      followUpQuickReplies: followUpQuickReplies ?? this.followUpQuickReplies,
      followUpReply: followUpReply ?? this.followUpReply,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'text': text,
      'tone': tone,
      'quickReplies': quickReplies.join('|'),
      'read': read ? 1 : 0,
      'userReply': userReply,
      'followUpQuestion': followUpQuestion,
      'followUpQuickReplies': followUpQuickReplies.join('|'),
      'followUpReply': followUpReply,
    };
  }

  factory MentorMessage.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['quickReplies']?.toString() ?? '';
    final rawFollowUpReplies = json['followUpQuickReplies']?.toString() ?? '';
    return MentorMessage(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      type: json['type'] as String? ?? 'daily',
      text: json['text'] as String? ?? '',
      tone: json['tone'] as String? ?? 'neutral',
      quickReplies: rawReplies.isEmpty ? const [] : rawReplies.split('|'),
      read: ((json['read'] as num?)?.toInt() ?? 0) == 1,
      userReply: json['userReply'] as String?,
      followUpQuestion: json['followUpQuestion'] as String?,
      followUpQuickReplies: rawFollowUpReplies.isEmpty
          ? const []
          : rawFollowUpReplies.split('|'),
      followUpReply: json['followUpReply'] as String?,
    );
  }
}
