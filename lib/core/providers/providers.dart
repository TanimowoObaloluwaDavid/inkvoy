import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/open_library.dart';
import '../models/book.dart';
import '../models/insights.dart';
import '../models/reading_session.dart';
import '../models/sample_text.dart';
import '../storage/hive_store.dart';

// ------------------------------------------------------------------ core ---

final openLibraryProvider = Provider<OpenLibrary>((ref) => OpenLibrary());

final class AppSettings {
  final bool onboardingDone;
  final List<String> genres;
  final ThemeMode themeMode;
  final int dailyGoal;
  const AppSettings({
    this.onboardingDone = false,
    this.genres = const [],
    this.themeMode = ThemeMode.system,
    this.dailyGoal = 10,
  });
  AppSettings copyWith({
    bool? onboardingDone,
    List<String>? genres,
    ThemeMode? themeMode,
    int? dailyGoal,
  }) => AppSettings(
    onboardingDone: onboardingDone ?? this.onboardingDone,
    genres: genres ?? this.genres,
    themeMode: themeMode ?? this.themeMode,
    dailyGoal: dailyGoal ?? this.dailyGoal,
  );
}

class SettingsRepo extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final box = HiveStore.settings;
    return AppSettings(
      onboardingDone: box.get(Keys.onboardingDone, defaultValue: false) as bool,
      genres: (box.get(Keys.genres, defaultValue: const <String>[]) as List)
          .cast<String>(),
      themeMode: switch (box.get(Keys.themeMode, defaultValue: 'system')
          as String) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      dailyGoal: box.get(Keys.dailyGoal, defaultValue: 10) as int,
    );
  }

  void setOnboardingDone() {
    state = state.copyWith(onboardingDone: true);
    HiveStore.settings.put(Keys.onboardingDone, true);
  }

  void setGenres(List<String> g) {
    state = state.copyWith(genres: g);
    HiveStore.settings.put(Keys.genres, g);
  }

  void setDailyGoal(int minutes) {
    state = state.copyWith(dailyGoal: minutes);
    HiveStore.settings.put(Keys.dailyGoal, minutes);
  }

  void setThemeMode(ThemeMode m) {
    state = state.copyWith(themeMode: m);
    HiveStore.settings.put(Keys.themeMode, m.name);
  }
}

final settingsProvider = NotifierProvider<SettingsRepo, AppSettings>(
  SettingsRepo.new,
);

// ------------------------------------------------------------------ saved ---

class SavedRepo extends Notifier<List<SavedEntry>> {
  @override
  List<SavedEntry> build() {
    final box = HiveStore.saved;
    final out = <SavedEntry>[];
    for (final raw in box.values) {
      if (raw is String && raw.isNotEmpty) {
        try {
          out.add(SavedEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
        } catch (_) {
          /* skip corrupt entries */
        }
      }
    }
    out.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return out;
  }

  void _persist() {
    final box = HiveStore.saved;
    box.clear();
    for (final e in state) {
      box.put(e.book.key, jsonEncode(e.toJson()));
    }
  }

  SavedEntry? entryFor(String key) {
    for (final e in state) {
      if (e.book.key == key) return e;
    }
    return null;
  }

  Shelf shelfOf(String key) => entryFor(key)?.shelf ?? Shelf.want;

  void addBook(Book book, {Shelf shelf = Shelf.want}) {
    if (shelf == Shelf.want && entryFor(book.key) != null) {
      // Re-add onto a different shelf keeps the freshest timestamp.
      remove(book.key);
    } else if (entryFor(book.key) != null) {
      setShelf(book.key, shelf);
      return;
    }
    state = [
      SavedEntry(book: book, shelf: shelf, addedAt: DateTime.now()),
      ...state,
    ];
    _persist();
  }

  void setShelf(String key, Shelf shelf) {
    final e = entryFor(key);
    if (e == null) return;
    state = [
      for (final x in state)
        if (x.book.key == key) x.copyWith(shelf: shelf) else x,
    ];
    _persist();
  }

  void setProgress(String key, double progress) {
    final e = entryFor(key);
    if (e == null) return;
    state = [
      for (final x in state)
        if (x.book.key == key)
          x.copyWith(
            progress: progress.clamp(0, 1),
            shelf: progress >= 1 ? Shelf.finished : x.shelf,
          )
        else
          x,
    ];
    _persist();
  }

  /// In-place star rating from the finish prompt (or elsewhere).
  void setRating(String key, int? rating) {
    final e = entryFor(key);
    if (e == null) return;
    state = [
      for (final x in state)
        if (x.book.key == key) x.copyWith(myRating: rating) else x,
    ];
    _persist();
  }

  void remove(String key) {
    state = state.where((e) => e.book.key != key).toList();
    _persist();
  }

  void toggle(String key) {
    final e = entryFor(key);
    if (e == null) return;
    const next = {
      Shelf.want: Shelf.reading,
      Shelf.reading: Shelf.finished,
      Shelf.finished: Shelf.want,
    };
    setShelf(key, next[e.shelf] ?? Shelf.want);
  }
}

final savedRepoProvider = NotifierProvider<SavedRepo, List<SavedEntry>>(
  SavedRepo.new,
);

// ---------------------------------------------------------------- sessions ---

class SessionsRepo extends Notifier<List<ReadingSession>> {
  @override
  List<ReadingSession> build() {
    final box = HiveStore.sessions;
    final out = <ReadingSession>[];
    for (final raw in box.values) {
      if (raw is String && raw.isNotEmpty) {
        try {
          out.add(
            ReadingSession.fromJson(jsonDecode(raw) as Map<String, dynamic>),
          );
        } catch (_) {}
      }
    }
    out.sort((a, b) => b.start.compareTo(a.start));
    return out;
  }

  void add(ReadingSession s) {
    state = [s, ...state];
    HiveStore.sessions.put('s_${s.id}', jsonEncode(s.toJson()));
  }

  void clearAll() {
    state = const [];
    HiveStore.sessions.clear();
  }
}

final sessionsRepoProvider =
    NotifierProvider<SessionsRepo, List<ReadingSession>>(SessionsRepo.new);

final readingStatsProvider = Provider<ReadingStats>((ref) {
  final sessions = ref.watch(sessionsRepoProvider);
  return ReadingStats.compute(sessions);
});

// ---------------------------------------------------------------- reader ---

class ReaderPrefsRepo extends Notifier<ReaderPrefs> {
  @override
  ReaderPrefs build() {
    final raw = HiveStore.reader.get(Keys.readerPrefs) as String?;
    if (raw == null || raw.isEmpty) return const ReaderPrefs();
    try {
      return ReaderPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReaderPrefs();
    }
  }

  void update(ReaderPrefs prefs) {
    state = prefs;
    HiveStore.reader.put(Keys.readerPrefs, jsonEncode(prefs.toJson()));
  }
}

final readerPrefsProvider = NotifierProvider<ReaderPrefsRepo, ReaderPrefs>(
  ReaderPrefsRepo.new,
);

final bookTextProvider = FutureProvider.autoDispose
    .family<(String, bool), Book>((ref, book) async {
      final cached = HiveStore.reader.get('text:${book.olid}');
      if (cached is String && cached.isNotEmpty) return (cached, false);
      final api = ref.watch(openLibraryProvider);
      final text = await api.fetchPlainText(book);
      if (text != null && text.length > 200) {
        HiveStore.reader.put('text:${book.olid}', text);
        return (text, false);
      }
      // Always readable: fall back to an elegant literary preview.
      return (SampleText.forBook(book), true);
    });

// ----------------------------------------------------------------- shelves ---

final subjectShelfProvider = FutureProvider.autoDispose
    .family<List<Book>, String>((ref, subject) async {
      final api = ref.watch(openLibraryProvider);
      return api.subjects(subject, limit: 24);
    });

/// Full work metadata (description + resolved authors) for the detail screen.
final workDetailProvider = FutureProvider.autoDispose.family<Book, String>((
  ref,
  key,
) async {
  final api = ref.watch(openLibraryProvider);
  return api.work(key);
});

/// Additional works by the same author.
final authorWorksProvider = FutureProvider.autoDispose
    .family<List<Book>, String>((ref, authorKey) async {
      final api = ref.watch(openLibraryProvider);
      return api.authorWorks(authorKey);
    });

final newArrivalsProvider = FutureProvider.autoDispose<List<Book>>((ref) async {
  final api = ref.watch(openLibraryProvider);
  return api.search('', sort: 'new', subject: 'fiction', limit: 24);
});

final topRatedProvider = FutureProvider.autoDispose<ApiResult<Book>>((
  ref,
) async {
  final api = ref.watch(openLibraryProvider);
  return api.topRated('fiction', limit: 24);
});

typedef SearchArgs = ({String query, String subject, String sort});

final searchProvider = FutureProvider.autoDispose
    .family<List<Book>, SearchArgs>((ref, args) async {
      final api = ref.watch(openLibraryProvider);
      var list = await api.search(
        args.query,
        subject: args.subject,
        sort: args.sort == 'new' ? 'new' : '',
        limit: 40,
      );
      if (args.sort == 'rating') {
        list = [...list]
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      }
      return list;
    });
