import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/book.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Real covers used for the flying-selection effect (Open Library by ISBN).
const _flyingCoverIsbns = <String, String>{
  'fantasy': '9780385534635', // The Night Circus
  'romance': '9780316556347', // Circe
  'science fiction': '9780441013593', // Dune
  'classics': '9780141439518', // Pride and Prejudice
  'mystery': '9781984827627', // Where the Crawdads Sing
  'young adult': '9780525559474', // The Midnight Library
};

IconData _iconFor(String genre) => switch (genre) {
  'mystery' => PhosphorIconsRegular.detective,
  'fantasy' => PhosphorIconsRegular.sparkle,
  'romance' => PhosphorIconsRegular.heart,
  'science fiction' => PhosphorIconsRegular.planet,
  'thriller' => PhosphorIconsRegular.lightning,
  'classics' => PhosphorIconsRegular.bookmarkSimple,
  'biography' => PhosphorIconsRegular.user,
  'poetry' => PhosphorIconsRegular.feather,
  'history' => PhosphorIconsRegular.hourglass,
  'young adult' => PhosphorIconsRegular.rocketLaunch,
  'nonfiction' => PhosphorIconsRegular.sealCheck,
  _ => PhosphorIconsRegular.bookOpenText,
};

/// Multi-select genre picker (max [maxSelect]). Animated card grid with a
/// spring-pop select state and a flying real-cover effect as selections land
/// in the counter shelf. Used by onboarding step & settings.
class GenrePicker extends StatefulWidget {
  const GenrePicker({
    super.key,
    required this.selected,
    required this.onToggle,
    this.maxSelect = 3,
    this.title = 'Pick up to 3 genres you love',
    this.subtitle =
        'We\'ll steer your home shelves toward stories you\'ll adore.',
    this.compact = false,
  });

  final List<String> selected;
  final ValueChanged<String> onToggle;
  final int maxSelect;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  State<GenrePicker> createState() => _GenrePickerState();
}

class _GenrePickerState extends State<GenrePicker>
    with SingleTickerProviderStateMixin {
  final Map<int, GlobalKey> _cardKeys = {};
  final _targetKey = GlobalKey();

  _Flight? _flight;
  late final AnimationController _fly;

  @override
  void initState() {
    super.initState();
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _flight = null);
      });
  }

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  Rect? _box(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final rb = ctx.findRenderObject();
    if (rb is! RenderBox) return null;
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return null;
    return rb.localToGlobal(Offset.zero, ancestor: overlay) & rb.size;
  }

  void _handleTap(int i, String g) {
    HapticFeedback.selectionClick();
    final willSelect =
        !widget.selected.contains(g) &&
        widget.selected.length < widget.maxSelect;
    widget.onToggle(g);
    if (willSelect) _launchFlight(i, g);
  }

  void _launchFlight(int i, String g) {
    final from = _box(_cardKeys[i]!);
    final to = _box(_targetKey);
    if (from == null || to == null) return;
    setState(() {
      _flight = _Flight(
        from: from,
        to: to,
        isbn: _flyingCoverIsbns[g],
        label: Genres.display(g),
      );
      _fly.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;
    if (widget.compact) {
      body = Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: List.generate(Genres.popular.length, (i) {
          final g = Genres.popular[i];
          return _CompactChip(
            genre: g,
            selected: widget.selected.contains(g),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onToggle(g);
            },
          );
        }),
      );
    } else {
      final selected = widget.selected;
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, cons) => SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: cons.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GridView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.7,
                                ),
                            itemCount: Genres.popular.length,
                            itemBuilder: (context, i) {
                              final g = Genres.popular[i];
                              final cardKey = _cardKeys[i] ??= GlobalKey();
                              return _GenreCard(
                                key: cardKey,
                                genre: g,
                                index: i,
                                selected: selected.contains(g),
                                enabled:
                                    !selected.contains(g) &&
                                    selected.length >= widget.maxSelect,
                                onTap: () => _handleTap(i, g),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          Row(
                            key: _targetKey,
                            children: List.generate(
                              widget.maxSelect,
                              (i) => Expanded(
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(
                                    'seg-$i-${selected.length > i}',
                                  ),
                                  duration: const Duration(milliseconds: 380),
                                  curve: Curves.easeOutBack,
                                  tween: Tween(begin: 0.6, end: 1.0),
                                  builder: (_, v, child) =>
                                      Transform.scale(scale: v, child: child),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    height: 4,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: i < selected.length
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_flight != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _fly,
                  builder: (context, child) {
                    final f = _flight!;
                    final origin =
                        (context.findRenderObject() as RenderBox?)
                            ?.localToGlobal(Offset.zero) ??
                        Offset.zero;
                    final v = Curves.easeInOutCubic.transform(_fly.value);
                    final fromCenter = f.from.center - origin;
                    final toCenter = f.to.center - origin;
                    final w = _lerp(f.from.width * 0.5, 30, v);
                    final h = _lerp(f.from.height * 0.5, 44, v);
                    final pos =
                        Offset.lerp(
                          fromCenter,
                          toCenter - const Offset(14, 24),
                          v,
                        )! -
                        Offset(w / 2, 0);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fromRect(
                          rect: Rect.fromLTWH(pos.dx, pos.dy, w, h),
                          child: Transform.rotate(
                            angle: 0.6 * math.sin(v * math.pi) - 0.14,
                            child: Opacity(
                              opacity: (1 - ((v - 0.7) / 0.3)).clamp(0, 1),
                              child: _FlyCover(
                                isbn: f.isbn,
                                label: f.label,
                                radius: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.compact) ...[
            const SizedBox(height: 14),
            _editorialTitle(
              widget.title,
              theme.colorScheme.onSurface,
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.2, end: 0),
            const SizedBox(height: 20),
          ],
          Expanded(child: body),
        ],
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Serif title with the trailing phrase set as italic — the editorial voice.
  Widget _editorialTitle(String raw, Color fg) {
    final baseStyle = AppTheme.serif(
      size: 26,
      weight: FontWeight.w700,
      color: fg,
      height: 1.1,
    );
    final accentStyle = AppTheme.serif(
      size: 26,
      weight: FontWeight.w600,
      italic: true,
      color: fg,
      height: 1.1,
    );
    final words = raw.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return Text(raw, style: baseStyle);
    final accent = words.sublist(words.length - 2).join(' ');
    final base = words.sublist(0, words.length - 2).join(' ');
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: base.isEmpty ? '' : '$base '),
          TextSpan(text: accent, style: accentStyle),
        ],
      ),
    );
  }
}

class _Flight {
  const _Flight({
    required this.from,
    required this.to,
    this.isbn,
    required this.label,
  });
  final Rect from;
  final Rect to;
  final String? isbn;
  final String label;
}

/// A tiny real cover used for the flying-selection effect, with a designed
/// tint plate fallback when no cover exists for a genre.
class _FlyCover extends StatelessWidget {
  const _FlyCover({this.isbn, required this.label, this.radius = 4});
  final String? isbn;
  final String label;
  final double radius;

  Widget _plate() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B3B3B), Color(0xFF222222)],
      ),
    ),
    alignment: Alignment.center,
    child: Text(
      label.isEmpty ? '?' : label[0].toUpperCase(),
      style: AppTheme.serif(
        size: 15,
        weight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: isbn == null
          ? _plate()
          : CachedNetworkImage(
              imageUrl: 'https://covers.openlibrary.org/b/isbn/$isbn-M.jpg',
              fit: BoxFit.cover,
              memCacheWidth: 160,
              memCacheHeight: 220,
              fadeInDuration: const Duration(milliseconds: 160),
              placeholder: (_, __) => _plate(),
              errorWidget: (_, __, ___) => _plate(),
            ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  const _GenreCard({
    super.key,
    required this.genre,
    required this.index,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String genre;
  final int index;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Genres.display(genre);
    return TweenAnimationBuilder<double>(
      key: ValueKey('pop-$selected'),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0.9, end: 1.0),
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child:
          GestureDetector(
                onTap: enabled ? null : onTap,
                child: Opacity(
                  opacity: enabled ? 1 : 0.45,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.10,
                              ),
                        width: 1.2,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : const [],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.onPrimary.withValues(
                                    alpha: 0.16,
                                  )
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.05,
                                  ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _iconFor(genre),
                            size: 18,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.sans(
                              size: 14.5,
                              weight: FontWeight.w600,
                              color: selected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                              height: 1.15,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (c, a) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: a,
                              curve: Curves.easeOutBack,
                            ),
                            child: c,
                          ),
                          child: selected
                              ? Icon(
                                  PhosphorIconsFill.checkCircle,
                                  size: 20,
                                  color: theme.colorScheme.onPrimary,
                                  key: const ValueKey('on'),
                                )
                              : Icon(
                                  PhosphorIconsRegular.circle,
                                  size: 20,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.16,
                                  ),
                                  key: const ValueKey('off'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: index * 34))
              .fadeIn(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
              )
              .slideY(begin: 0.15, end: 0),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({
    required this.genre,
    required this.selected,
    required this.onTap,
  });
  final String genre;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(genre),
              size: 14,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              Genres.display(genre),
              style: AppTheme.sans(
                size: 13,
                weight: FontWeight.w600,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
