import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ambient slowly-shifting gradient canvas behind onboarding & splash.
///
/// Pass several palettes; the stage continuously interpolates between them
/// and is influenced by [activeIndex] so each onboarding step has its own mood.
class GradientStage extends StatefulWidget {
  const GradientStage({super.key, required this.palettes, this.activeIndex = 0, required this.child, this.glow = true});

  final List<List<Color>> palettes;
  final int activeIndex;
  final Widget child;
  final bool glow;

  @override
  State<GradientStage> createState() => _GradientStageState();
}

class _GradientStageState extends State<GradientStage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 14))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.palettes.length;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = (_controller.value * n + widget.activeIndex) % n;
        final i = t.floor();
        final f = t - i;
        final a = widget.palettes[i % n];
        final b = widget.palettes[(i + 1) % n];
        final grad = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(a[0], b[0], f)!,
            Color.lerp(a[1 % a.length], b[1 % b.length], f)!,
            Color.lerp(a[2 % a.length], b[2 % b.length], f)!,
          ],
        );
        return DecoratedBox(
          decoration: BoxDecoration(gradient: grad),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.glow)
                CustomPaint(
                  painter: _GlowPainter(color: Colors.white.withValues(alpha: 0.10), center: Offset(0.6, 0.25)),
                ),
              if (widget.glow)
                CustomPaint(
                  painter: _GlowPainter(color: Colors.black.withValues(alpha: 0.18), center: Offset(0.15, 0.85)),
                ),
child ?? const SizedBox.shrink(),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.color, required this.center});
  final Color color;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * center.dx, size.height * center.dy), radius: math.max(size.width, size.height) * 0.7));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => false;
}