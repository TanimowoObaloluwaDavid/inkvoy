import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/gradient_stage.dart';
import '../../core/widgets/shimmer.dart';

/// Branded intro with an animated reveal. Routes to onboarding (first run)
/// or the home shell. Tapping skips the wait.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _schedule();
  }

  void _schedule() {
    Future.delayed(const Duration(milliseconds: 3200), _go);
  }

  void _go() {
    if (!mounted) return;
    final done = ref.read(settingsProvider).onboardingDone;
    context.go(done ? '/home' : '/onboarding');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: GradientStage(
          palettes: const [
            [
              AppColors.espresso,
              Color(0xFF202020),
              AppColors.espressoSurfaceContainer,
            ],
            [Color(0xFF141414), AppColors.espressoSurface, Color(0xFF2C2C2C)],
          ],
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Logo reveal with shimmer sweep.
                ScaleTransition(
                  scale: Tween(begin: 0.78, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: Shimmer(
                    color: Colors.white.withValues(alpha: 0.06),
                    child: const InkvoyLogo(size: 158),
                  ),
                ),
                const SizedBox(height: 30),
                const Wordmark(
                  size: 64,
                  textColor: AppColors.parchment,
                  tagline: 'Every page is a voyage.',
                  taglineColor: AppColors.parchmentMuted,
                ),
                const Spacer(flex: 2),
                const _LoadingDots(
                  color: AppColors.parchment,
                  light: AppColors.parchment,
                ),
                const SizedBox(height: 20),
                Text(
                  'v1.0 · crafted for readers',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.parchmentMuted,
                  ),
                ).animate(delay: const Duration(milliseconds: 1400)).fadeIn(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.color, required this.light});
  final Color color;
  final Color light;
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value + i / 3) % 1.0;
            final scale =
                0.55 + 0.45 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
              transform: Matrix4.identity()..scaleByDouble(scale, scale, 1, 1),
            );
          }),
        );
      },
    );
  }
}
