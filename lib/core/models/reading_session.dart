import 'book.dart';

/// Where a book lives in the user's library.
enum Shelf {
  want('Want to read'),
  reading('Reading'),
  finished('Finished');

  const Shelf(this.label);
  final String label;

  static Shelf from(String v) =>
      Shelf.values.firstWhere((s) => s.name == v, orElse: () => Shelf.want);
}

/// A saved library entry.
class SavedEntry {
  final Book book;
  final Shelf shelf;
  final double progress; // 0..1
  final int lastPage;
  final DateTime addedAt;
  final int? myRating; // 1..5

  const SavedEntry({
    required this.book,
    required this.shelf,
    this.progress = 0,
    this.lastPage = 0,
    required this.addedAt,
    this.myRating,
  });

  SavedEntry copyWith({
    Shelf? shelf,
    double? progress,
    int? lastPage,
    int? myRating,
  }) => SavedEntry(
    book: book,
    shelf: shelf ?? this.shelf,
    progress: progress ?? this.progress,
    lastPage: lastPage ?? this.lastPage,
    addedAt: addedAt,
    myRating: myRating ?? this.myRating,
  );

  Map<String, dynamic> toJson() => {
    'book': book.encode(),
    'shelf': shelf.name,
    'progress': progress,
    'lastPage': lastPage,
    'addedAt': addedAt.millisecondsSinceEpoch,
    'myRating': myRating,
  };

  factory SavedEntry.fromJson(Map<String, dynamic> j) => SavedEntry(
    book: Book.decode(j['book'] as String),
    shelf: Shelf.from(j['shelf'] as String? ?? 'want'),
    progress: (j['progress'] as num?)?.toDouble() ?? 0,
    lastPage: (j['lastPage'] as num?)?.toInt() ?? 0,
    addedAt: DateTime.fromMillisecondsSinceEpoch(
      (j['addedAt'] as num?)?.toInt() ?? 0,
    ),
    myRating: j['myRating'] as int?,
  );
}

/// One logged reading session (used by the insights tracker).
class ReadingSession {
  final String id;
  final String bookKey;
  final String bookTitle;
  final int? coverI;
  final DateTime start;
  final DateTime end;

  const ReadingSession({
    required this.id,
    required this.bookKey,
    required this.bookTitle,
    this.coverI,
    required this.start,
    required this.end,
  });

  int get minutes => end.difference(start).inMinutes;

  String get dayKey {
    final l = start.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  DateTime get day => DateTime(start.year, start.month, start.day);

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookKey': bookKey,
    'bookTitle': bookTitle,
    'coverI': coverI,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
  };

  factory ReadingSession.fromJson(Map<String, dynamic> j) => ReadingSession(
    id: j['id'] as String,
    bookKey: j['bookKey'] as String? ?? '',
    bookTitle: j['bookTitle'] as String? ?? '',
    coverI: j['coverI'] as int?,
    start: DateTime.fromMillisecondsSinceEpoch((j['start'] as num).toInt()),
    end: DateTime.fromMillisecondsSinceEpoch((j['end'] as num).toInt()),
  );
}

/// Reader appearance preferences for the mini reader.
class ReaderPrefs {
  final String themeId;
  final double fontSize;
  final double lineHeight;
  final bool serif;
  final bool justify;
  final double margin; // horizontal gutter in px (reading width)

  const ReaderPrefs({
    this.themeId = 'Paper',
    this.fontSize = 17,
    this.lineHeight = 1.75,
    this.serif = true,
    this.justify = true,
    this.margin = 22,
  });

  ReaderPrefs copyWith({
    String? themeId,
    double? fontSize,
    double? lineHeight,
    bool? serif,
    bool? justify,
    double? margin,
  }) => ReaderPrefs(
    themeId: themeId ?? this.themeId,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    serif: serif ?? this.serif,
    justify: justify ?? this.justify,
    margin: margin ?? this.margin,
  );

  Map<String, dynamic> toJson() => {
    'themeId': themeId,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'serif': serif,
    'justify': justify,
    'margin': margin,
  };
  factory ReaderPrefs.fromJson(Map<String, dynamic> j) => ReaderPrefs(
    themeId: j['themeId'] as String? ?? 'Paper',
    fontSize: (j['fontSize'] as num?)?.toDouble() ?? 17,
    lineHeight: (j['lineHeight'] as num?)?.toDouble() ?? 1.75,
    serif: j['serif'] as bool? ?? true,
    justify: j['justify'] as bool? ?? true,
    margin: (j['margin'] as num?)?.toDouble() ?? 22,
  );
}

const String kDefaultReaderPrefsJson =
    '{"themeId":"Paper","fontSize":17,"lineHeight":1.75,"serif":true,"justify":true,"margin":22}';
