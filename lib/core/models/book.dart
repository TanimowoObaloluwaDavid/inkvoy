import 'dart:convert';

/// A book as surfaced by the Open Library API (search / subjects / works).
class Book {
  final String key;
  final String title;
  final String? author;
  final int? firstPublishYear;
  final int? coverI;
  final String? isbn;
  final List<int> covers;
  final int editionCount;
  final int pageCount;
  final double? rating;
  final int ratingCount;
  final List<String> subjects;
  final List<String> authorKeys;
  final String description;

  const Book({
    required this.key,
    required this.title,
    this.author,
    this.firstPublishYear,
    this.coverI,
    this.isbn,
    this.covers = const [],
    this.editionCount = 0,
    this.pageCount = 0,
    this.rating,
    this.ratingCount = 0,
    this.subjects = const [],
    this.authorKeys = const [],
    this.description = '',
  });

  String get olid => key;

  bool get hasCover => coverI != null || (isbn != null && isbn!.isNotEmpty) || covers.isNotEmpty;

  String? coverUrl([String size = 'M']) {
    if (coverI != null) return 'https://covers.openlibrary.org/b/id/$coverI-$size.jpg';
    if (isbn != null && isbn!.isNotEmpty) {
      return 'https://covers.openlibrary.org/b/isbn/$isbn-$size.jpg?default=false';
    }
    if (covers.isNotEmpty) return 'https://covers.openlibrary.org/b/id/${covers.first}-$size.jpg';
    return null;
  }

  /// Ordered candidate cover URLs; the cover widget falls through to the next
  /// when an image 404s so real covers appear wherever possible.
  List<String> coverCandidates([String size = 'M']) {
    final out = <String>[];
    if (coverI != null) out.add('https://covers.openlibrary.org/b/id/$coverI-$size.jpg');
    if (isbn != null && isbn!.isNotEmpty) {
      out.add('https://covers.openlibrary.org/b/isbn/$isbn-$size.jpg?default=false');
    }
    for (final c in covers) {
      out.add('https://covers.openlibrary.org/b/id/$c-$size.jpg');
    }
    return out.toSet().toList();
  }

  Book copyWith({
    String? title,
    String? author,
    int? firstPublishYear,
    int? coverI,
    String? isbn,
    List<int>? covers,
    int? pageCount,
    double? rating,
    int? ratingCount,
    List<String>? subjects,
    List<String>? authorKeys,
    String? description,
  }) {
    return Book(
      key: key,
      title: title ?? this.title,
      author: author ?? this.author,
      firstPublishYear: firstPublishYear ?? this.firstPublishYear,
      coverI: coverI ?? this.coverI,
      isbn: isbn ?? this.isbn,
      covers: covers ?? this.covers,
      editionCount: editionCount,
      pageCount: pageCount ?? this.pageCount,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      subjects: subjects ?? this.subjects,
      authorKeys: authorKeys ?? this.authorKeys,
      description: description ?? this.description,
    );
  }

  // ---------------- Open Library JSON mapping ----------------

  factory Book.fromSearchJson(Map<String, dynamic> j) {
    final subjects = j['subject'];
    return Book(
      key: _norm(j['key'] ?? ''),
      title: _s(j['title']) ?? '',
      author: _firstStr(j['author_name']),
      firstPublishYear: _int(j['first_publish_year']),
      coverI: _int(j['cover_i']),
      isbn: _firstStr(j['isbn']),
      editionCount: _int(j['edition_count']) ?? 0,
      rating: _double(j['ratings_average']),
      ratingCount: _int(j['ratings_count']) ?? 0,
      subjects: subjects is List ? subjects.map((e) => e.toString()).toList() : const [],
      authorKeys: _strList(j['author_key']),
      description: _s(j['description']) ?? '',
    );
  }

  factory Book.fromSubjectJson(Map<String, dynamic> j) {
    final authors = j['authors'];
    final author = authors is List && authors.isNotEmpty && authors.first is Map
        ? _s((authors.first as Map)['name'])
        : null;
    final authorKeys = authors is List
        ? authors.whereType<Map>().map((a) => _norm(_s(a['key']))).where((k) => k.isNotEmpty).toList()
        : <String>[];
    return Book(
      key: _norm(j['key'] ?? ''),
      title: _s(j['title']) ?? '',
      author: author,
      firstPublishYear: _int(j['first_publish_year']),
      coverI: _int(j['cover_id']),
      editionCount: _int(j['edition_count']) ?? 0,
      rating: _double(j['average_rating']),
      ratingCount: _int(j['ratings_count']) ?? 0,
      subjects: _strList(j['subject']),
      authorKeys: authorKeys,
      description: '',
    );
  }

  factory Book.fromWorkJson(Map<String, dynamic> j) {
    final desc = j['description'];
    final descStr = desc is String ? desc : (desc is Map ? _s(desc['value']) : '');
    final authors = j['authors'];
    final covers = j['covers'] is List
        ? (j['covers'] as List).whereType<num>().map((e) => e.toInt()).toList()
        : <int>[];
    return Book(
      key: _norm(j['key'] ?? ''),
      title: _s(j['title']) ?? '',
      firstPublishYear: _int(j['first_publish_year']),
      coverI: covers.isEmpty ? null : covers.first,
      covers: covers,
      rating: _double(j['rating']?['average']),
      ratingCount: _int(j['rating']?['count']) ?? 0,
      subjects: _strList(j['subjects']),
      authorKeys: authors is List
          ? authors.whereType<Map>().map((a) => _norm(_s(a['key']) ?? '')).where((k) => k.isNotEmpty).toList()
          : const [],
      description: descStr ?? '',
    );
  }

  // ---------------- Persistence ----------------

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'author': author,
        'firstPublishYear': firstPublishYear,
        'coverI': coverI,
        'isbn': isbn,
        'covers': covers,
        'editionCount': editionCount,
        'pageCount': pageCount,
        'rating': rating,
        'ratingCount': ratingCount,
        'subjects': subjects,
        'authorKeys': authorKeys,
        'description': description,
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        key: _s(j['key']) ?? '',
        title: _s(j['title']) ?? '',
        author: j['author'] as String?,
        firstPublishYear: _int(j['firstPublishYear']),
        coverI: _int(j['coverI']),
        isbn: j['isbn'] as String?,
        covers: j['covers'] is List
            ? (j['covers'] as List).whereType<num>().map((e) => e.toInt()).toList()
            : const [],
        editionCount: _int(j['editionCount']) ?? 0,
        pageCount: _int(j['pageCount']) ?? 0,
        rating: _double(j['rating']),
        ratingCount: _int(j['ratingCount']) ?? 0,
        subjects: _strList(j['subjects']),
        authorKeys: _strList(j['authorKeys']),
        description: _s(j['description']) ?? '',
      );

  String encode() => jsonEncode(toJson());
  static Book decode(String raw) => Book.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  // ---------------- helpers ----------------

  static String? _s(dynamic v) => v is String && v.isNotEmpty ? v : (v != null ? v.toString() : null);
  static String _norm(dynamic v) {
    if (v is! String) return '';
    return v.startsWith('/') ? v : '/$v';
  }
  static String? _firstStr(dynamic v) {
    if (v is List && v.isNotEmpty) return v.first.toString();
    return _s(v);
  }
  static int? _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : (v is String ? int.tryParse(v) : null));
  static double? _double(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
  static List<String> _strList(dynamic v) =>
      v is List ? v.whereType<dynamic>().map((e) => e.toString()).toList() : const [];

  @override
  bool operator ==(Object other) => other is Book && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

/// Curated + user genres for discovery shelves.
abstract final class Genres {
  static const List<String> popular = [
    'fiction',
    'mystery',
    'fantasy',
    'romance',
    'science fiction',
    'thriller',
    'classics',
    'biography',
    'poetry',
    'history',
    'young adult',
    'nonfiction',
  ];

  static String display(String g) => g.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}