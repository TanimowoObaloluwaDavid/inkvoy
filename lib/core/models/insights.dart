import 'package:intl/intl.dart';

import 'reading_session.dart';

class DayTotal {
  final DateTime day;
  final int minutes;
  const DayTotal(this.day, this.minutes);
}

class ReadingStats {
  final int totalMinutes;
  final int todayMinutes;
  final int currentStreak;
  final int bestStreak;
  final List<DayTotal> last14Days;
  final int sessionsCount;

  const ReadingStats({
    this.totalMinutes = 0,
    this.todayMinutes = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.last14Days = const [],
    this.sessionsCount = 0,
  });

  bool get isZero => totalMinutes == 0 && sessionsCount == 0;

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  factory ReadingStats.compute(List<ReadingSession> sessions, {DateTime? now}) {
    final today = _startOfDay(now ?? DateTime.now());
    final buckets = <String, int>{};
    final byDay = <DateTime, int>{};
    int total = 0;
    for (final s in sessions) {
      if (s.minutes <= 0) continue;
      total += s.minutes;
      final day = _startOfDay(s.day);
      byDay[day] = (byDay[day] ?? 0) + s.minutes;
      buckets[s.dayKey] = (buckets[s.dayKey] ?? 0) + s.minutes;
    }

    // Consecutive-day streak: a gap of one day is forgiven while it is still "today".
    var streak = 0;
    var cursor = today;
    if ((byDay[cursor] ?? 0) == 0) cursor = cursor.subtract(const Duration(days: 1));
    while (byDay.containsKey(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var best = 0;
    final days = byDay.keys.toList()..sort();
    if (days.isNotEmpty) {
      var run = 1;
      for (var i = 1; i < days.length; i++) {
        final diff = days[i].difference(days[i - 1]).inDays;
        run = diff == 1 ? run + 1 : (diff == 2 ? run + 1 : 1);
        // diff==2 keeps runs alive across a short break; simple and generous.
        if (run > best) best = run;
      }
      best = best > 1 ? best : 1;
    }

    final last14 = <DayTotal>[];
    for (var i = 13; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      last14.add(DayTotal(d, byDay[d] ?? 0));
    }

    return ReadingStats(
      totalMinutes: total,
      todayMinutes: byDay[today] ?? 0,
      currentStreak: streak,
      bestStreak: best,
      last14Days: last14,
      sessionsCount: sessions.length,
    );
  }

  static String formatMinutes(int m) {
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}m';
  }

  static String formatDay(DateTime d) => DateFormat.E().format(d); // Mon, Tue...
}