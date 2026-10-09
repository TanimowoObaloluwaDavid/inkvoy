import 'package:flutter_test/flutter_test.dart';
import 'package:inkvoy/core/models/book.dart';
import 'package:inkvoy/core/models/insights.dart';
import 'package:inkvoy/core/models/reading_session.dart';

void main() {
  group('Book', () {
    test('round-trips through JSON', () {
      const original = Book(
        key: '/works/OL123W',
        title: 'Pride and Prejudice',
        author: 'Jane Austen',
        firstPublishYear: 1813,
        coverI: 12345,
        editionCount: 500,
        ratingCount: 1200,
      );
      final decoded = Book.decode(original.encode());
      expect(decoded, original);
    });

    test('maps Open Library search JSON', () {
      final b = Book.fromSearchJson({
        'key': 'OL1W',
        'title': 'The Hobbit',
        'author_name': ['J. R. R. Tolkien'],
        'first_publish_year': 1937,
        'cover_i': 9,
        'ratings_average': 4.5,
        'ratings_count': 5000,
      });
      expect(b.key, '/OL1W');
      expect(b.title, 'The Hobbit');
      expect(b.author, 'J. R. R. Tolkien');
      expect(b.coverI, 9);
      expect(b.rating, 4.5);
      expect(b.ratingCount, 5000);
    });

    test('normaliizes keys without a leading slash', () {
      final b = Book.fromSubjectJson({'key': 'work/OL1W', 'title': 'X'});
      expect(b.key, '/work/OL1W');
    });
  });

  group('ReadingStats.compute', () {
    ReadingSession session(String id, DateTime day, int minutes) => ReadingSession(
          id: id,
          bookKey: '/works/OL$id',
          bookTitle: 'Book $id',
          start: day,
          end: day.add(Duration(minutes: minutes)),
        );

    test('totals minutes and counts sessions', () {
      final now = DateTime(2026, 9, 7, 12);
      final stats = ReadingStats.compute([
        session('a', DateTime(2026, 9, 7, 9), 30),
        session('b', DateTime(2026, 9, 6, 9), 45),
      ], now: now);

      expect(stats.totalMinutes, 75);
      expect(stats.todayMinutes, 30);
      expect(stats.sessionsCount, 2);
      expect(stats.currentStreak, 2);
    });

    test('computes a best streak with a short break', () {
      final now = DateTime(2026, 9, 7, 12);
      final days = [
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 6),
        DateTime(2026, 9, 4),
        DateTime(2026, 9, 3),
        DateTime(2026, 9, 2),
      ];
      final stats = ReadingStats.compute(days.map((d) => session(d.day.toString(), d.add(const Duration(hours: 9)), 15)).toList(), now: now);
      // Sep 2,3,4 then 6,7 read; Sep 5 missed (forgiven) -> 5-day run; streak to today = 2.
      expect(stats.currentStreak, 2);
      expect(stats.bestStreak, 5);
    });

    test('formats minutes readably', () {
      expect(ReadingStats.formatMinutes(0), '0m');
      expect(ReadingStats.formatMinutes(45), '45m');
      expect(ReadingStats.formatMinutes(60), '1h');
      expect(ReadingStats.formatMinutes(90), '1h 30m');
    });
  });
}