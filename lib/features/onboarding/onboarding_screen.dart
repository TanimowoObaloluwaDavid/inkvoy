import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/models/book.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_logo.dart';
import 'genre_picker.dart';

/// Covers used for the onboarding artwork (Open Library by ISBN).
const _coverSet = [
  (isbn: '9780441013593', title: 'Dune'),
  (isbn: '9780316556347', title: 'Circe'),
  (isbn: '9780385534635', title: 'The Night Circus'),
  (isbn: '9781984827627', title: 'Where the Crawdads Sing'),
  (isbn: '9780141439518', title: 'Pride and Prejudice'),
  (isbn: '9780525559474', title: 'The Midnight Library'),
];

/// Curated real covers for the discovery page.
const _discoverSet = [
  (isbn: '9780451524935', title: '1984'),
  (isbn: '9780743273565', title: 'The Great Gatsby'),
  (isbn: '9780061120084', title: 'To Kill a Mockingbird'),
  (isbn: '9780062060624', title: 'The Song of Achilles'),
];

/// Public-domain "reader" plates (PD-old, Wikimedia Commons), used as the
/// duotone still backdrop of steps without video.
const _plateAssets = [
  'assets/onboarding/art_shelf.jpg',
  'assets/onboarding/art_taste.jpg',
  'assets/onboarding/art_rhythm.jpg',
];

/// Looping reading videos (Pixabay free license) for cinematic hero moments.
const _videoAssets = [
  'assets/onboarding/pages_loop.mp4',
  null, // step 2 is a painting
  'assets/onboarding/candle_loop.mp4',
];

/// unDraw illustrations (CC BY 4.0), tinted to the ink system.
const _illustBook = 'assets/onboarding/illust_book.svg';
const _illustReading = 'assets/onboarding/illust_reading.svg';

const _featureEyebrows = ['YOUR SHELF', 'YOUR TASTE', 'YOUR RHYTHM'];
const _featureTitlesBase = [
  'Every book, one ',
  'Find the ones that find ',
  'Build a quiet little ',
];
const _featureTitlesAccent = ['beautiful shelf', 'you', 'ritual'];
const _featureBodies = [
  'Your stories — sorted, saved, always in reach. A library that feels like home.',
  'Tell us what you love and we’ll shape every shelf around it.',
  'Gentle goals and streaks that add up without pressure — a few calm minutes a day.',
];

/// Onboarding: 3 art-forward feature pages, genre personalization, then a
/// small celebration that hands off to Home.
///
/// Every feature page is an editorial spread: the media lives in a full-bleed
/// hero on top, the copy lives in a solid-paper deck below — two dedicated
/// zones, so art and type can never overlap.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  /// Index of the genre step, which lives outside the 3-page feature PageView.
  static const int _genreStep = 3;

  /// Celebration step shown once genres + onboarding flag are persisted.
  static const int _doneStep = 4;

  final _controller = PageController();
  int _index = 0;
  final Set<String> _genres = {};
  int _dailyGoal = 10;

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final isbn in [
      ..._coverSet.map((c) => c.isbn),
      ..._discoverSet.map((c) => c.isbn),
    ]) {
      precacheImage(
        CachedNetworkImageProvider(
          'https://covers.openlibrary.org/b/isbn/$isbn-M.jpg',
        ),
        context,
      );
    }
    for (final asset in _plateAssets) {
      precacheImage(AssetImage(asset), context);
    }
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_index < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    } else if (_index == 2) {
      // Last feature page — move out of the PageView into the genre step.
      setState(() => _index = _genreStep);
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    if (_index == _genreStep) {
      setState(() => _index = 2);
    } else if (_index < _genreStep) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _finish() {
    HapticFeedback.heavyImpact();
    final repo = ref.read(settingsProvider.notifier);
    if (_genres.isEmpty) _genres.add('fiction');
    repo.setGenres(_genres.toList());
    repo.setDailyGoal(_dailyGoal);
    repo.setOnboardingDone();
    setState(() => _index = _doneStep);
  }

  void _skip() => _finish();

  void _toggleGenre(String g) {
    setState(() {
      if (_genres.contains(g)) {
        _genres.remove(g);
      } else if (_genres.length < 3) {
        _genres.add(g);
      }
    });
  }

  void _startReading() {
    HapticFeedback.mediumImpact();
    context.go('/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isGenre = _index == _genreStep;
    final isDone = _index == _doneStep;

    return PopScope(
      canPop: _index == 0 || isDone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isDone) _back();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.surfaceContainerLowest,
                      theme.colorScheme.surface,
                    ],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _HairlinePainter(
                        color: onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                    CustomPaint(
                      painter: _GrainPainter(
                        color: onSurface.withValues(alpha: 0.028),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  if (!isDone)
                    _TopBar(
                      index: _index,
                      onSkip: _skip,
                      onBack: _back,
                      onSurface: onSurface,
                    )
                  else
                    const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.05),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: isDone
                          ? _Welcome(
                              key: const ValueKey('done'),
                              genres: _genres.toList(),
                              onStart: _startReading,
                            )
                          : isGenre
                          ? Column(
                              key: const ValueKey('genres'),
                              children: [
                                Expanded(
                                  child: GenrePicker(
                                    selected: _genres.toList(),
                                    onToggle: _toggleGenre,
                                  ),
                                ),
                                _GenreFooter(
                                  count: _genres.length,
                                  dailyGoal: _dailyGoal,
                                  onGoal: (m) => setState(() => _dailyGoal = m),
                                  onStart: _finish,
                                  onFallback: _finish,
                                ),
                              ],
                            )
                          : PageView.builder(
                              key: const ValueKey('features'),
                              controller: _controller,
                              onPageChanged: (i) => setState(() => _index = i),
                              itemCount: 3,
                              itemBuilder: (context, i) => _FeaturePage(
                                i: i,
                                controller: _controller,
                                onNext: _next,
                              ),
                            ),
                    ),
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

/// Subtle concentric hairlines for a designed placeholder ground.
class _HairlinePainter extends CustomPainter {
  const _HairlinePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final c = Offset(size.width / 2, size.height * 0.42);
    for (final r in [160.0, 230.0, 300.0]) {
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HairlinePainter old) => old.color != color;
}

/// Fine paper-grain speckle so flat gradient pages feel like real paper.
class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rnd = math.Random(17);
    const step = 9.0;
    for (double y = 3; y < size.height; y += step) {
      for (double x = 3; x < size.width; x += step) {
        if (rnd.nextDouble() < 0.14) {
          canvas.drawCircle(
            Offset(x + rnd.nextDouble() * 4, y + rnd.nextDouble() * 4),
            0.7,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.color != color;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.onSkip,
    required this.onBack,
    required this.onSurface,
  });
  final int index;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          if (index > 0)
            IconButton(
              onPressed: onBack,
              icon: const Icon(PhosphorIconsRegular.caretLeft),
              color: onSurface,
            )
          else
            Row(
              children: [
                InkvoyMark(size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'inkvoy',
                  style: AppTheme.serif(
                    size: 20,
                    weight: FontWeight.w700,
                    italic: true,
                    color: onSurface,
                  ),
                ),
              ],
            ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: onSurface.withValues(alpha: 0.6),
              textStyle: AppTheme.sans(
                size: 12.5,
                weight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('SKIP'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------- feature page (spread) ----

/// A single editorial spread. Media (video or painting) in the top hero, copy
/// in a solid-paper deck that scrolls on overflow — never overlapping.
class _FeaturePage extends StatelessWidget {
  const _FeaturePage({
    required this.i,
    required this.controller,
    required this.onNext,
  });
  final int i;
  final PageController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final page = controller.hasClients
            ? (controller.page ?? i.toDouble())
            : i.toDouble();
        final delta = (page - i).clamp(-1.0, 1.0);
        final dx = delta * 56;
        return Column(
          children: [
            Expanded(
              flex: 11,
              child: ClipRect(
                child: _HeroMedia(
                  index: i,
                  plate: _plateAssets[i],
                  video: _videoAssets[i],
                  parallax: dx,
                ),
              ),
            ),
            Flexible(
              flex: 8,
              child: _Deck(i: i, onNext: onNext, parallax: dx),
            ),
          ],
        );
      },
    );
  }
}

/// Full-bleed media hero: looping video or duotone plate with slow Ken Burns.
class _HeroMedia extends StatefulWidget {
  const _HeroMedia({
    required this.index,
    required this.plate,
    required this.video,
    required this.parallax,
  });
  final int index;
  final String plate;
  final String? video;
  final double parallax;

  @override
  State<_HeroMedia> createState() => _HeroMediaState();
}

class _HeroMediaState extends State<_HeroMedia> {
  VideoPlayerController? _player;
  bool _ready = false;
  bool _reduced = false;

  bool _inTest() => Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    if (widget.video != null && !_inTest()) {
      final player = VideoPlayerController.asset(widget.video!)
        ..setLooping(true)
        ..setVolume(0);
      _player = player;
      player.initialize().then((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) return;
        setState(() => _ready = true);
        player.play();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced && _player != null && _ready) _player!.pause();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hero = _player != null && _ready
        ? _videoFill(_player!)
        : widget.video != null
        ? const _VideoPoster()
        : _PlateHero(asset: widget.plate, parallax: widget.parallax);
    return _heroScrim(hero);
  }

  Widget _videoFill(VideoPlayerController player) {
    final size = player.value.size;
    final portrait = size.width > 0 && size.height > 0
        ? size.height > size.width
        : false;
    if (size.width == 0 || size.height == 0) return const _VideoPoster();
    return Transform.translate(
      offset: Offset(widget.parallax * 0.5, 0),
      child: ColorFiltered(
        colorFilter: _duotone,
        child: Opacity(
          opacity: 0.82,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: portrait ? 720 : 1280,
              height: portrait ? 1280 : 720,
              child: VideoPlayer(player),
            ),
          ),
        ),
      ),
    );
  }

  /// Top paper-leak and bottom melt so art and deck seam cleanly together.
  Widget _heroScrim(Widget media) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        media,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 96,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0.72),
                  scheme.surface.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 150,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0),
                  scheme.surface.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
        ),
        CustomPaint(
          painter: _GrainPainter(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.03),
          ),
        ),
      ],
    );
  }
}

/// Editorially designed stand-in when video is unavailable (tests, reduced
/// motion, tiny screens): a duotone ink block with a reading glyph.
class _VideoPoster extends StatelessWidget {
  const _VideoPoster();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerLowest,
            scheme.surfaceContainer,
          ],
        ),
      ),
      child: Center(
        child: SvgPicture.asset(
          _illustBook,
          width: 92,
          height: 92,
          colorFilter: ColorFilter.mode(
            fg.withValues(alpha: 0.16),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// Public-domain painting pushed through a grayscale curve with a slow
/// Ken Burns drift (skipped under reduced motion).
class _PlateHero extends StatefulWidget {
  const _PlateHero({required this.asset, required this.parallax});
  final String asset;
  final double parallax;
  @override
  State<_PlateHero> createState() => _PlateHeroState();
}

class _PlateHeroState extends State<_PlateHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burns = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_burns.isAnimating) {
      _burns.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _burns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _burns,
      builder: (context, child) {
        final t = _burns.isAnimating ? _burns.value : 0.5;
        final scale = 1.08 + 0.07 * t;
        final shift = Offset(widget.parallax * 0.5, 8 - 16 * t);
        return Transform.translate(
          offset: shift,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: 0.55,
              child: ColorFiltered(
                colorFilter: _duotone,
                child: Image.asset(
                  widget.asset,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Luminance-only duotone curve shared by every piece of media.
const _duotone = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// Solid-paper content panel. Scrolls in case of overflow, so nothing can
/// clip or collide — the payoff (covers / streak tile) peeks over the seam.
class _Deck extends StatelessWidget {
  const _Deck({required this.i, required this.onNext, required this.parallax});
  final int i;
  final VoidCallback onNext;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: fg.withValues(alpha: 0.08))),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, -20),
              child: _SeamPayoff(i: i, parallax: parallax),
            ),
            const SizedBox(height: 4),
            _Eyebrow(label: '0${i + 1}/03', caption: _featureEyebrows[i]),
            const SizedBox(height: 16),
            Text.rich(
              _headline(
                _featureTitlesBase[i],
                _featureTitlesAccent[i],
                fg,
                theme.colorScheme.primary,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 12),
            Text(
              _featureBodies[i],
              textAlign: TextAlign.left,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: fg.withValues(alpha: 0.62),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: fg.withValues(alpha: 0.1)),
                ),
              ),
              child: SizedBox(height: 0),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _StepDots(count: 3, active: i),
                const SizedBox(width: 16),
                _NextButton(
                  title: i == 2 ? 'Shape your shelves' : 'Continue',
                  onTap: onNext,
                  emphasized: true,
                ),
              ],
            ),
            SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  /// Serif headline with a single italic accent word — the editorial voice.
  static TextSpan _headline(
    String base,
    String accent,
    Color fg,
    Color accentColor,
  ) {
    return TextSpan(
      style: AppTheme.serif(
        size: 34,
        weight: FontWeight.w700,
        color: fg,
        height: 1.04,
        letterSpacing: -0.4,
      ),
      children: [
        TextSpan(text: base),
        TextSpan(
          text: accent,
          style: AppTheme.serif(
            size: 34,
            weight: FontWeight.w600,
            italic: true,
            color: accentColor,
            height: 1.04,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

/// The "instant payoff": floating covers on the shelf/taste steps, and a
/// daily-rhythm stamp on the ritual step.
class _SeamPayoff extends StatelessWidget {
  const _SeamPayoff({required this.i, required this.parallax});
  final int i;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (i == 0) {
      return Transform.translate(
        offset: Offset(parallax * 0.4, 0),
        child: _CoverFan(
          covers: _coverSet.take(4).toList(),
          width: 56,
          height: 84,
        ),
      );
    }
    if (i == 1) {
      return Transform.translate(
        offset: Offset(parallax * 0.4, 0),
        child: _CoverFan(covers: _discoverSet.take(4).toList()),
      );
    }
    final fg = theme.colorScheme.onSurface;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            AppShadows.soft(theme.colorScheme.surface, alpha: 0.08, blur: 14),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.flame,
              size: 17,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 7),
            Text(
              '10',
              style: AppTheme.serif(
                size: 21,
                weight: FontWeight.w800,
                height: 1,
                color: fg,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'MIN / DAY',
              style: AppTheme.sans(
                size: 9.5,
                weight: FontWeight.w800,
                letterSpacing: 1.3,
                color: fg.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shallow overlapping fan of real covers, tilted like a spread shelf.
class _CoverFan extends StatelessWidget {
  const _CoverFan({required this.covers, this.width = 52, this.height = 78});
  final List<({String isbn, String title})> covers;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final n = covers.length;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var j = 0; j < n; j++)
            Transform.translate(
              offset: Offset((j - (n - 1) / 2) * (width * 0.72), 0),
              child: Transform.rotate(
                angle: (j - (n - 1) / 2) * 0.10,
                child: _RealCover(
                  isbn: covers[j].isbn,
                  title: covers[j].title,
                  width: width,
                  height: height,
                  angle: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label, required this.caption});
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          '$label  ·  $caption',
          style: AppTheme.sans(
            size: 11,
            weight: FontWeight.w800,
            letterSpacing: 1.8,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Hairline pill segments that fill as you advance.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    return Expanded(
      child: Row(
        children: List.generate(count, (i) {
          final filled = i <= active;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              height: 4,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: filled ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: filled
                    ? null
                    : Border.all(color: fg.withValues(alpha: 0.22)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.title,
    required this.onTap,
    this.emphasized = false,
  });
  final String title;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child:
          FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  backgroundColor: emphasized
                      ? theme.colorScheme.primary
                      : null,
                  textStyle: AppTheme.sans(size: 15, weight: FontWeight.w700),
                ),
                onPressed: onTap,
                iconAlignment: IconAlignment.end,
                icon: const Icon(PhosphorIconsRegular.arrowRight, size: 19),
                label: Text(title),
              )
              .animate(
                onPlay: (c) => c.repeat(
                  reverse: true,
                  period: const Duration(milliseconds: 900),
                ),
              )
              .moveX(begin: 0, end: 2.5),
    );
  }
}

class _GenreFooter extends StatelessWidget {
  const _GenreFooter({
    required this.count,
    required this.dailyGoal,
    required this.onGoal,
    required this.onStart,
    required this.onFallback,
  });
  final int count;
  final int dailyGoal;
  final ValueChanged<int> onGoal;
  final VoidCallback onStart;
  final VoidCallback onFallback;

  static const _tiers = [
    (5, 'Light'),
    (10, 'Balanced'),
    (15, 'Consistent'),
    (20, 'Deep'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: fg.withValues(alpha: 0.08)),
              ),
            ),
            child: SizedBox(height: 0),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Up to 3 shelves that call to you',
                style: AppTheme.sans(
                  size: 13,
                  weight: FontWeight.w600,
                  color: fg.withValues(alpha: 0.62),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '$count/3',
                  key: ValueKey(count),
                  style: AppTheme.sans(
                    size: 13,
                    weight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'DAILY RHYTHM',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_tiers.length, (i) {
              final (minutes, label) = _tiers[i];
              final selected = minutes == dailyGoal;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == _tiers.length - 1 ? 0 : 8,
                  ),
                  child: Material(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => onGoal(minutes),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: selected
                              ? null
                              : Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$minutes',
                              style: AppTheme.serif(
                                size: 22,
                                weight: FontWeight.w700,
                                height: 1,
                                color: selected
                                    ? theme.colorScheme.onPrimary
                                    : fg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: AppTheme.sans(
                                size: 10,
                                weight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: selected
                                    ? theme.colorScheme.onPrimary.withValues(
                                        alpha: 0.85,
                                      )
                                    : fg.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'minutes a day — your reading room, your pace',
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                textStyle: AppTheme.sans(size: 16, weight: FontWeight.w700),
              ),
              onPressed: count > 0 ? onStart : null,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Commit to reading'),
                  SizedBox(width: 8),
                  Icon(PhosphorIconsRegular.bookOpenText, size: 20),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: count == 0
                ? SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onFallback,
                      child: const Text('Not sure? Start with fiction'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: MediaQuery.viewPaddingOf(context).bottom + 12),
        ],
      ),
    );
  }
}

/// Real cover, rendered over Open Library. Falls back to a designed tint plate.
class _RealCover extends StatelessWidget {
  const _RealCover({
    required this.isbn,
    required this.title,
    this.width = 76,
    this.height = 112,
    this.angle = 0,
  });
  final String isbn;
  final String title;
  final double width, height, angle;

  static const double _coverRadius = 10;

  String get _initials {
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.length < 2) {
      return title.isEmpty
          ? 'pp'
          : title.substring(0, math.min(2, title.length));
    }
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  Widget _plate(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFF3B3B3B), Color(0xFF222222)],
        ),
        borderRadius: BorderRadius.circular(_coverRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _initials,
            style: AppTheme.serif(
              size: width * 0.38,
              weight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: width * 0.11,
              height: 1.15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(_coverRadius),
      child: CachedNetworkImage(
        imageUrl: 'https://covers.openlibrary.org/b/isbn/$isbn-M.jpg',
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: (width * 3).round().clamp(40, 700),
        memCacheHeight: (height * 3).round().clamp(40, 700),
        fadeInDuration: const Duration(milliseconds: 240),
        placeholder: (_, __) => _plate(context),
        errorWidget: (_, __, ___) => _plate(context),
      ),
    );
    return Transform.rotate(
      angle: angle,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_coverRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: cover,
      ),
    );
  }
}

// ------------------------------------------------------------ celebration ----

/// "You're all set" — a confetti peak moment before handing off to Home.
class _Welcome extends StatefulWidget {
  const _Welcome({super.key, required this.genres, required this.onStart});
  final List<String> genres;
  final VoidCallback onStart;
  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(seconds: 4),
  )..play();

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _WelcomePlate()),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SvgPicture.asset(
                      _illustReading,
                      width: 148,
                      height: 148,
                      colorFilter: ColorFilter.mode(
                        theme.colorScheme.primary.withValues(alpha: 0.14),
                        BlendMode.srcIn,
                      ),
                    ),
                    const InkvoyMark(size: 44),
                  ],
                ),
                CustomPaint(
                  painter: _HairlinePainter(color: fg.withValues(alpha: 0.06)),
                ),
                ConfettiWidget(
                  confettiController: _confetti,
                  blastDirection: -math.pi / 2,
                  emissionFrequency: 0.06,
                  numberOfParticles: 9,
                  gravity: 0.35,
                  colors: const [
                    AppColors.ink,
                    AppColors.inkMuted,
                    Color(0xFF9A9A9A),
                  ],
                  maxBlastForce: 18,
                  minBlastForce: 6,
                ),
              ],
            ),
            Text(
                  'You’re all set.',
                  textAlign: TextAlign.center,
                  style: AppTheme.serif(
                    size: 40,
                    weight: FontWeight.w700,
                    color: fg,
                    height: 1.05,
                  ),
                )
                .animate(delay: 120.ms)
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.25, end: 0),
            const SizedBox(height: 8),
            Text(
              'Your shelves are ready — go find the book that feels like a homecoming.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: fg.withValues(alpha: 0.62),
                height: 1.5,
              ),
            ).animate(delay: 220.ms).fadeIn(duration: 600.ms),
            const SizedBox(height: 24),
            if (widget.genres.isNotEmpty) ...[
              Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.genres
                        .map(
                          (g) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              boxShadow: [
                                AppShadows.soft(
                                  theme.colorScheme.surface,
                                  alpha: 0.06,
                                  blur: 12,
                                  dy: 3,
                                ),
                              ],
                            ),
                            child: Text(
                              Genres.display(g),
                              style: AppTheme.sans(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: fg.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  )
                  .animate(delay: 320.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.2, end: 0),
              const SizedBox(height: 28),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  textStyle: AppTheme.sans(size: 16, weight: FontWeight.w700),
                ),
                onPressed: widget.onStart,
                iconAlignment: IconAlignment.end,
                icon: const Icon(PhosphorIconsRegular.bookOpenText, size: 20),
                label: const Text('Start reading'),
              ),
            ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
          ],
        ),
      ),
    );
  }
}

/// Faded Cassatt plate + ink-book illustration behind the completion mark.
class _WelcomePlate extends StatelessWidget {
  const _WelcomePlate();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.38,
            child: ColorFiltered(
              colorFilter: _duotone,
              child: Image.asset(
                'assets/onboarding/art_welcome.jpg',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0.55),
                  scheme.surface.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
