import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/book.dart';

class ApiResult<T> {
  final List<T> items;
  final String? error;
  const ApiResult(this.items, [this.error]);
  bool get hasError => error != null;
}

/// Thin, defensive client for the public Open Library API + Gutenberg.
class OpenLibrary {
  OpenLibrary({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _base = 'https://openlibrary.org';
  static const _searchFields =
      'key,title,author_name,first_publish_year,cover_i,isbn,edition_count,ratings_average,ratings_count,subject,author_key';

  Uri _uri(String path, [Map<String, String>? qp]) => Uri.parse('$_base$path').replace(queryParameters: qp);

  Future<List<Book>> search(
    String query, {
    int limit = 20,
    int offset = 0,
    String sort = '',
    String subject = '',
  }) async {
    final qp = <String, String>{
      'fields': _searchFields,
      'limit': '$limit',
      'offset': '$offset',
    };
    final q = <String>[];
    if (query.trim().isNotEmpty) q.add(query.trim());
    if (subject.isNotEmpty) q.add('subject:$subject');
    qp['q'] = q.join(' ');
    if (sort.isNotEmpty) qp['sort'] = sort;
    final res = await _client.get(_uri('/search.json', qp)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Search failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = body['docs'];
    if (docs is! List) return const [];
    return docs.whereType<Map<String, dynamic>>().map(Book.fromSearchJson).toList();
  }

  Future<List<Book>> subjects(String subject, {int limit = 20, int offset = 0}) async {
    final qp = <String, String>{'limit': '$limit', 'offset': '$offset'};
    final res = await _client.get(_uri('/subjects/$subject.json', qp)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Shelf failed (${res.statusCode})');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final works = body['works'];
    if (works is! List) return const [];
    return works.whereType<Map<String, dynamic>>().map(Book.fromSubjectJson).toList();
  }

  Future<Book> work(String olid) async {
    final res = await _client.get(_uri('/works/$olid.json')).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('Book not found');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final base = Book.fromWorkJson(body);
    if ((base.author ?? '').isNotEmpty) return base;
    // Resolve author names from keys so detail pages never show a blank author.
    final names = <String>[];
    for (final k in base.authorKeys) {
      try {
        final ar = await _client.get(_uri('$k.json')).timeout(const Duration(seconds: 10));
        if (ar.statusCode == 200) {
          final ajson = jsonDecode(ar.body) as Map<String, dynamic>;
          final n = ajson['name']?.toString();
          if (n != null && n.isNotEmpty) names.add(n);
        }
      } catch (_) {/* single author failure is non-fatal */}
    }
    return base.copyWith(author: names.isEmpty ? base.author : names.join(', '));
  }

  Future<List<Book>> authorWorks(String authorKey, {int limit = 14}) async {
    final res = await _client.get(_uri('$authorKey/works.json', {'limit': '$limit'})).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final entries = body['entries'];
    if (entries is! List) return const [];
    return entries.whereType<Map<String, dynamic>>().map(Book.fromSubjectJson).toList();
  }

  /// Searches a broad result set then sorts by community rating client-side.
  Future<ApiResult<Book>> topRated(String subject, {int limit = 24}) async {
    try {
      final items = await subjects(subject, limit: limit);
      final rated = items.where((b) => (b.rating ?? 0) > 0).toList()
        ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      return ApiResult(rated.isEmpty ? items : rated);
    } catch (e) {
      return ApiResult(const [], e.toString());
    }
  }

  // ------------------------------------------------------- Gutenberg text ---

  /// A curated map of popular public-domain works → Project Gutenberg IDs.
  /// Covers the most-searched classics so text resolves instantly.
  static const Map<String, int> _gutenbergIds = {
    'OL66554W': 1342, // Pride and Prejudice
    'OL20709W': 1080, // A Modest Proposal
    'OL449404W': 1952, // The Metamorphosis
    'OL157508W': 2600, // War and Peace
    'OL24163W': 41, // Grimm's Fairy Tales
  };

  static const Map<String, int> _titleToId = {
    'pride and prejudice': 1342,
    'sense and sensibility': 161,
    'emma': 158,
    'alice': 11,
    'through the looking-glass': 12,
    'frankenstein': 84,
    'dracula': 345,
    'the picture of dorian gray': 174,
    'jekyll and hyde': 43,
    'a christmas carol': 46,
    'great expectations': 1400,
    'oliver twist': 730,
    'a tale of two cities': 98,
    'moby dick': 2701,
    'the scarlet letter': 25344,
    'little women': 514,
    'the adventures of sherlock holmes': 1661,
    'wuthering heights': 768,
    'jane eyre': 1260,
    'the secret garden': 113,
    'the wonderful wizard of oz': 55,
    'the jungle book': 236,
    'the time machine': 35,
    'the war of the worlds': 36,
    'the island of dr. moreau': 7793,
    'twenty thousand leagues under the seas': 164,
    'around the world in eighty days': 103,
    'heart of darkness': 219,
    'the strange case of dr. jekyll and mr. hyde': 43,
    'critique of pure reason': 4280,
  };

  /// Returns full text for a public-domain work, stripped of Gutenberg
  /// headers/footers. Falls back to [null] when unavailable.
  Future<String?> fetchPlainText(Book book, {bool cacheFile = true}) async {
    String url;
    final fixed = _gutenbergIds[book.olid] ?? _matchTitle(book.title);
    if (fixed != null) {
      url = 'https://www.gutenberg.org/cache/epub/$fixed/pg$fixed.txt';
    } else {
      final id = await _gutenbergSearchId(book);
      if (id == null) return null;
      url = 'https://www.gutenberg.org/cache/epub/$id/pg$id.txt';
    }
    try {
      final res = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) return null;
      return _stripGutenberg(res.body);
    } catch (_) {
      return null;
    }
  }

  int? _matchTitle(String title) {
    final t = title.toLowerCase().trim();
    for (final entry in _titleToId.entries) {
      if (t.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Future<int?> _gutenbergSearchId(Book book) async {
    try {
      final query = book.title.replaceAll(RegExp(r'[^\w ]+'), ' ').trim();
      if (query.isEmpty) return null;
      final res = await _client
          .get(Uri.https('gutendex.com', '/books', {'search': query}))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (body['results'] as List?)?.cast<Map<String, dynamic>>();
      if (results == null || results.isEmpty) return null;

      // Score candidates by how many significant title words they share, then
      // prefer author matches. The returned ID is the strongest match.
      final wantedTokens = query
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 3)
          .map((w) => w.toLowerCase())
          .toSet();
      final authorTokens = (book.author ?? '')
          .split(RegExp(r'[^A-Za-z]+'))
          .where((w) => w.length > 2)
          .map((w) => w.toLowerCase())
          .toSet();

      Map<String, dynamic>? best;
      int bestScore = -1;
      for (final r in results) {
        final t = (r['title'] as String? ?? '').toLowerCase();
        final titleWords = t.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 3).toSet();
        int score = titleWords.intersection(wantedTokens).length;
        final authors = (r['authors'] as List?)?.cast<Map<String, dynamic>>();
        if (authors != null) {
          for (final a in authors) {
            final name = (a['name'] as String? ?? '').toLowerCase();
            final aTokens = name.split(RegExp(r'[^a-z]+')).where((w) => w.length > 2).toSet();
            if (authorTokens.isNotEmpty && aTokens.intersection(authorTokens).isNotEmpty) score += 2;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          best = r;
        }
      }
      if (best == null || bestScore < 2) return null;
      return best['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  String _stripGutenberg(String raw) {
    final start = raw.indexOf('*** START OF THE PROJECT GUTENBERG');
    var s = start >= 0 ? raw.substring(start) : raw;
    final end = s.indexOf('*** END OF THE PROJECT GUTENBERG');
    if (end >= 0) s = s.substring(0, end);
    // Drop the START banner line.
    final nl = s.indexOf('\n');
    if (nl >= 0 && s.startsWith('***')) s = s.substring(nl + 1);
    return s.trim();
  }

  void close() => _client.close();
}