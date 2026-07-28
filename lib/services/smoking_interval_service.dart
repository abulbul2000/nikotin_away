import 'dart:math';

/// A half-open clock range, in minutes from midnight. [end] may exceed 1440
/// when the range wraps past midnight (a 23:00–07:00 sleep window is
/// 1380–1860), which keeps overlap arithmetic on one number line.
class _Range {
  final int start;
  final int end;

  const _Range(this.start, this.end);

  int get length => end - start;

  /// How much of this range overlaps [other], counting the copy of [other]
  /// shifted a day forward too so a wrapped range still matches.
  int overlapWith(_Range other) {
    var total = 0;
    for (final shift in const [-1440, 0, 1440]) {
      final s = max(start, other.start + shift);
      final e = min(end, other.end + shift);
      if (e > s) {
        total += e - s;
      }
    }
    return total;
  }
}

/// The inputs the barrier length is derived from. Plain values rather than a
/// storage handle, so the arithmetic stays pure and testable.
class SmokingWindowInput {
  final String wakeTime; // "07:00"
  final String sleepTime; // "23:00"
  final String? workStart;
  final String? workEnd;

  /// The survey's own wording: 'Evet', 'Hayır' or 'Sadece molalarda'.
  final String? workplaceRule;

  /// Smoking breaks during the workday, as (start, end) clock strings.
  final List<(String, String)> breaks;

  final int dailyCigarettes;

  const SmokingWindowInput({
    required this.wakeTime,
    required this.sleepTime,
    required this.dailyCigarettes,
    this.workStart,
    this.workEnd,
    this.workplaceRule,
    this.breaks = const [],
  });
}

/// Works out how often the user actually smokes, and how long the next
/// no-smoking barrier should be.
///
/// The whole programme is reduction rather than abrupt quitting, so the
/// barrier is anchored to the user's real habit instead of an arbitrary
/// ladder: measure the gap they currently leave between cigarettes, ask for
/// slightly more than that, then stretch it week by week. A barrier shorter
/// than the natural gap asks for nothing; one far above it just fails.
class SmokingIntervalService {
  /// How much longer than the measured gap the first barrier is. Small enough
  /// to be achievable on day one, large enough that it isn't a no-op — at
  /// this ratio a 20-a-day habit has room for about 16.
  static const double startingMultiplier = 1.25;

  /// Weekly step, up and down alike. Applied to the barrier, so its effect on
  /// cigarettes-per-day compounds the same way in both directions.
  static const double weeklyStep = 0.15;

  static const int minDailyTasks = 4;
  static const int maxDailyTasks = 8;

  /// A barrier shorter than this isn't worth issuing as a task.
  static const int minBarrierMinutes = 10;

  final Random _random;

  SmokingIntervalService({Random? random}) : _random = random ?? Random();

  /// Minutes from midnight, or null when unparseable.
  static int? _clockToMinutes(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^\s*(\d{1,2})[:.](\d{2})').firstMatch(raw.trim());
    if (match == null) return null;
    final h = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return h * 60 + m;
  }

  static _Range? _rangeOf(String? from, String? to) {
    final start = _clockToMinutes(from);
    final end = _clockToMinutes(to);
    if (start == null || end == null) return null;
    // Wrapped (night shift, or a sleep window crossing midnight).
    return _Range(start, end > start ? end : end + 1440);
  }

  /// The stretch of the day the user is awake.
  int awakeMinutes(SmokingWindowInput input) {
    final awake = _rangeOf(input.wakeTime, input.sleepTime);
    if (awake == null || awake.length <= 0) {
      return 16 * 60; // sensible default rather than a divide-by-zero later
    }
    return awake.length;
  }

  /// The stretch of the day the user could actually smoke in.
  ///
  /// Sleep is always out. Work is out too when the workplace forbids it —
  /// except for the breaks, which are added back, since a break at a
  /// smoke-free workplace is exactly when people step outside for one.
  int availableSmokingMinutes(SmokingWindowInput input) {
    final awake = _rangeOf(input.wakeTime, input.sleepTime);
    if (awake == null || awake.length <= 0) {
      return 16 * 60;
    }

    var available = awake.length;
    final rule = input.workplaceRule?.trim().toLowerCase();
    final smokingBannedAtWork = rule == 'hayır' ||
        rule == 'hayir' ||
        rule == 'no' ||
        rule == 'sadece molalarda' ||
        rule == 'only breaks';

    if (smokingBannedAtWork) {
      final work = _rangeOf(input.workStart, input.workEnd);
      if (work != null && work.length > 0) {
        available -= awake.overlapWith(work);

        // 'Sadece molalarda' means the breaks are the exception, so hand
        // that time back. Clamped to the work overlap so a mis-entered break
        // outside working hours can't inflate the window.
        if (rule == 'sadece molalarda' || rule == 'only breaks') {
          for (final (from, to) in input.breaks) {
            final b = _rangeOf(from, to);
            if (b == null || b.length <= 0) continue;
            available += min(b.overlapWith(work), b.overlapWith(awake));
          }
        }
      }
    }

    // Never claim less than an hour: a survey saying the user works every
    // waking hour at a smoke-free site would otherwise leave nothing to
    // divide by.
    return max(60, available);
  }

  /// The gap the user currently leaves between cigarettes.
  int naturalIntervalMinutes(SmokingWindowInput input) {
    final cigarettes = input.dailyCigarettes;
    if (cigarettes <= 0) {
      return availableSmokingMinutes(input);
    }
    return max(1, (availableSmokingMinutes(input) / cigarettes).round());
  }

  /// Where a brand-new user starts: a little above their own habit.
  int startingBarrierMinutes(SmokingWindowInput input) {
    final natural = naturalIntervalMinutes(input);
    return max(minBarrierMinutes, (natural * startingMultiplier).round());
  }

  /// The barrier for the coming week.
  ///
  /// Symmetric by design: a bad week pulls back by as much as a good one
  /// pushes forward. Holding position instead would leave someone who is
  /// struggling facing the same demand that just beat them, week after week,
  /// which is how people quit the app rather than smoking.
  int evolveWeeklyBarrierMinutes({
    required int currentMinutes,
    required bool goodWeek,
  }) {
    final factor = goodWeek ? (1 + weeklyStep) : (1 - weeklyStep);
    return max(minBarrierMinutes, (currentMinutes * factor).round());
  }

  /// Whether the week earns an increase.
  ///
  /// Both halves have to hold. Task success alone is blind to the cigarettes
  /// smoked between tasks; the logged count alone rewards someone who simply
  /// stopped logging. Requiring both means the barrier only grows on evidence
  /// from two independent directions — and when logs are absent entirely
  /// (rather than zero), success rate is all there is to go on.
  bool isGoodWeek({
    required int? loggedCigarettes,
    required int targetCigarettes,
    required double taskSuccessRate,
    double successThreshold = 0.6,
  }) {
    final tasksWentWell = taskSuccessRate >= successThreshold;
    if (loggedCigarettes == null) {
      return tasksWentWell;
    }
    return tasksWentWell && loggedCigarettes <= targetCigarettes;
  }

  /// How many cigarettes a day the current barrier implies, used as the
  /// target [isGoodWeek] measures the logged count against.
  int impliedDailyTarget({
    required SmokingWindowInput input,
    required int barrierMinutes,
  }) {
    if (barrierMinutes <= 0) return input.dailyCigarettes;
    final available = availableSmokingMinutes(input);
    return max(0, (available / barrierMinutes).floor());
  }

  /// How many tasks to issue today.
  ///
  /// Scaled off waking hours so a 12-hour day isn't handed the same load as
  /// an 18-hour one, nudged by how the user has been coping, and jittered so
  /// the count itself doesn't become predictable. Clamped to 4–8: fewer stops
  /// feeling like a programme, more feels like harassment.
  int dailyTaskCount({
    required SmokingWindowInput input,
    required double movingSuccessRate,
    required double movingFailureRate,
    required double postponeRate,
  }) {
    var count = (awakeMinutes(input) / 144).round(); // ~2.4h per task

    if (movingSuccessRate >= 0.75) count += 1;
    if (movingSuccessRate >= 0.88) count += 1;
    if (movingFailureRate >= 0.45) count -= 1;
    if (postponeRate >= 0.5) count -= 1;

    count += _random.nextInt(3) - 1;
    return count.clamp(minDailyTasks, maxDailyTasks);
  }
}
