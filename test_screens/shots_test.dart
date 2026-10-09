// Golden-screenshot harness for Inkvoy.
//
// Renders every screen with deterministic, curated data so the marketing
// screenshots can be regenerated at any time:
//
//   flutter test test_screens --update-goldens
//
// Output PNGs land in test_screens/shots/ and are copied into docs/screenshots/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:inkvoy/core/api/open_library.dart';
import 'package:inkvoy/core/models/book.dart';
import 'package:inkvoy/core/models/reading_session.dart';
import 'package:inkvoy/core/providers/providers.dart';
import 'package:inkvoy/core/router/app_router.dart';
import 'package:inkvoy/core/router/nav.dart';
import 'package:inkvoy/core/storage/hive_store.dart';
import 'package:inkvoy/core/theme/app_theme.dart';
import 'package:inkvoy/features/detail/book_detail_screen.dart';
import 'package:inkvoy/features/onboarding/genre_picker.dart';
import 'package:inkvoy/features/onboarding/onboarding_screen.dart';
import 'package:inkvoy/features/reader/reader_screen.dart';
import 'package:inkvoy/features/settings/settings_screen.dart';
import 'package:inkvoy/features/splash/splash_screen.dart';

// ------------------------------------------------------------- fake storage ---

// ignore: invalid_use_of_visible_for_testing_member
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      (await Directory.systemTemp.createTemp('inkvoy_shots')).path;

  @override
  Future<String?> getApplicationSupportPath() async =>
      (await Directory.systemTemp.createTemp('inkvoy_shots_support')).path;

  @override
  Future<String?> getLibraryPath() async =>
      (await Directory.systemTemp.createTemp('inkvoy_shots_lib')).path;

  @override
  Future<String?> getTemporaryPath() async =>
      (await Directory.systemTemp.createTemp('inkvoy_shots_tmp')).path;
}

// ------------------------------------------------------------ curated books ---

const String _d1 =
    'A circus arrives without warning. Within its black-and-white tents, two '
    'young illusionists are bound to a duel neither understands — a contest of '
    'imagination, obsession and love that will reshape the world around them.';
const String _d2 =
    'The daughter of the sun god Helios is exiled to a lonely island, where she '
    'hones her witchcraft and crosses paths with the mortal who will change the '
    'course of her long, immortal life.';
const String _d3 =
    'On the desert planet Arrakis, a boy becomes the fulcrum of an empire. Spice, '
    'prophecy and betrayal collide in the greatest ecological epic ever written.';
const String _d4 =
    'Elizabeth Bennet has little patience for pride and even less for prejudice — '
    'until Mr Darcy forces her to reconsider everything she thought she knew about '
    'love, class and first impressions.';
const String _d5 =
    'In a world of perpetual surveillance, one man dares to keep a private '
    'journal. A chilling, unforgettable meditation on truth, power and freedom.';

const List<Book> _library = [
  Book(
    key: '/works/OL1W',
    title: 'The Night Circus',
    author: 'Erin Morgenstern',
    firstPublishYear: 2011,
    rating: 4.3,
    ratingCount: 4820,
    subjects: ['fantasy', 'fiction', 'romance'],
    authorKeys: ['/authors/OLmorganA'],
    description: _d1,
  ),
  Book(
    key: '/works/OL2W',
    title: 'Circe',
    author: 'Madeline Miller',
    firstPublishYear: 2018,
    rating: 4.5,
    ratingCount: 9130,
    subjects: ['fantasy', 'fiction', 'mythology'],
    authorKeys: ['/authors/OLmillerA'],
    description: _d2,
  ),
  Book(
    key: '/works/OL3W',
    title: 'Dune',
    author: 'Frank Herbert',
    firstPublishYear: 1965,
    rating: 4.4,
    ratingCount: 7640,
    subjects: ['science fiction', 'fiction', 'classics'],
    authorKeys: ['/authors/OLherbertA'],
    description: _d3,
  ),
  Book(
    key: '/works/OL4W',
    title: 'Pride and Prejudice',
    author: 'Jane Austen',
    firstPublishYear: 1813,
    rating: 4.6,
    ratingCount: 12500,
    subjects: ['classics', 'romance', 'fiction'],
    authorKeys: ['/authors/OLaustenA'],
    description: _d4,
  ),
  Book(
    key: '/works/OL5W',
    title: '1984',
    author: 'George Orwell',
    firstPublishYear: 1949,
    rating: 4.5,
    ratingCount: 15200,
    subjects: ['science fiction', 'classics', 'fiction'],
    authorKeys: ['/authors/OLorwellA'],
    description: _d5,
  ),
  Book(
    key: '/works/OL6W',
    title: 'The Great Gatsby',
    author: 'F. Scott Fitzgerald',
    firstPublishYear: 1925,
    rating: 4.0,
    ratingCount: 10100,
    subjects: ['classics', 'fiction'],
    authorKeys: ['/authors/OLfitzA'],
  ),
  Book(
    key: '/works/OL7W',
    title: 'To Kill a Mockingbird',
    author: 'Harper Lee',
    firstPublishYear: 1960,
    rating: 4.6,
    ratingCount: 13800,
    subjects: ['classics', 'fiction', 'mystery'],
    authorKeys: ['/authors/OLleeA'],
  ),
  Book(
    key: '/works/OL8W',
    title: 'The Midnight Library',
    author: 'Matt Haig',
    firstPublishYear: 2020,
    rating: 3.9,
    ratingCount: 6400,
    subjects: ['fantasy', 'fiction', 'romance'],
    authorKeys: ['/authors/OLhaigA'],
  ),
  Book(
    key: '/works/OL9W',
    title: 'Where the Crawdads Sing',
    author: 'Delia Owens',
    firstPublishYear: 2018,
    rating: 4.2,
    ratingCount: 8800,
    subjects: ['mystery', 'fiction'],
    authorKeys: ['/authors/OLowensA'],
  ),
  Book(
    key: '/works/OL10W',
    title: 'The Song of Achilles',
    author: 'Madeline Miller',
    firstPublishYear: 2011,
    rating: 4.5,
    ratingCount: 9700,
    subjects: ['fantasy', 'romance', 'mythology'],
    authorKeys: ['/authors/OLmillerA'],
  ),
  Book(
    key: '/works/OL11W',
    title: 'The Hobbit',
    author: 'J. R. R. Tolkien',
    firstPublishYear: 1937,
    rating: 4.5,
    ratingCount: 11900,
    subjects: ['fantasy', 'classics', 'fiction'],
    authorKeys: ['/authors/OLtolkienA'],
  ),
  Book(
    key: '/works/OL12W',
    title: 'Emma',
    author: 'Jane Austen',
    firstPublishYear: 1815,
    rating: 4.3,
    ratingCount: 5600,
    subjects: ['classics', 'romance'],
    authorKeys: ['/authors/OLaustenA'],
  ),
];

const String _sampleText = '''
Chapter I

Every library is a promise. It stands in a parlor or a narrow hall, in the quiet corner of a sleeping house, and asks only that you sit down beside it. So it is with this book, which begins, as all good books do, with a reader and a room and a question that has not yet been asked aloud.

This page is a reading preview, written in the spirit of the original — a gentle stand-in while the full edition is fetched. Turn it like any first page: with the certain knowledge that the story you are holding has travelled through more hands than you will ever count.

The story, wherever it truly begins, begins in weather. A morning of the kind that licks gold across the rooftops, or a rain so patient it seems to apologize for arriving. And into that weather walks a figure — lonely, stubborn, or simply in a hurry — carrying a small valise and a larger hope.

That figure is, in a way, every reader. We come to a story the way travellers come to an inn: tired of our own company, and yet unwilling to begin again unless the warmth is genuine. These pages intend to be warm. They intend to let you breathe.

Somewhere beyond this opening the tale continues its quiet work of accumulation — incidents, arguments, small victories, doors that close a shade too loudly, letters sent and letters kept. A plot is only a scaffold for feeling; the real architecture is the sly way one ordinary hour makes itself unforgettable.

And so we read on. Not because we must, but because somewhere in these paragraphs there is a sentence that will feel like remembering, a line addressed so precisely to you that you will set the book down for a moment, simply to keep it new.
''';

/// Deterministic, offline stand-in for the Open Library client.
class _FakeLibrary extends OpenLibrary {
  Book _match(String olid) {
    final norm = olid.startsWith('/') ? olid : '/$olid';
    return _library.firstWhere((b) => b.key == norm, orElse: () => _library.first);
  }

  @override
  Future<List<Book>> search(
    String query, {
    int limit = 20,
    int offset = 0,
    String sort = '',
    String subject = '',
  }) async {
    Iterable<Book> list = _library;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where(
        (b) =>
            b.title.toLowerCase().contains(q) ||
            (b.author ?? '').toLowerCase().contains(q),
      );
    }
    if (subject.isNotEmpty) {
      final s = subject.toLowerCase();
      list = list.where(
        (b) => b.subjects.any((x) => x.toLowerCase().contains(s)),
      );
    }
    return list.take(limit).toList();
  }

  @override
  Future<List<Book>> subjects(String subject, {int limit = 20, int offset = 0}) async {
    final s = subject.toLowerCase();
    final list = _library
        .where((b) => b.subjects.any((x) => x.toLowerCase().contains(s)))
        .toList();
    return (list.isEmpty ? _library : list).take(limit).toList();
  }

  @override
  Future<Book> work(String olid) async => _match(olid);

  @override
  Future<List<Book>> authorWorks(String authorKey, {int limit = 14}) async {
    final norm = authorKey.startsWith('/') ? authorKey : '/$authorKey';
    return _library
        .where((b) => b.authorKeys.contains(norm))
        .take(limit)
        .toList();
  }

  @override
  Future<ApiResult<Book>> topRated(String subject, {int limit = 24}) async {
    final rated = [..._library]
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return ApiResult(rated.take(limit).toList());
  }

  @override
  Future<String?> fetchPlainText(Book book, {bool cacheFile = true}) async =>
      _sampleText;
}

/// Repos that mutate in-memory state only. The reader screen writes on every
/// frame interaction / dispose; persisting those writes to disk from inside the
/// fake-async test zone would leave real I/O futures permanently pending.
class _EphemeralSavedRepo extends SavedRepo {
  @override
  void addBook(Book book, {Shelf shelf = Shelf.want}) {
    if (entryFor(book.key) != null) {
      setShelf(book.key, shelf);
      return;
    }
    state = [
      SavedEntry(book: book, shelf: shelf, addedAt: DateTime.now()),
      ...state,
    ];
  }

  @override
  void setShelf(String key, Shelf shelf) {
    final e = entryFor(key);
    if (e == null) return;
    state = [
      for (final x in state)
        if (x.book.key == key) x.copyWith(shelf: shelf) else x,
    ];
  }

  @override
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
  }

  @override
  void setRating(String key, int? rating) {
    final e = entryFor(key);
    if (e == null) return;
    state = [
      for (final x in state)
        if (x.book.key == key) x.copyWith(myRating: rating) else x,
    ];
  }

  @override
  void remove(String key) {
    state = state.where((e) => e.book.key != key).toList();
  }
}

class _EphemeralSessionsRepo extends SessionsRepo {
  @override
  void add(ReadingSession s) {
    state = [s, ...state];
  }

  @override
  void clearAll() {
    state = const [];
  }
}

// -------------------------------------------------------------------- seed ---

Future<void> _seed({String themeMode = 'light'}) async {
  final settings = HiveStore.settings;
  await settings.clear();
  await settings.put(Keys.onboardingDone, true);
  await settings.put(Keys.genres, ['fantasy', 'classics']);
  await settings.put(Keys.themeMode, themeMode);
  await settings.put(Keys.dailyGoal, 10);

  final now = DateTime.now();
  final saved = HiveStore.saved;
  await saved.clear();
  final entries = <SavedEntry>[
    SavedEntry(
      book: _library[1],
      shelf: Shelf.reading,
      progress: 0.42,
      addedAt: now.subtract(const Duration(hours: 2)),
    ),
    SavedEntry(
      book: _library[2],
      shelf: Shelf.reading,
      progress: 0.63,
      addedAt: now.subtract(const Duration(hours: 6)),
    ),
    SavedEntry(
      book: _library[0],
      shelf: Shelf.reading,
      progress: 0.18,
      addedAt: now.subtract(const Duration(days: 1)),
    ),
    SavedEntry(book: _library[5], shelf: Shelf.want, addedAt: now.subtract(const Duration(days: 2))),
    SavedEntry(book: _library[6], shelf: Shelf.want, addedAt: now.subtract(const Duration(days: 3))),
    SavedEntry(book: _library[7], shelf: Shelf.want, addedAt: now.subtract(const Duration(days: 4))),
    SavedEntry(book: _library[8], shelf: Shelf.want, addedAt: now.subtract(const Duration(days: 5))),
    SavedEntry(book: _library[10], shelf: Shelf.want, addedAt: now.subtract(const Duration(days: 6))),
    SavedEntry(
      book: _library[3],
      shelf: Shelf.finished,
      progress: 1,
      addedAt: now.subtract(const Duration(days: 12)),
      myRating: 5,
    ),
    SavedEntry(
      book: _library[4],
      shelf: Shelf.finished,
      progress: 1,
      addedAt: now.subtract(const Duration(days: 20)),
      myRating: 4,
    ),
  ];
  for (final e in entries) {
    await saved.put(e.book.key, jsonEncode(e.toJson()));
  }

  final sessions = HiveStore.sessions;
  await sessions.clear();
  const minutes = [25, 40, 18, 0, 32, 55, 20, 0, 45, 30, 12, 38];
  for (var i = 0; i < minutes.length; i++) {
    if (minutes[i] == 0) continue;
    final day = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: i));
    final start = DateTime(day.year, day.month, day.day, 20, 30);
    final book = _library[i % _library.length];
    final s = ReadingSession(
      id: 'seed$i',
      bookKey: book.key,
      bookTitle: book.title,
      start: start,
      end: start.add(Duration(minutes: minutes[i])),
    );
    await sessions.put('s_${s.id}', jsonEncode(s.toJson()));
  }

  final reader = HiveStore.reader;
  await reader.clear();
  await reader.put(Keys.readerPrefs, kDefaultReaderPrefsJson);
}

// ------------------------------------------------------------------- fonts ---

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) continue;
    final bytes = await f.readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    any = true;
  }
  if (any) await loader.load();
}

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  await _loadFont('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);

  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache';
  final phosphor =
      '$pubCache\\hosted\\pub.dev\\phosphor_flutter-2.1.0\\lib\\fonts';
  await _loadFont('PhosphorRegular', ['$phosphor\\Phosphor.ttf']);
  await _loadFont('PhosphorFill', ['$phosphor\\Phosphor-Fill.ttf']);
  await _loadFont('PhosphorBold', ['$phosphor\\Phosphor-Bold.ttf']);

  const fonts = 'assets/fonts';
  await _loadFont('CormorantGaramond', [
    '$fonts/CormorantGaramond-Regular.ttf',
    '$fonts/CormorantGaramond-Medium.ttf',
    '$fonts/CormorantGaramond-SemiBold.ttf',
    '$fonts/CormorantGaramond-Bold.ttf',
    '$fonts/CormorantGaramond-Italic.ttf',
    '$fonts/CormorantGaramond-MediumItalic.ttf',
  ]);
  await _loadFont('Inter', [
    '$fonts/Inter-Regular.ttf',
    '$fonts/Inter-Medium.ttf',
    '$fonts/Inter-SemiBold.ttf',
    '$fonts/Inter-Bold.ttf',
    '$fonts/Inter-ExtraBold.ttf',
  ]);
}

// ------------------------------------------------------------- test helpers ---

void _setSurface(WidgetTester tester) {
  // iPhone 16 Pro Max logical canvas (440 x 956 @ 3x).
  tester.view.physicalSize = const Size(1320, 2868);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 20);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> _pumpRouter(
  WidgetTester tester,
  String location, {
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [openLibraryProvider.overrideWithValue(_FakeLibrary())],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        routerConfig: buildAppRouter(initialLocation: location),
      ),
    ),
  );
  await _pumpFor(tester, const Duration(milliseconds: 1900));
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget home, {
  Duration settle = const Duration(milliseconds: 1700),
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openLibraryProvider.overrideWithValue(_FakeLibrary()),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: home,
      ),
    ),
  );
  await _pumpFor(tester, settle);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name.png'),
  );
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

// ------------------------------------------------------------------- suite ---

void main() {
  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProvider();
    TestWidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await HiveStore.init();
    await _loadFonts();

    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = details.exceptionAsString();
      if (msg.contains('HTTP request failed') ||
          msg.contains('ImageCodec') ||
          msg.contains('Exception: 400') ||
          msg.contains('Invalid statusCode') ||
          msg.contains('failed to precache') ||
          msg.contains('NetworkImageLoadException') ||
          msg.contains('SocketException') ||
          msg.contains('CachedNetworkImage') ||
          msg.contains('statusCode: 400') ||
          msg.contains('A RenderFlex overflowed') ||
          msg.contains('deactivated widget') ||
          msg.contains('after the widget was disposed')) {
        return;
      }
      onError?.call(details);
    };
  });

// Seeding touches the disk, so it runs outside the fake-async zone.
setUp(() async {
  await _seed();
});

tearDownAll(() async {
  await Hive.deleteFromDisk();
});

  testWidgets('01 splash', (tester) async {
    _setSurface(tester);
    await _pumpScreen(
      tester,
      const SplashScreen(),
      settle: const Duration(milliseconds: 1300),
    );
    await _shoot(tester, '01_splash');
    await _finish(tester);
  });

  testWidgets('02 onboarding', (tester) async {
    _setSurface(tester);
    await _pumpScreen(tester, const OnboardingScreen());
    await _shoot(tester, '02_onboarding');
    await _finish(tester);
  });

  testWidgets('03 genre picker', (tester) async {
    _setSurface(tester);
    await _pumpScreen(
      tester,
      Scaffold(
        body: SafeArea(
          child: GenrePicker(
            selected: const ['fantasy', 'classics', 'mystery'],
            onToggle: (_) {},
          ),
        ),
      ),
    );
    await _shoot(tester, '03_genres');
    await _finish(tester);
  });

  testWidgets('04 home', (tester) async {
    _setSurface(tester);
    await _pumpRouter(tester, '/home');
    await _shoot(tester, '04_home');
    await _finish(tester);
  });

  testWidgets('05 home dark', (tester) async {
    _setSurface(tester);
    await tester.runAsync(() => _seed(themeMode: 'dark'));
    await _pumpRouter(tester, '/home', mode: ThemeMode.dark);
    await _shoot(tester, '05_home_dark');
    await _finish(tester);
  });

  testWidgets('06 discover', (tester) async {
    _setSurface(tester);
    await _pumpRouter(tester, '/discover');
    await _shoot(tester, '06_discover');
    await _finish(tester);
  });

  testWidgets('07 discover results', (tester) async {
    _setSurface(tester);
    await _pumpRouter(tester, '/discover');
    await tester.enterText(find.byType(TextField), 'The');
    await _pumpFor(tester, const Duration(milliseconds: 1500));
    await _shoot(tester, '07_discover_results');
    await _finish(tester);
  });

  testWidgets('08 library', (tester) async {
    _setSurface(tester);
    await _pumpRouter(tester, '/library');
    await _shoot(tester, '08_library');
    await _finish(tester);
  });

  testWidgets('09 insights', (tester) async {
    _setSurface(tester);
    await _pumpRouter(tester, '/insights');
    await _shoot(tester, '09_insights');
    await _finish(tester);
  });

  testWidgets('10 book detail', (tester) async {
    _setSurface(tester);
    await _pumpScreen(
      tester,
      BookDetailScreen(
        bookKey: _library[1].key,
        book: _library[1],
        heroTag: coverTag('h', _library[1].key),
      ),
    );
    await _shoot(tester, '10_book_detail');
    await _finish(tester);
  });

  testWidgets('11 reader', (tester) async {
    _setSurface(tester);
    await _pumpScreen(
      tester,
      ReaderScreen(book: _library[0]),
      settle: const Duration(milliseconds: 1500),
      overrides: [
        savedRepoProvider.overrideWith(() => _EphemeralSavedRepo()),
        sessionsRepoProvider.overrideWith(() => _EphemeralSessionsRepo()),
        bookTextProvider.overrideWith((ref, book) async => (_sampleText, true)),
      ],
    );
    await _shoot(tester, '11_reader');
    await _finish(tester);
  });

  testWidgets('12 settings', (tester) async {
    _setSurface(tester);
    await _pumpScreen(tester, const Scaffold(body: SettingsScreen()));
    await _shoot(tester, '12_settings');
    await _finish(tester);
  });
}
