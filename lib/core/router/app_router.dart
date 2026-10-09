import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../features/detail/book_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/reader/reader_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../models/book.dart';
import 'nav.dart';

/// Pull a [Book] from route extra, or fall back to a key placeholder when the
/// route is reached via a deep link.
Book _bookFromRoute(GoRouterState s) {
  final key = s.pathParameters['key'] ?? 'unknown';
  final extra = s.extra;
  if (extra is Book) return extra;
  if (extra is BookRouteArgs) return extra.book;
  return Book(key: key, title: key);
}

/// Builds a fresh router. Exposed so tests (golden/screenshots) can spin up an
/// isolated navigator without sharing global state.
GoRouter buildAppRouter({String initialLocation = '/splash'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(
      path: '/book/:key',
      builder: (_, s) {
        final extra = s.extra;
        final tag = extra is BookRouteArgs ? extra.tag : null;
        return BookDetailScreen(
          bookKey: s.pathParameters['key'] ?? '',
          book: _bookFromRoute(s),
          heroTag: tag,
        );
      },
    ),
    GoRoute(path: '/reader/:key', builder: (_, s) => ReaderScreen(book: _bookFromRoute(s))),
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => _AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/discover', builder: (_, __) => const SearchScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/library', builder: (_, __) => const LibraryScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen())]),
      ],
    ),
  ],
);

final appRouter = buildAppRouter();

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(PhosphorIconsRegular.house), selectedIcon: Icon(PhosphorIconsFill.house), label: 'Home'),
          NavigationDestination(icon: Icon(PhosphorIconsRegular.magnifyingGlass), selectedIcon: Icon(PhosphorIconsFill.magnifyingGlass), label: 'Discover'),
          NavigationDestination(icon: Icon(PhosphorIconsRegular.bookmarkSimple), selectedIcon: Icon(PhosphorIconsFill.bookmarkSimple), label: 'Library'),
          NavigationDestination(icon: Icon(PhosphorIconsRegular.chartLineUp), selectedIcon: Icon(PhosphorIconsFill.chartLineUp), label: 'Insights'),
        ],
      ),
    );
  }
}