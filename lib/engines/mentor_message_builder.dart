import '../models/mentor_message.dart';

/// Turns the app's existing coaching signals (risk score, risky hours,
/// recent task success rate, week-over-week smoking-event patterns) into a
/// single personalized [MentorMessage] — the mentor's "voice" — instead of
/// the stateless one-off command strings [MentorEngine] otherwise produces.
///
/// Tone adapts to how the user has been doing recently rather than being
/// fixed: a high recent success rate gets a coach-like nudge, a low one
/// gets a gentler, more supportive message, and anything in between stays
/// neutral. This is a deliberately simple, rule-based, fully-offline
/// implementation — see the "AI-backed replies" tier discussion for a
/// future richer alternative gated behind the top payment tier.
class MentorMessageBuilder {
  static const List<String> _dayParts = [
    'morning',
    'afternoon',
    'evening',
    'night',
  ];

  String _tone(double recentSuccessRate) {
    if (recentSuccessRate >= 0.7) {
      return 'coach';
    }
    if (recentSuccessRate <= 0.4) {
      return 'supportive';
    }
    return 'neutral';
  }

  MentorMessage buildDailyMessage({
    required int riskScore,
    required double recentSuccessRate,
    required List<String> riskyHours,
    String? historicalNote,
    String breathTrend = 'stable',
    DateTime? now,
  }) {
    final tone = _tone(recentSuccessRate);
    final timestamp = now ?? DateTime.now();

    final buffer = StringBuffer();
    switch (tone) {
      case 'coach':
        buffer.write(
          'Bu ara gerçekten iyi gidiyorsun. ',
        );
        if (riskyHours.isNotEmpty) {
          buffer.write(
            'Bugün özellikle ${riskyHours.first} aralığına dikkat et, gerisini zaten götürüyorsun.',
          );
        } else {
          buffer.write('Bu tempoyu koruyalım.');
        }
        break;
      case 'supportive':
        buffer.write(
          'Son günler senin için kolay geçmiyor gibi görünüyor, bunu görüyorum. ',
        );
        buffer.write(
          'Bugün mükemmel olması gerekmiyor — sadece bir sonraki anı atlatmaya odaklan.',
        );
        break;
      default:
        buffer.write('Bugün nasıl gidiyor? ');
        if (riskyHours.isNotEmpty) {
          buffer.write('${riskyHours.first} aralığında yanındayım.');
        }
    }

    if (breathTrend == 'improving') {
      buffer.write(
        ' Son nefes testlerin de iyiye gidiyor, bunu fark ettim — devam et.',
      );
    }

    if (historicalNote != null && historicalNote.isNotEmpty) {
      buffer.write('\n\n$historicalNote');
    }

    final quickReplies = tone == 'supportive'
        ? const ['İyiyim', 'Zorlanıyorum', 'Konuşmak istemiyorum']
        : const ['İyiyim', 'Zorlanıyorum'];

    return MentorMessage(
      id: 'mentor_daily_${timestamp.millisecondsSinceEpoch}',
      createdAt: timestamp,
      type: 'daily',
      text: buffer.toString(),
      tone: tone,
      quickReplies: quickReplies,
      read: false,
    );
  }

  MentorMessage buildWeeklyMessage({
    required int weeklyRiskScore,
    required String weeklyRiskLevel,
    required double recentSuccessRate,
    required int completedTasksThisWeek,
    String? historicalNote,
    DateTime? now,
  }) {
    final tone = _tone(recentSuccessRate);
    final timestamp = now ?? DateTime.now();

    final buffer = StringBuffer();
    switch (tone) {
      case 'coach':
        buffer.write(
          'Bu hafta gerçekten güçlüydün — $completedTasksThisWeek görevi tamamladın. Bu ivmeyi haftaya da taşıyalım.',
        );
        break;
      case 'supportive':
        buffer.write(
          'Bu hafta zorlu geçti, farkındayım. Sayılar önemli değil şu an — önemli olan hâlâ burada olman.',
        );
        break;
      default:
        buffer.write(
          'Bu haftaki risk seviyen: $weeklyRiskLevel. Detaylı bir haftalık anketle daha net bir resim çıkarabiliriz.',
        );
    }

    if (historicalNote != null && historicalNote.isNotEmpty) {
      buffer.write('\n\n$historicalNote');
    }

    return MentorMessage(
      id: 'mentor_weekly_${timestamp.millisecondsSinceEpoch}',
      createdAt: timestamp,
      type: 'weekly',
      text: buffer.toString(),
      tone: tone,
      quickReplies: const ['Haftalık anketi doldur', 'Daha sonra'],
      read: false,
    );
  }

  /// Builds a "geçen hafta X zamanları zorlanmıştın, bu hafta nasıl?" style
  /// callback by comparing which part of the day smoking events clustered
  /// in last week versus this week. Returns null when there isn't enough
  /// data yet to say anything meaningful — a quiet mentor beats a wrong one.
  String? buildHistoricalNote({
    required Map<String, int> lastWeekDayPartCounts,
    required Map<String, int> thisWeekDayPartCounts,
  }) {
    final lastWeekTotal = lastWeekDayPartCounts.values.fold(0, (a, b) => a + b);
    if (lastWeekTotal < 3) {
      // Too little history to draw any pattern from.
      return null;
    }

    String? dominantPart;
    var dominantCount = 0;
    for (final part in _dayParts) {
      final count = lastWeekDayPartCounts[part] ?? 0;
      if (count > dominantCount) {
        dominantCount = count;
        dominantPart = part;
      }
    }
    if (dominantPart == null || dominantCount < 2) {
      return null;
    }

    final thisWeekCount = thisWeekDayPartCounts[dominantPart] ?? 0;
    final label = _dayPartLabel(dominantPart);

    if (thisWeekCount == 0) {
      return 'Geçen hafta $label zorlanmıştın — bu hafta o saatlerde hiç kayıt yok, harika gidiyor.';
    }
    if (thisWeekCount >= dominantCount) {
      return 'Geçen hafta $label zorlanmıştın, bu hafta da benzer görünüyor. Birlikte bu saatlere özel bir plan yapalım mı?';
    }
    return 'Geçen hafta $label zorlanmıştın, bu hafta biraz daha iyi görünüyorsun.';
  }

  String _dayPartLabel(String part) {
    switch (part) {
      case 'morning':
        return 'sabahları';
      case 'afternoon':
        return 'öğleden sonraları';
      case 'evening':
        return 'akşamları';
      case 'night':
        return 'geceleri';
      default:
        return part;
    }
  }

  /// Reframes a protocol-violation event (logged by
  /// `ProtocolViolationService`) as a supportive mentor message instead of
  /// a bare "violation recorded" alert — the discipline-protocol machinery
  /// keeps running underneath, but the user-facing voice is the mentor's.
  MentorMessage? buildReframedViolationMessage({
    required String violationType,
    String? taskTitle,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    String text;
    String tone;
    List<String> quickReplies = const [];

    switch (violationType) {
      case 'suspicious_behavior':
        text =
            'Az önce bir şeyler ters gitmiş gibi göründü${taskTitle != null ? " (\"$taskTitle\" sırasında)" : ""}. İyi misin? İstersen birlikte kısa bir nefes molası verelim.';
        tone = 'supportive';
        quickReplies = const ['İyiyim', 'Konuşalım'];
        break;
      case 'willpower_weakness':
      case 'followup_failed':
        text =
            'Bu sefer olmadı, sorun değil — bu bir başarısızlık değil, sürecin bir parçası. Yarın yeniden deneriz.';
        tone = 'supportive';
        quickReplies = const ['Teşekkürler'];
        break;
      case 'deferred_start':
        text =
            'Şimdi uygun değilse anlıyorum, 10 dakika sonra tekrar hatırlatacağım.';
        tone = 'neutral';
        break;
      case 'followup_deferred':
        text = 'Tamam, biraz sonra tekrar soracağım.';
        tone = 'neutral';
        break;
      case 'duration_barrier_failure':
        text =
            'Bu hedef sana göre biraz uzun geldi sanırım. Bir dahaki sefere daha kısa bir süreyle başlayalım — küçük adımlar da ilerlemedir.';
        tone = 'supportive';
        quickReplies = const ['Tamam'];
        break;
      case 'fake_call_avoided':
        text =
            'Son zamanlarda molaları hep erteliyorsun gibi görünüyor. Şu an uygun olmadığını biliyorum — istersen bir dahaki seferde süreyi birlikte kısaltalım.';
        tone = 'supportive';
        quickReplies = const ['Konuşalım', 'İyiyim'];
        break;
      default:
        return null;
    }

    return MentorMessage(
      id: 'mentor_reframe_${timestamp.microsecondsSinceEpoch}',
      createdAt: timestamp,
      type: 'reframed_violation',
      text: text,
      tone: tone,
      quickReplies: quickReplies,
      read: false,
    );
  }

  /// Buckets an hour-of-day (0-23) into a day part, matching the labels
  /// used by [buildHistoricalNote].
  static String dayPartForHour(int hour) {
    if (hour >= 5 && hour < 11) {
      return 'morning';
    }
    if (hour >= 11 && hour < 17) {
      return 'afternoon';
    }
    if (hour >= 17 && hour < 22) {
      return 'evening';
    }
    return 'night';
  }
}
