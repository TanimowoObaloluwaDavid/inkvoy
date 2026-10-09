import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/book.dart';
import '../../core/models/reading_session.dart';
import '../../core/providers/providers.dart';
import '../../core/router/nav.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/states.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({
    super.key,
    required this.bookKey,
    this.book,
    this.heroTag,
  });
  final String bookKey;
  final Book? book;
  final String? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = book;
    final detail = ref.watch(workDetailProvider(bookKey));
    final saved = ref.watch(savedRepoProvider);
    final entry = saved.where((e) => e.book.key == bookKey).firstOrNull;

    return detail.when(
      loading: () => fallback == null
          ? const _DetailLoading()
          : _DetailBody(
              book: fallback,
              entry: entry,
              bookKey: bookKey,
              heroTag: heroTag,
            ),
      error: (e, _) => fallback == null
          ? Scaffold(body: ErrorState(message: '$e'))
          : _DetailBody(
              book: fallback,
              entry: entry,
              bookKey: bookKey,
              heroTag: heroTag,
            ),
      data: (d) {
        final merged = Book(
          key: d.key,
          title: d.title.isEmpty ? (fallback?.title ?? '') : d.title,
          author: d.author ?? fallback?.author,
          firstPublishYear: d.firstPublishYear ?? fallback?.firstPublishYear,
          coverI: d.coverI ?? fallback?.coverI,
          isbn: (d.isbn?.isNotEmpty ?? false)
              ? d.isbn!
              : (fallback?.isbn ?? ''),
          covers: d.covers.isEmpty ? (fallback?.covers ?? const []) : d.covers,
          editionCount: d.editionCount,
          pageCount: d.pageCount,
          rating: d.rating ?? fallback?.rating,
          ratingCount: d.ratingCount != 0
              ? d.ratingCount
              : (fallback?.ratingCount ?? 0),
          subjects: d.subjects.isEmpty
              ? (fallback?.subjects ?? const [])
              : d.subjects,
          authorKeys: d.authorKeys.isEmpty
              ? (fallback?.authorKeys ?? const [])
              : d.authorKeys,
          description: d.description.isEmpty
              ? (fallback?.description ?? '')
              : d.description,
        );
        return _DetailBody(
          book: merged,
          entry: entry,
          bookKey: bookKey,
          heroTag: heroTag,
        );
      },
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          Center(child: SkeletonBox(width: 140, height: 210)),
          SizedBox(height: 20),
          SkeletonBox(width: 220, height: 22),
          SizedBox(height: 12),
          SkeletonBox(width: 150, height: 14),
          SizedBox(height: 26),
          SkeletonBox(height: 16),
          SizedBox(height: 10),
          SkeletonBox(height: 16),
          SizedBox(height: 10),
          SkeletonBox(height: 16, width: 240),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({
    required this.book,
    required this.entry,
    required this.bookKey,
    this.heroTag,
  });
  final Book book;
  final SavedEntry? entry;
  final String bookKey;
  final String? heroTag;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Book get book => widget.book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = CoverPalette.forBook(book);
    final saved = widget.entry;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 330,
                backgroundColor: Colors.transparent,
                stretch: true,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(colors[0], Colors.white, 0.05)!,
                          Color.lerp(colors[1], Colors.black, 0.15)!,
                        ],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          top: 96,
                          left: 0,
                          right: 0,
                          child: Center(
                            child:
                                Hero(
                                      tag:
                                          widget.heroTag ??
                                          coverTag('x', book.key),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: BookCover(
                                          book: book,
                                          width: 138,
                                          height: 206,
                                          radius: 16,
                                          size: 'L',
                                        ),
                                      ),
                                    )
                                    .animate(delay: 120.ms)
                                    .fadeIn()
                                    .scale(
                                      begin: const Offset(0.92, 0.92),
                                      end: const Offset(1, 1),
                                      curve: Curves.easeOutBack,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        child: _Header(book: book),
                      ),
                      const SizedBox(height: 14),
                      _ActionRow(
                        book: book,
                        entry: saved,
                        onStart: _startReading,
                        onSave: _saveToggle,
                      ),
                      const SizedBox(height: 22),
                      _About(book: book),
                      if (book.subjects.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: book.subjects
                              .take(8)
                              .map(
                                (s) => Chip(
                                  label: Text(
                                    s,
                                    style: theme.textTheme.labelMedium,
                                  ),
                                  avatar: const Icon(
                                    PhosphorIconsRegular.tag,
                                    size: 14,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
              if (book.authorKeys.isNotEmpty)
                SliverToBoxAdapter(
                  child: _AuthorRail(
                    authorKey: book.authorKeys.first,
                    book: book,
                  ),
                ),
              if (book.subjects.isNotEmpty)
                SliverToBoxAdapter(
                  child: _RelatedRail(subject: book.subjects.first, book: book),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 44,
              colors: const [
                Color(0xFF111111),
                Color(0xFF6E6E6E),
                Color(0xFFD0D0D0),
                Color(0xF2FFFFFF),
              ],
              gravity: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  void _startReading() {
    ref.read(savedRepoProvider.notifier).addBook(book, shelf: Shelf.reading);
    context.push('/reader/${book.key}', extra: book);
  }

  void _saveToggle() async {
    final repo = ref.read(savedRepoProvider.notifier);
    if (widget.entry == null) {
      HapticFeedback.lightImpact();
      repo.addBook(book, shelf: Shelf.want);
      _confetti.play();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved to your library')));
    } else {
      final result = await showModalBottomSheet<Object>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final theme = Theme.of(context);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Move to a shelf', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  for (final s in Shelf.values)
                    ListTile(
                      leading: Icon(
                        _shelfIcon(s),
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(s.label),
                      trailing: widget.entry?.shelf == s
                          ? const Icon(PhosphorIconsFill.check, size: 18)
                          : null,
                      onTap: () => Navigator.pop(context, s),
                    ),
                  const Divider(height: 24),
                  ListTile(
                    leading: Icon(
                      PhosphorIconsRegular.trash,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('Remove from library'),
                    onTap: () => Navigator.pop(context, 'remove'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (result == null) return;
      if (result == 'remove') {
        repo.remove(book.key);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from library')));
      } else {
        repo.setShelf(book.key, result as Shelf);
        HapticFeedback.lightImpact();
      }
    }
  }

  IconData _shelfIcon(Shelf s) => switch (s) {
    Shelf.want => PhosphorIconsRegular.bookmarkSimple,
    Shelf.reading => PhosphorIconsRegular.bookOpen,
    Shelf.finished => PhosphorIconsFill.checkCircle,
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.book});
  final Book book;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: ValueKey(book.key),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: AppTheme.serif(size: 26, weight: FontWeight.w700),
        ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.2, end: 0),
        const SizedBox(height: 6),
        Text(
          book.author ?? 'Unknown author',
          style: theme.textTheme.bodyMedium!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ).animate(delay: 100.ms).fadeIn(),
        const SizedBox(height: 12),
        Row(
          children: [
            _Stars(rating: book.rating ?? 0, count: book.ratingCount),
            const SizedBox(width: 14),
            if (book.firstPublishYear != null)
              Text(
                '${book.firstPublishYear}',
                style: theme.textTheme.labelLarge!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.count});
  final double rating;
  final int count;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: rating),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, v, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            v >= 0.75 ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
            size: 17,
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 3),
          Text(
            reading(v).toStringAsFixed(1),
            style: theme.textTheme.titleMedium!.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text('(${_compact(count)})', style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}

double reading(double v) => v.clamp(0, 5).toDouble();

String _compact(int n) {
  if (n < 1000) return '$n';
  return '${(n / 1000).toStringAsFixed(1)}k';
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.book,
    required this.entry,
    required this.onStart,
    required this.onSave,
  });
  final Book book;
  final SavedEntry? entry;
  final VoidCallback onStart;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onStart,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: AppTheme.sans(size: 15, weight: FontWeight.w700),
            ),
            icon: const Icon(PhosphorIconsRegular.play, size: 18),
            label: const Text('Start reading'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: onSave,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(52, 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: entry == null
              ? const Icon(PhosphorIconsRegular.bookmarkSimple)
              : Icon(
                  PhosphorIconsFill.bookmarkSimple,
                  color: theme.colorScheme.primary,
                ),
        ),
      ],
    );
  }
}

class _About extends StatefulWidget {
  const _About({required this.book});
  final Book book;
  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desc = widget.book.description.trim();
    if (desc.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          'No synopsis yet — this book awaits its story description on Open Library.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'About this book',
              style: theme.textTheme.titleLarge,
            ).animate(delay: 120.ms).fadeIn(),
            const Spacer(),
            if (desc.length > 220)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Text(
            desc,
            maxLines: _expanded ? null : 5,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium!.copyWith(
              height: 1.65,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthorRail extends ConsumerWidget {
  const _AuthorRail({required this.authorKey, required this.book});
  final String authorKey;
  final Book book;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = book.author?.split(',').first ?? 'Author';
    final works = ref.watch(authorWorksProvider(authorKey));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Row(
            children: [
              _AuthorAvatar(authorKey: authorKey, name: name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTheme.serif(
                        size: 17,
                        weight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Author',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(title: 'More by $name'),
        works.when(
          loading: () =>
              const SkeletonShelf(coverWidth: 96, coverHeight: 148, count: 4),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) => list.isEmpty || list.length <= 1
              ? const SizedBox.shrink()
              : SizedBox(
                  height: 208,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final b = list[i];
                      if (b.key == book.key) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () => context.push('/book/${b.key}', extra: b),
                        child: Hero(
                          tag: coverTag('a', b.key),
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
                ),
        ),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.authorKey, required this.name});
  final String authorKey;
  final String name;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl =
        'https://covers.openlibrary.org/a/olid/$authorKey-M.jpg?default=false';
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return ClipOval(
      child: SizedBox(
        width: 44,
        height: 44,
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          memCacheWidth: 160,
          memCacheHeight: 160,
          placeholder: (_, __) => _fallback(theme, initial),
          errorWidget: (_, __, ___) => _fallback(theme, initial),
        ),
      ),
    );
  }

  Widget _fallback(ThemeData theme, String initial) => Container(
    color: theme.colorScheme.surfaceContainer,
    alignment: Alignment.center,
    child: Text(
      initial,
      style: AppTheme.serif(
        size: 18,
        weight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
      ),
    ),
  );
}

class _RelatedRail extends ConsumerWidget {
  const _RelatedRail({required this.subject, required this.book});
  final String subject;
  final Book book;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelf = ref.watch(subjectShelfProvider(subject));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'You might also like'),
        shelf.when(
          loading: () =>
              const SkeletonShelf(coverWidth: 96, coverHeight: 148, count: 4),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : SizedBox(
                  height: 208,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final b = list[i];
                      if (b.key == book.key) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () => context.push('/book/${b.key}', extra: b),
                        child: Hero(
                          tag: coverTag('r', b.key),
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
                ),
        ),
      ],
    );
  }
}
