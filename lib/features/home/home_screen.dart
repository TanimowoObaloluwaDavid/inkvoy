import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/book.dart';
import '../../core/models/insights.dart';
import '../../core/models/reading_session.dart';
import '../../core/providers/providers.dart';
import '../../core/router/nav.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/states.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _celebrated = {};
  final Set<String> _dismissed = {};
  bool _confettiActive = false;
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 3),
  );

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _rate(int? rating, SavedEntry e) {
    HapticFeedback.selectionClick();
    ref.read(savedRepoProvider.notifier).setRating(e.book.key, rating);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final saved = ref.watch(savedRepoProvider);
    final stats = ref.watch(readingStatsProvider);
    final continueBooks =
        saved
            .where((e) => e.shelf == Shelf.reading && e.progress > 0.0001)
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    final finishCandidate = saved
        .where((e) => e.shelf == Shelf.finished && e.myRating == null)
        .where((e) => !_dismissed.contains(e.book.key))
        .toList()
        .firstOrNull;

    if (finishCandidate != null &&
        !_celebrated.contains(finishCandidate.book.key)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _celebrated.add(finishCandidate.book.key);
        setState(() {
          _confettiActive = true;
          _confetti.play();
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _confettiActive = false);
        });
      });
    }

    return Stack(
      children: [
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                settings: settings,
                onTheme: () {
                  final cur = settings.themeMode;
                  final next = switch (cur) {
                    ThemeMode.light => ThemeMode.dark,
                    ThemeMode.dark => ThemeMode.system,
                    _ => ThemeMode.light,
                  };
                  ref.read(settingsProvider.notifier).setThemeMode(next);
                },
                onSettings: () => context.push('/settings'),
              ),
            ),
            if (stats.currentStreak > 0)
              SliverToBoxAdapter(
                child: _StreakCard(
                  streak: stats.currentStreak,
                  days: stats.last14Days,
                ),
              ),
            if (finishCandidate != null)
              SliverToBoxAdapter(
                child: _FinishBanner(
                  entry: finishCandidate,
                  onRate: (v) => _rate(v, finishCandidate),
                  onDismiss: () =>
                      setState(() => _dismissed.add(finishCandidate.book.key)),
                ),
              ),
            if (continueBooks.isNotEmpty)
              SliverToBoxAdapter(
                child: _ContinueCard(entry: continueBooks.first),
              ),
            SliverToBoxAdapter(child: _TrendingShelf()),
            if (settings.genres.isNotEmpty)
              for (final g in settings.genres.take(2))
                SliverToBoxAdapter(child: _PersonalShelf(genre: g)),
            const SliverToBoxAdapter(child: _NewArrivalsShelf()),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
        if (_confettiActive)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: -math.pi / 2,
                emissionFrequency: 0.05,
                numberOfParticles: 14,
                gravity: 0.3,
                maxBlastForce: 16,
                minBlastForce: 6,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------- header ----

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.settings,
    required this.onTheme,
    required this.onSettings,
  });
  final AppSettings settings;
  final VoidCallback onTheme;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? (hour < 5 ? 'Late night' : 'Good morning')
        : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final date = DateFormat('EEEE, MMMM d').format(now);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          8,
          AppSpacing.page,
          4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const InkvoyWord()
                    .animate(delay: 50.ms)
                    .fadeIn()
                    .slideX(begin: -0.08, end: 0),
                const Spacer(),
                _RoundIconButton(
                  icon: settings.themeMode == ThemeMode.dark
                      ? PhosphorIconsRegular.moon
                      : PhosphorIconsRegular.sun,
                  onTap: onTheme,
                ),
                const SizedBox(width: 8),
                _RoundIconButton(
                  icon: PhosphorIconsRegular.gear,
                  onTap: onSettings,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _MastheadPlate(greeting: greeting, date: date),
          ],
        ),
      ),
    );
  }
}

/// Inverted editorial masthead — the one black moment of the home page.
/// Carries the day as a display headline per the newsprint system.
class _MastheadPlate extends StatelessWidget {
  const _MastheadPlate({required this.greeting, required this.date});
  final String greeting;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.plate,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                greeting.toUpperCase(),
                style: AppTheme.sans(
                  size: 11,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.plateMuted,
                ),
              ),
              const Spacer(),
              Text(
                'EDN 01',
                style: AppTheme.sans(
                  size: 11,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                  color: AppColors.plateRule,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            date,
            style: AppTheme.serif(
              size: 34,
              weight: FontWeight.w600,
              height: 1.02,
              letterSpacing: -0.5,
              color: AppColors.plateText,
            ),
          ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.plateRule),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'THE READING DESK',
                style: AppTheme.sans(
                  size: 10,
                  weight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: AppColors.plateMuted.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Text(
                'DAILY EDITION',
                style: AppTheme.sans(
                  size: 10,
                  weight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: AppColors.plateMuted.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InkvoyWord extends StatelessWidget {
  const InkvoyWord({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        InkvoyMark(size: 24, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          'Inkvoy',
          style: AppTheme.serif(size: 26, weight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ continue reading ----

/// Streak momentum card shown above the continue tile.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.days});
  final int streak;
  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = days.fold<int>(0, (m, d) => d.minutes > m ? d.minutes : m);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        14,
        AppSpacing.page,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            AppShadows.soft(
              theme.colorScheme.surface,
              alpha: 0.05,
              blur: 14,
              dy: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                PhosphorIconsFill.flame,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$streak',
                        style:
                            AppTheme.serif(
                              size: 30,
                              weight: FontWeight.w700,
                              height: 1,
                            ).copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DAY STREAK',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Keep it burning — read today',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 34,
              width: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days.take(14))
                    Expanded(
                      child: Container(
                        height: max == 0 ? 4 : 5 + (d.minutes / max) * 26,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: d.minutes == 0
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.10,
                                )
                              : theme.colorScheme.primary.withValues(
                                  alpha:
                                      0.35 +
                                      0.65 * (d.minutes / (max == 0 ? 1 : max)),
                                ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.12, end: 0);
  }
}

/// "Just finished" celebration banner: confetti already flew; rate it here.
class _FinishBanner extends StatelessWidget {
  const _FinishBanner({
    required this.entry,
    required this.onRate,
    required this.onDismiss,
  });
  final SavedEntry entry;
  final ValueChanged<int?> onRate;
  final VoidCallback onDismiss;

  static const _cream = Color(0xFFF3EFE7);
  static const _mute = Color(0xFFB9B3A8);

  @override
  Widget build(BuildContext context) {
    final book = entry.book;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        14,
        AppSpacing.page,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF181818), Color(0xFF272727)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            AppShadows.raised(
              const Color(0xFF181818),
              alpha: 0.26,
              blur: 22,
              dy: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -34,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BookCover(book: book, width: 62, height: 92, radius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JUST FINISHED',
                          style: AppTheme.sans(
                            size: 10,
                            weight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: _cream.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.serif(
                            size: 18,
                            weight: FontWeight.w700,
                            color: _cream,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'How was it?',
                              style: TextStyle(
                                color: _mute,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _RateStars(
                              value: entry.myRating,
                              onChanged: onRate,
                              active: _cream,
                              idle: Colors.white24,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: IconButton(
                      onPressed: onDismiss,
                      icon: Icon(
                        PhosphorIconsRegular.x,
                        size: 18,
                        color: _mute,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.14, end: 0);
  }
}

class _RateStars extends StatelessWidget {
  const _RateStars({
    required this.value,
    required this.onChanged,
    required this.active,
    required this.idle,
  });
  final int? value;
  final ValueChanged<int?> onChanged;
  final Color active;
  final Color idle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < (value ?? 0);
        return IconButton(
          onPressed: () => onChanged(value == i + 1 ? null : i + 1),
          icon: Icon(
            filled ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
            size: 22,
            color: filled ? active : idle,
          ),
          splashRadius: 18,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(2),
        );
      }),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry});
  final SavedEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = entry.book;
    final progress = entry.progress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        18,
        AppSpacing.page,
        6,
      ),
      child:
          Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.90),
                      theme.colorScheme.primary.withValues(alpha: 0.96),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -40,
                      top: -40,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.07,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: BookCover(
                              book: book,
                              width: 82,
                              height: 122,
                              radius: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'CONTINUE READING',
                                  style: AppTheme.sans(
                                    size: 10.5,
                                    weight: FontWeight.w800,
                                    letterSpacing: 1.8,
                                    color: theme.colorScheme.onPrimary
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.serif(
                                    size: 20,
                                    weight: FontWeight.w700,
                                    color: theme.colorScheme.onPrimary,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  book.author ??
                                      'Keep going, you\'re almost there.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimary
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.pill,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 5,
                                          backgroundColor: theme
                                              .colorScheme
                                              .onPrimary
                                              .withValues(alpha: 0.22),
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: AppTheme.sans(
                                        size: 13,
                                        weight: FontWeight.w700,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      FilledButton.icon(
                                        onPressed: () =>
                                            pushReader(context, book),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 42),
                                          backgroundColor:
                                              theme.colorScheme.onPrimary,
                                          foregroundColor:
                                              theme.colorScheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.md,
                                            ),
                                          ),
                                          textStyle: AppTheme.sans(
                                            size: 14,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                        icon: const Icon(
                                          PhosphorIconsFill.play,
                                          size: 16,
                                        ),
                                        label: const Text('Continue'),
                                      ),
                                      TextButton(
                                        onPressed: () => pushBook(
                                          context,
                                          book,
                                          prefix: 'h',
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.onPrimary,
                                        ),
                                        child: const Text('Details'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .animate(delay: 160.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0),
    );
  }
}

// ----------------------------------------------------------------- shelf ----

class _TrendingShelf extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(topRatedProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Trending now',
          subtitle: 'Loved by readers this month',
        ).animate(delay: 200.ms).fadeIn(),
        result.when(
          loading: () =>
              const SkeletonShelf(coverWidth: 132, coverHeight: 198, count: 3),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextButton.icon(
              onPressed: () => ref.invalidate(topRatedProvider),
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 18),
              label: const Text('Retry trending shelf'),
            ),
          ),
          data: (r) => r.items.isEmpty
              ? const SizedBox.shrink()
              : SizedBox(
                  height: 292,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    itemCount: math.min(r.items.length, 12),
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) =>
                        _TrendingCard(book: r.items[i], delay: 240 + i * 60),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.book, required this.delay});
  final Book book;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => pushBook(context, book, prefix: 'h'),
      child:
          SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: coverTag('h', book.key),
                      child: Material(
                        color: Colors.transparent,
                        child: BookCover(
                          book: book,
                          width: 132,
                          height: 196,
                          radius: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if ((book.rating ?? 0) > 0) ...[
                          Icon(
                            PhosphorIconsFill.star,
                            size: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            book.rating!.toStringAsFixed(1),
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (book.firstPublishYear != null) ...[
                          Icon(
                            PhosphorIconsRegular.calendar,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${book.firstPublishYear}',
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              )
              .animate(delay: Duration(milliseconds: delay.round()))
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.18, end: 0),
    );
  }
}

class _PersonalShelf extends ConsumerWidget {
  const _PersonalShelf({required this.genre});
  final String genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(subjectShelfProvider(genre));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Because you love ${Genres.display(genre)}'),
        shelf.when(
          loading: () =>
              const SkeletonShelf(coverWidth: 96, coverHeight: 148, count: 4),
          error: (e, _) => const SizedBox.shrink(),
          data: (books) {
            if (books.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 208,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: math.min(books.length, 14),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => pushBook(context, books[i], prefix: 'h'),
                  child: Hero(
                    tag: coverTag('h', books[i].key),
                    child: BookCover(
                      book: books[i],
                      width: 96,
                      height: 148,
                      radius: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NewArrivalsShelf extends ConsumerWidget {
  const _NewArrivalsShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(newArrivalsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'New arrivals',
          subtitle: 'Recently added to the library',
        ),
        shelf.when(
          loading: () =>
              const SkeletonShelf(coverWidth: 96, coverHeight: 148, count: 4),
          error: (e, _) => const SizedBox.shrink(),
          data: (books) {
            if (books.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 208,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: math.min(books.length, 14),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final b = books[i];
                  return GestureDetector(
                    onTap: () => pushBook(context, b, prefix: 'h'),
                    child: Hero(
                      tag: coverTag('h', b.key),
                      child: BookCover(
                        book: b,
                        width: 96,
                        height: 148,
                        radius: 12,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
