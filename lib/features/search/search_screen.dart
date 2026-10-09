import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/book.dart';
import '../../core/providers/providers.dart';
import '../../core/router/nav.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/shimmer.dart';
import '../../core/widgets/states.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _subject = '';
  String _sort = '';

  static const _popularSearches = [
    'Harry Potter',
    'The Alchemist',
    '1984',
    'Mistborn',
    'Pride and Prejudice',
    'The Hobbit',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  SearchArgs get _args =>
      (query: _query.text.trim(), subject: _subject, sort: _sort);

  bool get _idle => _query.text.trim().isEmpty && _subject.isEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SEARCH THE SHELVES',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ).animate(delay: 10.ms).fadeIn(),
                const SizedBox(height: 4),
                Text(
                  'Discover',
                  style: AppTheme.serif(size: 32, weight: FontWeight.w700),
                ).animate(delay: 40.ms).fadeIn().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 14),
                _SearchField(
                  controller: _query,
                  onChanged: _onChanged,
                  onClear: () {
                    _query.clear();
                    _onChanged('');
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        'All subjects',
                        '',
                        _subject,
                        (v) => setState(() => _subject = v),
                      ),
                      for (final s in const [
                        'fiction',
                        'mystery',
                        'fantasy',
                        'romance',
                        'classics',
                        'science fiction',
                      ])
                        _FilterChip(
                          _chipLabel(s),
                          s,
                          _subject,
                          (v) => setState(() => _subject = v),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text('Sort', style: theme.textTheme.labelMedium),
                      const SizedBox(width: 10),
                      ...['Relevance', 'Newest', 'Top rated'].asMap().entries.map(
                        (e) {
                          final label = e.value;
                          final value = ['', 'new', 'rating'][e.key];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                label,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _sort == value,
                              onSelected: (_) => setState(() => _sort = value),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(delay: 80.ms).fadeIn(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              child: _idle
                  ? _IdleSearch(
                      onPick: (q) {
                        _query.text = q;
                        _onChanged(q);
                        setState(() {});
                      },
                      onBrowse: (s) {
                        _query.clear();
                        setState(() => _subject = s);
                      },
                    )
                  : _Results(key: ValueKey(_args.toString()), args: _args),
            ),
          ),
        ],
      ),
    );
  }

  static String _chipLabel(String s) => s
      .split(' ')
      .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
      .join(' ');
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search titles, authors, subjects…',
        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(PhosphorIconsRegular.x, size: 18),
                onPressed: onClear,
              ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(this.label, this.value, this.current, this.onSelect);
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        selected: current == value,
        onSelected: (_) => onSelect(value),
      ),
    );
  }
}

class _IdleSearch extends StatelessWidget {
  const _IdleSearch({required this.onPick, required this.onBrowse});
  final ValueChanged<String> onPick;
  final ValueChanged<String> onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        4,
        AppSpacing.page,
        40,
      ),
      children: [
        Text(
          'Try one of these',
          style: theme.textTheme.titleMedium,
        ).animate(delay: 150.ms).fadeIn(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _SearchScreenState._popularSearches
              .map(
                (s) => ActionChip(
                  label: Text(s),
                  avatar: const Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 14,
                  ),
                  onPressed: () => onPick(s),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        Text(
          'Or browse a genre',
          style: theme.textTheme.titleMedium,
        ).animate(delay: 220.ms).fadeIn(),
        const SizedBox(height: 12),
        for (final (title, icon, subj) in [
          ('Fiction', PhosphorIconsRegular.bookOpenText, 'fiction'),
          ('Mystery & Thriller', PhosphorIconsRegular.eyeglasses, 'mystery'),
          ('Fantasy', PhosphorIconsRegular.planet, 'fantasy'),
          ('Romance', PhosphorIconsRegular.heart, 'romance'),
          ('Classics', PhosphorIconsRegular.heartbeat, 'classics'),
          ('Sci-Fi', PhosphorIconsRegular.rocket, 'science fiction'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GenreTile(
              title: title,
              icon: icon,
              onTap: () => onBrowse(subj),
            ),
          ),
      ],
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              const Icon(PhosphorIconsRegular.caretRight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({super.key, required this.args});
  final SearchArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(searchProvider(args));

    final query = args.query;

    return result.when(
      loading: () => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          4,
          AppSpacing.page,
          40,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.5,
        ),
        itemCount: 10,
        itemBuilder: (_, __) => SkeletonBox(radius: 12),
      ),
      error: (e, _) => ErrorState(
        message: '$e',
        onRetry: () => ref.invalidate(searchProvider(args)),
      ),
      data: (books) {
        if (books.isEmpty) {
          return EmptyState(
            icon: PhosphorIconsRegular.magnifyingGlassMinus,
            kicker: 'Search',
            title: 'Nothing found',
            message: query.isEmpty
                ? 'Try a different genre'
                : 'No shelves match "$query" yet.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            4,
            AppSpacing.page,
            40,
          ),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 130,
            mainAxisSpacing: 18,
            crossAxisSpacing: 12,
            childAspectRatio: 0.5,
          ),
          itemCount: books.length,
          itemBuilder: (context, i) => _ResultTile(book: books[i], index: i),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.book, required this.index});
  final Book book;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => pushBook(context, book, prefix: 's'),
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: coverTag('s', book.key),
                    child: BookCover(
                      book: book,
                      width: double.infinity,
                      height: 148,
                      radius: 12,
                    ),
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
                  if (book.rating != null && book.rating! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsFill.star,
                            size: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            book.rating!.toStringAsFixed(1),
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              )
              .animate(
                delay: Duration(milliseconds: (index * 45).clamp(0, 400)),
              )
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.15, end: 0),
    );
  }
}
