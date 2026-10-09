import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/book.dart';
import '../../core/models/reading_session.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/shimmer.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.book});
  final Book book;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  DateTime? _sessionStart;
  Timer? _minuteTimer;
  Timer? _uiTimer;
  double _progress = 0;
  int _elapsedSeconds = 0;
  int _savedAtMs = 0;
  int _lastDecile = 0;
  bool _showConfetti = false;
  final _confetti = ConfettiController(duration: const Duration(seconds: 4));
  // Captured up-front so persistence still works during dispose(), when the
  // widget's `ref` is no longer usable.
  late final SavedRepo _saved;
  late final SessionsRepo _sessions;

  static final _heading = RegExp(
    '^(chapter|prologue|preface|introduction|epilogue|part|the end)\\b.*\$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _saved = ref.read(savedRepoProvider.notifier);
    _sessions = ref.read(sessionsRepoProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _sessionStart = DateTime.now();
    _minuteTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      if (_elapsedSeconds % 30 == 0) setState(() {});
    });
    _uiTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted &&
          _savedAtMs != 0 &&
          DateTime.now().millisecondsSinceEpoch - _savedAtMs > 3000) {
        _persistProgress();
      }
    });
    // A book opened here lives on the Reading shelf. Deferred past the build
    // phase because mutating a provider during initState is not allowed.
    _lastDecile = ((_saved.entryFor(widget.book.key)?.progress ?? 0) * 10)
        .floor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _saved.addBook(widget.book, shelf: Shelf.reading);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minuteTimer?.cancel();
    _uiTimer?.cancel();
    _confetti.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _logSession();
    _persistProgress();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _logSession();
      _persistProgress();
    }
  }

  void _logSession() {
    final start = _sessionStart;
    if (start == null) return;
    final minutes = Duration(seconds: _elapsedSeconds).inMinutes;
    _sessionStart = null;
    if (minutes < 1) return;
    _sessions.add(
      ReadingSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        bookKey: widget.book.key,
        bookTitle: widget.book.title,
        coverI: widget.book.coverI,
        start: start,
        end: start.add(Duration(minutes: minutes)),
      ),
    );
  }

  void _onScroll() {
    final p = _scroll.hasClients && _scroll.position.maxScrollExtent > 0
        ? (_scroll.offset / _scroll.position.maxScrollExtent).clamp(0.0, 1.0)
        : 0.0;
    if (p > _progress + 0.001 || p < _progress - 0.001) {
      setState(() => _progress = p);
    }
    final decile = (p * 10).floor();
    if (decile != _lastDecile) {
      _lastDecile = decile;
      HapticFeedback.lightImpact();
    }
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 32) {
      if (!_showConfetti) {
        final repo = ref.read(savedRepoProvider.notifier);
        final wasFinished =
            repo.entryFor(widget.book.key)?.shelf == Shelf.finished;
        _persistProgress(forceComplete: true);
        if (!wasFinished) {
          _confetti.play();
          setState(() => _showConfetti = true);
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) setState(() => _showConfetti = false);
          });
        }
      } else {
        _persistProgress(forceComplete: true);
      }
    }
  }

  void _rate(int? rating) {
    HapticFeedback.selectionClick();
    ref.read(savedRepoProvider.notifier).setRating(widget.book.key, rating);
    setState(() {});
  }

  void _persistProgress({bool forceComplete = false}) {
    if (!mounted) return;
    _savedAtMs = DateTime.now().millisecondsSinceEpoch;
    final v = forceComplete ? 1.0 : _progress;
    _saved.setProgress(widget.book.key, v);
  }

  List<(bool isHeading, String text)> _paragraphs(String text) {
    return text
        .split(_splitter)
        .map((raw) {
          final t = raw.trim();
          if (t.isEmpty) return null;
          return (_heading.hasMatch(t), t);
        })
        .whereType<(bool, String)>()
        .toList();
  }

  static final _splitter = RegExp(r'\n\s*\n');

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(readerPrefsProvider);
    final theme = _palette(prefs.themeId);
    final textAsync = ref.watch(bookTextProvider(widget.book));

    return Scaffold(
      backgroundColor: theme.bg,
      body: Stack(
        children: [
          textAsync.when(
            loading: () => _ReaderLoading(theme: theme),
            error: (e, st) => _ReaderError(
              theme: theme,
              onRetry: () => ref.invalidate(bookTextProvider(widget.book)),
            ),
            data: (result) {
              final text = result.$1;
              final isSample = result.$2;
              final paragraphs = _paragraphs(text);
              if (paragraphs.length < 3) {
                return _ReaderError(
                  theme: theme,
                  onRetry: () => ref.invalidate(bookTextProvider(widget.book)),
                  empty: true,
                );
              }
              return _ReaderBody(
                theme: theme,
                prefs: prefs,
                book: widget.book,
                paragraphs: paragraphs,
                isSample: isSample,
                progress: _progress,
                elapsed: _elapsedSeconds,
                scroll: _scroll,
                restoreProgress:
                    ref
                        .read(savedRepoProvider.notifier)
                        .entryFor(widget.book.key)
                        ?.progress ??
                    0,
                rating: ref
                    .read(savedRepoProvider.notifier)
                    .entryFor(widget.book.key)
                    ?.myRating,
                onRate: _rate,
                onTapPrefs: _openPrefs,
                onClose: () => Navigator.of(context).maybePop(),
              );
            },
          ),
          if (_showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confetti,
                  blastDirection: -math.pi / 2,
                  emissionFrequency: 0.035,
                  numberOfParticles: 12,
                  gravity: 0.3,
                  maxBlastForce: 14,
                  minBlastForce: 5,
                  colors: [
                    theme.fg,
                    theme.accent,
                    theme.fg.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  _ReaderPalette _palette(String id) {
    for (final (name, bg, fg, accent) in ReaderThemes.all) {
      if (name == id) return _ReaderPalette(bg: bg, fg: fg, accent: accent);
    }
    final (_, bg, fg, accent) = ReaderThemes.all.first;
    return _ReaderPalette(bg: bg, fg: fg, accent: accent);
  }

  Future<void> _openPrefs() async {
    final current = ref.read(readerPrefsProvider);
    final picks = await showModalBottomSheet<_ReaderPrefsResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReaderPrefsSheet(initial: current),
    );
    if (picks == null) return;
    ref.read(readerPrefsProvider.notifier).update(picks.prefs);
    HapticFeedback.selectionClick();
  }
}

class _ReaderPalette {
  final Color bg;
  final Color fg;
  final Color accent;
  const _ReaderPalette({
    required this.bg,
    required this.fg,
    required this.accent,
  });
}

class _ReaderPrefsResult {
  final ReaderPrefs prefs;
  const _ReaderPrefsResult(this.prefs);
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.theme,
    required this.prefs,
    required this.book,
    required this.paragraphs,
    required this.isSample,
    required this.progress,
    required this.elapsed,
    required this.scroll,
    required this.restoreProgress,
    required this.rating,
    required this.onRate,
    required this.onTapPrefs,
    required this.onClose,
  });

  final _ReaderPalette theme;
  final ReaderPrefs prefs;
  final Book book;
  final List<(bool, String)> paragraphs;
  final bool isSample;
  final double progress;
  final int elapsed;
  final ScrollController scroll;
  final double restoreProgress;
  final int? rating;
  final ValueChanged<int?> onRate;
  final VoidCallback onTapPrefs;
  final VoidCallback onClose;

  int get _totalWords =>
      paragraphs.fold(0, (a, p) => a + p.$2.split(RegExp(r'\s+')).length);
  static const _wpm = 220;
  static const _titlePageEst = 400.0;

  /// Estimated cumulative top offset (px) of each list item + total height.
  /// Close enough for chapter jumps and position restore.
  (List<double>, double) _measure(
    BuildContext context,
    double horizontal,
    TextStyle body,
  ) {
    final inner = math.max(
      220.0,
      MediaQuery.sizeOf(context).width - horizontal * 2,
    );
    final wordsPerLine = math.max(4.0, inner / (body.fontSize! * 0.48));
    final linePx = body.fontSize! * (body.height ?? 1.5);
    final tops = <double>[];
    var acc = 0.0;
    for (var i = 0; i < paragraphs.length; i++) {
      tops.add(acc);
      final (isH, text) = paragraphs[i];
      final words = text.split(RegExp(r'\s+')).length;
      final lines = math.max(1, (words / wordsPerLine).ceil());
      var h = lines * linePx;
      if (i == 0) h += _titlePageEst;
      h += isH ? 74 : 18; // chapter-open block vs paragraph gap
      h += 4;
      acc += h;
    }
    tops.add(acc); // end-cap slot
    acc += 560; // generous room past the final page
    return (tops, acc);
  }

  List<(String, double)> _chapterIndex(List<double> tops) {
    final out = <(String, double)>[];
    for (var i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i].$1) out.add((paragraphs[i].$2, tops[i]));
    }
    return out;
  }

  Future<void> _openToc(
    BuildContext context,
    List<(String, double)> chapters,
    double total,
  ) async {
    final target = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bc) =>
          _TocSheet(chapters: chapters, total: total, accent: theme.accent),
    );
    if (target == null) return;
    HapticFeedback.selectionClick();
    scroll.animateTo(
      target.clamp(0, scroll.hasClients ? scroll.position.maxScrollExtent : 0),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = theme.fg;
    final muted = fg.withValues(alpha: 0.6);
    final rule = fg.withValues(alpha: 0.16);
    final font = prefs.serif ? 'Cormorant Garamond' : 'Inter';
    final topInset = MediaQuery.paddingOf(context).top;
    final totalWords = _totalWords;
    final minutesLeft = ((totalWords * (1 - progress)) / _wpm)
        .clamp(0.0, double.infinity)
        .round();
    final minutesRead = elapsed ~/ 60;
    final secondsRead = elapsed % 60;
    final textAlign = prefs.justify ? TextAlign.justify : TextAlign.start;

    final bodyStyle = TextStyle(
      fontFamily: font,
      fontSize: prefs.fontSize,
      height: prefs.lineHeight,
      color: fg,
    );
    final firstCharStyle = TextStyle(
      fontFamily: font,
      fontSize: prefs.fontSize * 2.05,
      height: 0.78,
      fontWeight: FontWeight.w700,
      color: theme.accent,
    );
    final horizontal = prefs.margin;
    final (tops, totalEst) = _measure(context, horizontal, bodyStyle);
    final chapters = _chapterIndex(tops);
    final restoreOffset = restoreProgress > 0.003
        ? restoreProgress * totalEst
        : 0.0;
    if (restoreOffset > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients && scroll.offset < 1) {
          scroll.jumpTo(
            restoreOffset.clamp(0.0, scroll.position.maxScrollExtent),
          );
        }
      });
    }

    return Column(
      children: [
        Container(
          color: theme.bg,
          padding: EdgeInsets.only(top: topInset),
          child: Row(
            children: [
              IconButton(
                onPressed: onClose,
                icon: Icon(PhosphorIconsRegular.arrowLeft, color: fg),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% · ${minutesLeft}m left',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: chapters.isEmpty
                    ? null
                    : () => _openToc(context, chapters, totalEst),
                icon: Icon(
                  PhosphorIconsRegular.listDashes,
                  color: chapters.isEmpty ? muted : fg,
                ),
                tooltip: chapters.isEmpty ? null : 'Contents',
              ),
              IconButton(
                onPressed: onTapPrefs,
                icon: Icon(PhosphorIconsRegular.textAa, color: fg),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 72),
            itemCount: paragraphs.length + 1,
            itemBuilder: (context, i) {
              // End-of-book panel.
              if (i == paragraphs.length) {
                return _EndCap(
                  theme: theme,
                  minutes: minutesRead,
                  seconds: secondsRead,
                  progress: progress,
                  rating: rating,
                  onRate: onRate,
                  onRetryHome: onClose,
                );
              }
              final isHeading = paragraphs[i].$1;
              final t = paragraphs[i].$2;
              final prevHeading = i > 0 && paragraphs[i - 1].$1;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (i == 0) ...[
                    _TitlePage(
                      book: book,
                      totalWords: totalWords,
                      fg: fg,
                      muted: muted,
                      theme: theme,
                      isSample: isSample,
                    ),
                    const SizedBox(height: 34),
                  ],
                  if (isHeading)
                    _ChapterOpen(heading: t, rule: rule, muted: muted)
                  else ...[
                    if (i == 0)
                      _ChapterOpen(heading: '', rule: rule, muted: muted)
                    else
                      const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _Paragraph(
                        rich: t,
                        first: prevHeading || i == 0,
                        textAlign: textAlign,
                        style: bodyStyle,
                        firstCharStyle: firstCharStyle,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        _ReaderFooter(
          theme: theme,
          progress: progress,
          elapsedSeconds: elapsed,
          minutesLeft: minutesLeft,
          totalWords: totalWords,
          onTapPrefs: onTapPrefs,
          muted: muted,
          accent: theme.accent,
        ),
      ],
    );
  }
}

class _TitlePage extends StatelessWidget {
  const _TitlePage({
    required this.book,
    required this.totalWords,
    required this.fg,
    required this.muted,
    required this.theme,
    this.isSample = false,
  });
  final Book book;
  final int totalWords;
  final Color fg;
  final Color muted;
  final _ReaderPalette theme;
  final bool isSample;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 26),
        BookCover(book: book, width: 108, height: 160, radius: 12),
        const SizedBox(height: 22),
        Text(
          book.title,
          textAlign: TextAlign.center,
          style: AppTheme.serif(
            size: 30,
            weight: FontWeight.w700,
            color: fg,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        if (book.author != null)
          Text(
            book.author!,
            textAlign: TextAlign.center,
            style: AppTheme.serif(size: 17, italic: true, color: muted),
          ),
        const SizedBox(height: 14),
        Text(
          isSample
              ? 'A reading preview · ${totalWords >= 1000 ? '${(totalWords / 1000).toStringAsFixed(1)}k' : totalWords} words'
              : 'A reading of ${totalWords >= 1000 ? '${(totalWords / 1000).toStringAsFixed(1)}k' : totalWords} words · public domain',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: muted,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        if (isSample)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: muted.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'FULL TEXT UNAVAILABLE · A PREVIEW IN ITS SPIRIT',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChapterOpen extends StatelessWidget {
  const _ChapterOpen({
    required this.heading,
    required this.rule,
    required this.muted,
  });
  final String heading;
  final Color rule;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Container(height: 1, color: rule)),
              const SizedBox(width: 12),
              Text('❦', style: TextStyle(color: muted, fontSize: 16)),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: rule)),
            ],
          ),
          if (heading.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              heading.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.6,
                color: muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({
    required this.rich,
    required this.first,
    required this.textAlign,
    required this.style,
    required this.firstCharStyle,
  });
  final String rich;
  final bool first;
  final TextAlign textAlign;
  final TextStyle style;
  final TextStyle firstCharStyle;

  @override
  Widget build(BuildContext context) {
    if (!first || rich.isEmpty) {
      return Text(rich, textAlign: textAlign, style: style);
    }
    // Drop-cap: first letter enlarged in the serif, remainder flows beside it.
    var t = rich;
    final cap = t.substring(0, 1);
    final rest = t.substring(1);
    return Text.rich(
      TextSpan(
        text: cap,
        style: firstCharStyle,
        children: [TextSpan(text: rest, style: style)],
      ),
      textAlign: textAlign,
      style: style,
    );
  }
}

class _EndCap extends StatelessWidget {
  const _EndCap({
    required this.theme,
    required this.minutes,
    required this.seconds,
    required this.progress,
    required this.rating,
    required this.onRate,
    required this.onRetryHome,
  });
  final _ReaderPalette theme;
  final int minutes;
  final int seconds;
  final double progress;
  final int? rating;
  final ValueChanged<int?> onRate;
  final VoidCallback onRetryHome;

  @override
  Widget build(BuildContext context) {
    final fg = theme.fg;
    final muted = fg.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Text('❦', style: TextStyle(color: muted, fontSize: 22)),
          const SizedBox(height: 14),
          Text(
            'THE END',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: muted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You reached the final page.',
            style: AppTheme.serif(size: 20, italic: true, color: fg),
          ),
          const SizedBox(height: 30),
          _StatBox(
            fg: fg,
            muted: muted,
            accent: theme.accent,
            progress: progress,
            minutes: minutes,
            seconds: seconds,
          ),
          const SizedBox(height: 30),
          Text(
            'How was it?',
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          _Stars(
            value: rating,
            onChanged: onRate,
            size: 34,
            fg: fg,
            accent: theme.accent,
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({
    required this.value,
    required this.onChanged,
    required this.size,
    required this.fg,
    required this.accent,
  });
  final int? value;
  final ValueChanged<int?> onChanged;
  final double size;
  final Color fg;
  final Color accent;

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
            size: size,
            color: filled ? accent : fg.withValues(alpha: 0.25),
          ),
          splashRadius: size * 0.7,
        );
      }),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.fg,
    required this.muted,
    required this.accent,
    required this.progress,
    required this.minutes,
    required this.seconds,
  });
  final Color fg;
  final Color muted;
  final Color accent;
  final double progress;
  final int minutes;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label) => Column(
      children: [
        Text(
          value,
          style: AppTheme.serif(size: 22, weight: FontWeight.w700, color: fg),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: fg.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          cell('${(progress * 100).toStringAsFixed(0)}%', 'Complete'),
          cell('$minutes:$seconds'.padLeft(5, '0'), 'This session'),
          cell('Done!', 'Book finished'),
        ],
      ),
    );
  }
}

class _ReaderFooter extends StatelessWidget {
  const _ReaderFooter({
    required this.theme,
    required this.progress,
    required this.elapsedSeconds,
    required this.minutesLeft,
    required this.totalWords,
    required this.onTapPrefs,
    required this.muted,
    required this.accent,
  });

  final _ReaderPalette theme;
  final double progress;
  final int elapsedSeconds;
  final int minutesLeft;
  final int totalWords;
  final VoidCallback onTapPrefs;
  final Color muted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return Container(
      color: theme.bg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: muted.withValues(alpha: 0.18),
                color: accent,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
              child: Row(
                children: [
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}% read',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progress >= 1
                          ? 'Finished — well read'
                          : 'Session ${m}m ${s.toString().padLeft(2, '0')}s · ~${minutesLeft}m left',
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ),
                  IconButton(
                    onPressed: onTapPrefs,
                    icon: Icon(
                      PhosphorIconsRegular.textAa,
                      size: 20,
                      color: accent,
                    ),
                    tooltip: 'Reader settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderPrefsSheet extends StatefulWidget {
  const _ReaderPrefsSheet({required this.initial});
  final ReaderPrefs initial;
  @override
  State<_ReaderPrefsSheet> createState() => _ReaderPrefsSheetState();
}

class _ReaderPrefsSheetState extends State<_ReaderPrefsSheet> {
  late ReaderPrefs _prefs = widget.initial;

  int get _widthIndex {
    const widths = [14.0, 22.0, 30.0];
    final idx = widths.indexOf(_prefs.margin);
    return idx == -1 ? 1 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reader settings',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      Navigator.pop(context, _ReaderPrefsResult(_prefs)),
                  icon: const Icon(PhosphorIconsFill.check, size: 22),
                ),
              ],
            ),
            Text('Theme', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: ReaderThemes.all.map((t) {
                final name = t.$1;
                final bg = t.$2;
                final selected = _prefs.themeId == name;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _prefs = _prefs.copyWith(themeId: name)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          height: 40,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: Icon(
                            PhosphorIconsFill.textT,
                            size: 16,
                            color: t.$3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(name, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text('Font size', style: theme.textTheme.bodyMedium),
                ),
                IconButton(
                  onPressed: _prefs.fontSize > 13
                      ? () => setState(
                          () => _prefs = _prefs.copyWith(
                            fontSize: (_prefs.fontSize - 1).clamp(13, 24),
                          ),
                        )
                      : null,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  icon: const Text(
                    'A−',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: (_prefs.fontSize - 13) / 11,
                    onChanged: (v) => setState(
                      () => _prefs = _prefs.copyWith(fontSize: 13 + v * 11),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _prefs.fontSize < 24
                      ? () => setState(
                          () => _prefs = _prefs.copyWith(
                            fontSize: (_prefs.fontSize + 1).clamp(13, 24),
                          ),
                        )
                      : null,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  icon: const Text(
                    'A+',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${_prefs.fontSize.round()}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            _sliderRow(
              theme,
              'Line spacing',
              (_prefs.lineHeight - 1.4) / 0.8,
              (v) => setState(
                () => _prefs = _prefs.copyWith(lineHeight: 1.4 + v * 0.8),
              ),
              trailing: Text(
                _prefs.lineHeight.toStringAsFixed(1),
                style: theme.textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    'Reading width',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: _Segmented(
                    labels: const ['Tight', 'Regular', 'Wide'],
                    index: _widthIndex,
                    onChanged: (i) => setState(() {
                      const widths = [14.0, 22.0, 30.0];
                      _prefs = _prefs.copyWith(margin: widths[i]);
                    }),
                    accent: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Serif typeface', style: theme.textTheme.bodyMedium),
                Switch(
                  value: _prefs.serif,
                  onChanged: (v) =>
                      setState(() => _prefs = _prefs.copyWith(serif: v)),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Justified text', style: theme.textTheme.bodyMedium),
                Switch(
                  value: _prefs.justify,
                  onChanged: (v) =>
                      setState(() => _prefs = _prefs.copyWith(justify: v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(
    ThemeData theme,
    String label,
    double value,
    ValueChanged<double> onChanged, {
    required Widget trailing,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(value: value, onChanged: onChanged),
        ),
        SizedBox(width: 40, child: trailing),
      ],
    );
  }
}

class _ReaderLoading extends StatelessWidget {
  const _ReaderLoading({required this.theme});
  final _ReaderPalette theme;
  @override
  Widget build(BuildContext context) {
    Widget skeletonLine(double widthFrac) {
      final color = theme.fg.withValues(alpha: 0.08);
      return Shimmer(
        color: color,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFrac,
          child: Container(height: 14, color: color, width: double.infinity),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Fetching the story…',
                style: TextStyle(
                  color: theme.fg.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 28),
            skeletonLine(0.9),
            const SizedBox(height: 14),
            skeletonLine(0.95),
            const SizedBox(height: 14),
            skeletonLine(0.8),
            const SizedBox(height: 30),
            for (var i = 0; i < 9; i++) ...[
              skeletonLine(i % 3 == 0 ? 0.97 : 0.62),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({
    required this.theme,
    required this.onRetry,
    this.empty = false,
  });
  final _ReaderPalette theme;
  final VoidCallback onRetry;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final fg = theme.fg;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                empty
                    ? PhosphorIconsRegular.bookBookmark
                    : PhosphorIconsRegular.warningCircle,
                size: 44,
                color: fg.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 14),
              Text(
                empty
                    ? 'No free text found for this title yet.'
                    : 'The story could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                empty
                    ? 'Try offline fallback, or pick another book.'
                    : 'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.6),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: fg,
                  side: BorderSide(color: fg.withValues(alpha: 0.35)),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill-style segmented control (reading width).
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.index,
    required this.onChanged,
    required this.accent,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  labels[i],
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11.5,
                    color: selected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Editorial chapter index. Tapping a row jumps the reader to that chapter.
class _TocSheet extends StatelessWidget {
  const _TocSheet({
    required this.chapters,
    required this.total,
    required this.accent,
  });
  final List<(String, double)> chapters;
  final double total;
  final Color accent;

  static const _numerals = [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X',
    'XI',
    'XII',
    'XIII',
    'XIV',
    'XV',
    'XVI',
    'XVII',
    'XVIII',
    'XIX',
    'XX',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = fg.withValues(alpha: 0.55);
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.62,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Row(
                children: [
                  Text('❦', style: TextStyle(color: muted, fontSize: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Contents',
                      style: AppTheme.serif(
                        size: 26,
                        weight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(PhosphorIconsRegular.x),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: fg.withValues(alpha: 0.08)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: chapters.length,
                itemBuilder: (context, i) {
                  final (title, offset) = chapters[i];
                  final pct = total <= 0 ? 0 : (offset / total * 100).round();
                  final cleanTitle = title
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim()
                      .replaceFirst(
                        RegExp(
                          r'^(chapter|prologue|preface|introduction|part)\s*\.?\s*(\d+|the\s+\w+)\b',
                          caseSensitive: false,
                        ),
                        '',
                      );
                  return InkWell(
                    onTap: () => Navigator.pop(context, offset),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              i < _numerals.length ? _numerals[i] : '${i + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              cleanTitle.isEmpty ? title.trim() : cleanTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.serif(
                                size: 17,
                                weight: FontWeight.w600,
                                color: fg,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '$pct%',
                              textAlign: TextAlign.end,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
