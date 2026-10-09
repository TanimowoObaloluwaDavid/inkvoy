import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/reading_session.dart';
import '../../core/providers/providers.dart';
import '../../core/router/nav.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/states.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  Shelf _shelf = Shelf.reading;
  bool _grid = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = ref.watch(savedRepoProvider);
    final shelfItems = entries.where((e) => e.shelf == _shelf).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              10,
              AppSpacing.page,
              4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                            'Your library',
                            style: AppTheme.serif(
                              size: 32,
                              weight: FontWeight.w700,
                            ),
                          )
                          .animate(delay: 30.ms)
                          .fadeIn()
                          .slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 2),
                      Text(
                        entries.isEmpty
                            ? 'Save stories for later'
                            : '${entries.length} saved',
                        style: theme.textTheme.bodySmall,
                      ).animate(delay: 60.ms).fadeIn(),
                    ],
                  ),
                ),
                _ViewToggle(
                  grid: _grid,
                  onToggle: () => setState(() => _grid = !_grid),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              12,
              AppSpacing.page,
              12,
            ),
            child: _ShelfTabs(
              current: _shelf,
              onChanged: (s) => setState(() => _shelf = s),
            ),
          ),
          Expanded(
            child: shelfItems.isEmpty
                ? EmptyState(
                    icon: _shelf == Shelf.want
                        ? PhosphorIconsRegular.bookmarkSimple
                        : PhosphorIconsRegular.bookOpenText,
                    kicker: _shelf == Shelf.reading
                        ? 'Reading'
                        : _shelf == Shelf.want
                        ? 'For later'
                        : 'Finished',
                    title: 'Nothing here yet',
                    message: _shelf == Shelf.reading
                        ? 'Books you are reading will show up right here.'
                        : _shelf == Shelf.want
                        ? 'Tap the bookmark on any book to keep it close.'
                        : 'Finished reads live here with your ratings.',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/discover'),
                      icon: const Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 18,
                      ),
                      label: const Text('Find books'),
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _grid
                        ? _LibraryGrid(items: shelfItems)
                        : _LibraryList(items: shelfItems),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.grid, required this.onToggle});
  final bool grid;
  final VoidCallback onToggle;
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
          _seg(theme, grid, PhosphorIconsFill.squaresFour, onIconsClick: () {}),
          _seg(theme, !grid, PhosphorIconsFill.list, onIconsClick: () {}),
        ],
      ),
    );
  }

  Widget _seg(
    ThemeData theme,
    bool active,
    IconData icon, {
    required VoidCallback onIconsClick,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ShelfTabs extends StatelessWidget {
  const _ShelfTabs({required this.current, required this.onChanged});
  final Shelf current;
  final ValueChanged<Shelf> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: Shelf.values.map((s) {
          final selected = s == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  s.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({required this.items});
  final List<SavedEntry> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        4,
        AppSpacing.page,
        96,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisSpacing: 18,
        crossAxisSpacing: 12,
        childAspectRatio: 0.48,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _GridTile(entry: items[i], index: i),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.entry, required this.index});
  final SavedEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = entry.book;
    return GestureDetector(
      onLongPress: () => showLibrarySheet(context, entry),
      onTap: () => pushBook(context, book, prefix: 'l'),
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Hero(
                        tag: coverTag('l', book.key),
                        child: BookCover(
                          book: book,
                          width: double.infinity,
                          height: 148,
                          radius: 12,
                        ),
                      ),
                      if (entry.shelf == Shelf.reading && entry.progress > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                            child: Container(
                              height: 20,
                              color: Colors.black.withValues(alpha: 0.55),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                      child: LinearProgressIndicator(
                                        value: entry.progress,
                                        minHeight: 3,
                                        backgroundColor: Colors.white24,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(entry.progress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (book.author != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        book.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                ],
              )
              .animate(
                delay: Duration(milliseconds: (index * 40).clamp(0, 320)),
              )
              .fadeIn(duration: 320.ms)
              .slideY(begin: 0.12, end: 0),
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({required this.items});
  final List<SavedEntry> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        4,
        AppSpacing.page,
        96,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final e = items[i];
        final book = e.book;
        return Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onLongPress: () => showLibrarySheet(context, e),
                onTap: () => pushBook(context, book, prefix: 'l'),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Hero(
                        tag: coverTag('l', book.key),
                        child: BookCover(
                          book: book,
                          width: 54,
                          height: 80,
                          radius: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall!.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (book.author != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  book.author!,
                                  maxLines: 1,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            if (e.shelf == Shelf.reading) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                      child: LinearProgressIndicator(
                                        value: e.progress,
                                        minHeight: 5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(e.progress * 100).toStringAsFixed(0)}%',
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .animate(delay: Duration(milliseconds: (i * 40).clamp(0, 320)))
            .fadeIn(duration: 320.ms)
            .slideY(begin: 0.12, end: 0);
      },
    );
  }
}

/// Long-press / bookmark-sheet shared by grid + list items.
Future<void> showLibrarySheet(BuildContext context, SavedEntry entry) async {
  final result = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          var progress = entry.progress;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BookCover(
                          book: entry.book,
                          width: 44,
                          height: 64,
                          radius: 6,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              entry.book.author ?? '',
                              maxLines: 1,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Shelf', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: Shelf.values
                        .map(
                          (s) => ChoiceChip(
                            label: Text(s.label),
                            selected: entry.shelf == s,
                            onSelected: (_) => Navigator.pop(ctx, s),
                          ),
                        )
                        .toList(),
                  ),
                  if (entry.shelf == Shelf.reading) ...[
                    const SizedBox(height: 18),
                    Text('Progress', style: theme.textTheme.labelLarge),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: progress,
                            onChanged: (v) => setSheetState(() => progress = v),
                            onChangeEnd: (v) =>
                                Navigator.pop(ctx, _ProgressResult(v)),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 28),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      PhosphorIconsRegular.bookOpen,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: const Text('Read now'),
                    onTap: () {
                      Navigator.pop(ctx);
                      pushReader(context, entry.book);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      PhosphorIconsRegular.trash,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: const Text('Remove from library'),
                    onTap: () => Navigator.pop(ctx, 'remove'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (result == null || context.mounted == false) return;
  final repo = ProviderScope.containerOf(
    context,
  ).read(savedRepoProvider.notifier);
  switch (result) {
    case 'remove':
      HapticFeedback.mediumImpact();
      repo.remove(entry.book.key);
      break;
    case _ProgressResult(:final value):
      repo.setProgress(entry.book.key, value);
      break;
    case Shelf s:
      HapticFeedback.selectionClick();
      repo.setShelf(entry.book.key, s);
      break;
  }
}

class _ProgressResult {
  const _ProgressResult(this.value);
  final double value;
}
