import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/insights.dart';
import '../../core/models/reading_session.dart';
import '../../core/providers/providers.dart';
import '../../core/router/nav.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/states.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _weekly = true;
  final _postcardKey = GlobalKey();

  /// Monday-based calendar for the last six weeks, oldest first.
  List<DayTotal> _calendarDays(List<ReadingSession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDay = <DateTime, int>{};
    for (final s in sessions) {
      if (s.minutes <= 0) continue;
      final d = DateTime(s.start.year, s.start.month, s.start.day);
      byDay[d] = (byDay[d] ?? 0) + s.minutes;
    }
    final out = <DayTotal>[];
    for (var i = 41; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      out.add(DayTotal(d, byDay[d] ?? 0));
    }
    return out;
  }

  int _monthMinutes(List<ReadingSession> sessions) {
    final now = DateTime.now();
    return sessions.fold(0, (sum, s) {
      final d = s.start.toLocal();
      return d.year == now.year && d.month == now.month ? sum + s.minutes : sum;
    });
  }

  /// Most represented genre among finished books, via subject keywords.
  String? _topShelf(List<SavedEntry> saved) {
    const genreKeys = [
      ('Fantasy', ['fantasy', 'magic', 'wizard', 'myth', 'legend']),
      ('Mystery', ['mystery', 'detective', 'crime', 'thriller', 'suspense']),
      ('Romance', ['romance', 'love', 'relationship']),
      ('Sci-Fi', ['science', 'space', 'dystopia', 'future', 'technology']),
      ('Classics', ['classic', 'literature']),
      ('History', ['history', 'war', 'biography', 'memoir', 'historical']),
      ('Poetry', ['poetry', 'verse', 'poem']),
    ];
    final counts = <String, int>{};
    for (final e in saved.where((x) => x.shelf == Shelf.finished)) {
      for (final (label, keys) in genreKeys) {
        final hit = e.book.subjects.any((sub) {
          final s = sub.toLowerCase();
          return keys.any(s.contains);
        });
        if (hit) counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return top.value == 0 ? null : top.key;
  }

  Future<void> _sharePostcard() async {
    final context = this.context;
    final boundary = _postcardKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    HapticFeedback.mediumImpact();
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null || !mounted) return;
      final file = XFile.fromData(
        bytes.buffer.asUint8List(),
        mimeType: 'image/png',
        name: 'inkvoy-month.png',
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: 'My month in Inkvoy — every page is a voyage.',
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share the postcard — try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = ref.watch(readingStatsProvider);
    final saved = ref.watch(savedRepoProvider);
    final sessions = ref.watch(sessionsRepoProvider);

    final readingNow = saved.where((e) => e.shelf == Shelf.reading).length;
    final finished = saved.where((e) => e.shelf == Shelf.finished).length;
    final thisWeek = stats.last14Days
        .where(
          (d) =>
              DateTime.now().difference(d.day).inDays <=
                  (DateTime.now().weekday - 1) &&
              d.minutes > 0,
        )
        .fold<int>(0, (sum, d) => sum + d.minutes);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          10,
          AppSpacing.page,
          96,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insights',
                      style: AppTheme.serif(size: 32, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    if (stats.currentStreak > 0)
                      Row(
                        children: [
                          const Icon(
                            PhosphorIconsFill.flame,
                            size: 16,
                            color: Color(0xFF8A8A8A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${stats.currentStreak}-day streak — keep it burning',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      )
                    else
                      Text(
                        'Your reading at a glance',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              _ChartToggle(
                weekly: _weekly,
                onChanged: (b) => setState(() => _weekly = b),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (stats.isZero && sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: PhosphorIconsRegular.chartLineUp,
                kicker: 'Journal',
                title: 'No reading yet',
                message:
                    'Open any book and read for a few minutes — this page starts tracking right away.',
                action: FilledButton.icon(
                  onPressed: () {
                    final first = saved.isNotEmpty ? saved.first.book : null;
                    if (first != null) pushReader(context, first);
                  },
                  icon: const Icon(PhosphorIconsRegular.bookOpenText, size: 18),
                  label: Text(firstSaveTitle(saved)),
                ),
              ),
            )
          else ...[
            _StatRow(
              stats: stats,
              readingNow: readingNow,
              finished: finished,
              thisWeek: thisWeek,
            ),
            const SizedBox(height: 18),
            _chartContainer(theme, stats, _weekly),
            const SizedBox(height: 18),
            _HeatmapCard(
              days: _calendarDays(sessions),
              muted: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 18),
            _JournalCard(
              boundaryKey: _postcardKey,
              monthMinutes: _monthMinutes(sessions),
              streakNow: stats.currentStreak,
              bestStreak: stats.bestStreak,
              finished: finished,
              topShelf: _topShelf(saved),
              onShare: _sharePostcard,
            ),
            const SizedBox(height: 18),
            _sessionsHeader(theme, sessions),
            ...sessions.take(12).map((s) => _SessionTile(session: s)),
            const SizedBox(height: 24),
            if (stats.last14Days.fold<int>(0, (sum, d) => sum + d.minutes) == 0)
              Center(
                child: Text(
                  'Sessions land here the moment you read.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }

  String firstSaveTitle(List<SavedEntry> saved) {
    if (saved.isEmpty) return 'Explore books';
    final t = saved.first.book.title;
    return t.length > 14 ? '${t.substring(0, 14)}…' : t;
  }

  Widget _chartContainer(ThemeData theme, ReadingStats stats, bool weekly) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: weekly
          ? _WeeklyChart(days: stats.last14Days)
          : _HoursRow(stats: stats),
    );
  }

  Widget _sessionsHeader(ThemeData theme, List<ReadingSession> sessions) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Recent sessions',
            style: AppTheme.serif(size: 20, weight: FontWeight.w700),
          ),
        ),
        Text('${sessions.length} total', style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _ChartToggle extends StatelessWidget {
  const _ChartToggle({required this.weekly, required this.onChanged});
  final bool weekly;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(theme, weekly, Icons.bar_chart_rounded, () => onChanged(true)),
          _seg(
            theme,
            !weekly,
            Icons.calendar_month_rounded,
            () => onChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _seg(ThemeData theme, bool active, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 17,
          color: active
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.stats,
    required this.readingNow,
    required this.finished,
    required this.thisWeek,
  });
  final ReadingStats stats;
  final int readingNow;
  final int finished;
  final int thisWeek;

  @override
  Widget build(BuildContext context) {
    final data = <(_Stat, String)>[
      (
        _Stat(id: PhosphorIconsFill.clock, label: 'Total'),
        ReadingStats.formatMinutes(stats.totalMinutes),
      ),
      (
        _Stat(id: PhosphorIconsFill.alarm, label: 'This week'),
        ReadingStats.formatMinutes(thisWeek),
      ),
      (
        _Stat(id: PhosphorIconsFill.bookOpen, label: 'In progress'),
        '$readingNow',
      ),
      (
        _Stat(id: PhosphorIconsFill.checkCircle, label: 'Finished'),
        '$finished',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (s, v) in data)
              SizedBox(
                width: (c.maxWidth - 10) / 2,
                child: _StatCell(stat: s, value: v),
              ),
          ],
        );
      },
    );
  }
}

class _Stat {
  const _Stat({required this.id, required this.label});
  final IconData id;
  final String label;
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat, required this.value});
  final _Stat stat;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(stat.id, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTheme.serif(size: 18, weight: FontWeight.w700),
                ),
                Text(
                  stat.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.days});
  final List<DayTotal> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = days.fold<int>(0, (m, d) => d.minutes > m ? d.minutes : m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Last 14 days',
                style: theme.textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              max == 0
                  ? 'No minutes yet'
                  : 'Top: ${ReadingStats.formatMinutes(max)}',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 158,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.minutes > 0)
                          Text(
                            d.minutes >= 60
                                ? '${d.minutes ~/ 60}h'
                                : '${d.minutes}m',
                            style: theme.textTheme.labelSmall!.copyWith(
                              fontSize: 9,
                            ),
                          ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                              duration: const Duration(milliseconds: 520),
                              curve: Curves.easeOutCubic,
                              height: max == 0 ? 3 : (d.minutes / max) * 92,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary.withValues(
                                      alpha: 0.30,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            )
                            .animate(delay: 150.ms)
                            .fadeIn(duration: 400.ms)
                            .scaleY(
                              begin: 0,
                              end: 1,
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.bottomCenter,
                            ),
                        const SizedBox(height: 6),
                        Text(
                          d.day.weekday == 1
                              ? 'M'
                              : d.day.weekday == 2
                              ? 'T'
                              : d.day.weekday == 3
                              ? 'W'
                              : d.day.weekday == 4
                              ? 'T'
                              : d.day.weekday == 5
                              ? 'F'
                              : d.day.weekday == 6
                              ? 'S'
                              : 'S',
                          style: theme.textTheme.labelSmall!.copyWith(
                            fontSize: 9,
                            color:
                                d.day.weekday == DateTime.now().weekday &&
                                    DateTime.now().difference(d.day).inDays == 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight:
                                d.day.weekday == DateTime.now().weekday &&
                                    DateTime.now().difference(d.day).inDays == 0
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({required this.stats});
  final ReadingStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stats.totalMinutes;
    final goal = 8 * 60;
    final pct = (total / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              ReadingStats.formatMinutes(total),
              style: AppTheme.serif(size: 34, weight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Text('cumulative in Inkvoy', style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: pct),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 10,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(pct * 100).toStringAsFixed(0)}% of an 8-hour reading goal',
          style: theme.textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});
  final ReadingSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saved = ref.watch(savedRepoProvider);
    final entry = saved.where((e) => e.book.key == session.bookKey).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child:
          Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: entry != null
                      ? () => pushReader(context, entry.book)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            PhosphorIconsFill.bookOpen,
                            size: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.bookTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              Text(
                                _sessionHeader(context, session),
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          session.minutes > 0 ? '${session.minutes}m' : '<1m',
                          style: theme.textTheme.titleSmall!.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: session.minutes))
              .fadeIn(duration: 300.ms)
              .slideX(begin: -0.1, end: 0),
    );
  }

  String _sessionHeader(BuildContext context, ReadingSession s) {
    final now = DateTime.now();
    final start = s.start.toLocal();
    final hm = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(start),
      alwaysUse24HourFormat: false,
    );
    if (start.year == now.year &&
        start.month == now.month &&
        start.day == now.day) {
      return 'Today · $hm';
    }
    if (now.difference(start).inDays == 1) return 'Yesterday · $hm';
    return '${start.month}/${start.day} · $hm';
  }
}

/// Six-week reading heatmap in the monochrome ink language.
class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.days, required this.muted});
  final List<DayTotal> days;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final now = DateTime.now();
    final cellW = (theme.textTheme.labelSmall?.fontSize ?? 10) * 2.1;

    Widget cell(DayTotal d) {
      final isToday =
          now.year == d.day.year &&
          now.month == d.day.month &&
          now.day == d.day.day;
      final m = d.minutes;
      final level = m == 0
          ? 0.0
          : m < 21
          ? 0.18
          : m < 46
          ? 0.42
          : m < 91
          ? 0.68
          : 1.0;
      return Tooltip(
        message:
            '${DateFormat('MMM d').format(d.day)} — ${ReadingStats.formatMinutes(m)}',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          width: cellW,
          height: cellW,
          decoration: BoxDecoration(
            color: level == 0
                ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                : theme.colorScheme.primary.withValues(alpha: level),
            borderRadius: BorderRadius.circular(5),
            border: isToday ? Border.all(color: primary, width: 1.4) : null,
          ),
        ),
      );
    }

    final lead = days.first.day.weekday - 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reading heatmap',
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                DateFormat('MMMM yyyy').format(DateTime.now()),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: Text(
                    const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][c],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall!.copyWith(
                      fontSize: 9,
                      color: muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: cellW * 0.28,
            runSpacing: 6,
            children: [
              for (var i = 0; i < lead; i++)
                SizedBox(width: cellW, height: cellW),
              for (final d in days) cell(d),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              Text(
                'Less',
                style: theme.textTheme.labelSmall!.copyWith(
                  fontSize: 9,
                  color: muted,
                ),
              ),
              const SizedBox(width: 6),
              for (final a in [0.05, 0.18, 0.42, 0.68, 1.0])
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                'More',
                style: theme.textTheme.labelSmall!.copyWith(
                  fontSize: 9,
                  color: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }
}

/// Shareable month-in-review postcard, rendered in the brand ink.
class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.boundaryKey,
    required this.monthMinutes,
    required this.streakNow,
    required this.bestStreak,
    required this.finished,
    required this.topShelf,
    required this.onShare,
  });
  final GlobalKey boundaryKey;
  final int monthMinutes;
  final int streakNow;
  final int bestStreak;
  final int finished;
  final String? topShelf;
  final VoidCallback onShare;

  static const _ink = Color(0xFF181818);
  static const _ink2 = Color(0xFF232323);
  static const _bedrock = Color(0xFFF3EFE7);
  static const _mute = Color(0xFFB7B2A8);
  static const _rule = Color(0x33FFFFFF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: boundaryKey,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_ink, _ink2],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                AppShadows.raised(_ink, alpha: 0.30, blur: 24, dy: 12),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const InkvoyMark(size: 18, color: _bedrock),
                    const SizedBox(width: 8),
                    Text(
                      'inkvoy',
                      style: AppTheme.serif(
                        size: 17,
                        weight: FontWeight.w700,
                        italic: true,
                        color: _bedrock,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'MONTH IN INKVOY',
                      style: TextStyle(
                        color: _mute,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  DateFormat('MMMM yyyy').format(now),
                  style: AppTheme.serif(
                    size: 26,
                    weight: FontWeight.w600,
                    italic: true,
                    color: _mute,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ReadingStats.formatMinutes(monthMinutes),
                  style: AppTheme.serif(
                    size: 48,
                    weight: FontWeight.w700,
                    color: _bedrock,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'read this month',
                  style: TextStyle(
                    color: _mute,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: const [
                    Expanded(child: Divider(color: _rule)),
                    SizedBox(width: 10),
                    Text('❦', style: TextStyle(color: _mute, fontSize: 13)),
                    SizedBox(width: 10),
                    Expanded(child: Divider(color: _rule)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _mini('${streakNow}d', 'Streak'),
                    _div(),
                    _mini('${bestStreak}d', 'Best streak'),
                    _div(),
                    _mini('$finished', 'Titles finished'),
                  ],
                ),
                if (topShelf != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: _rule),
                    ),
                    child: Text(
                      'Front shelf · $topShelf',
                      style: TextStyle(
                        color: _bedrock,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Every page is a voyage.',
                    style: TextStyle(
                      color: _mute,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onShare,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          icon: const Icon(PhosphorIconsRegular.shareNetwork, size: 18),
          label: const Text('Share postcard'),
        ),
      ],
    );
  }

  Widget _mini(String v, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            v,
            style: AppTheme.serif(
              size: 26,
              weight: FontWeight.w700,
              color: _bedrock,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: _mute,
              fontSize: 10.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _div() {
    return Container(width: 1, height: 30, color: _rule);
  }
}
