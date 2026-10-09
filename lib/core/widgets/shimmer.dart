import 'package:flutter/material.dart';

/// Lightweight infinite shimmer overlay for loading skeletons.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = widget.color ?? scheme.surfaceContainerHigh;
    final sheen = Color.lerp(scheme.surface, Colors.white, 0.55)!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = (t * 1.6 - 0.8);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final slide = Matrix4.translationValues(rect.width * dx, 0, 0);
            return LinearGradient(
              colors: [base.withValues(alpha: 0), sheen, base.withValues(alpha: 0)],
              stops: const [0.30, 0.5, 0.70],
              transform: _Slide(slide),
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _Slide extends GradientTransform {
  const _Slide(this.m);
  final Matrix4 m;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => m;
}

/// A rounded skeleton block with shimmer.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 14, this.color});
  final double? width;
  final double? height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      color: color,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Horizontal skeleton cover shelf for lazy home & search layouts.
class SkeletonShelf extends StatelessWidget {
  const SkeletonShelf({super.key, this.coverWidth = 116, this.coverHeight = 174, this.count = 4});
  final double coverWidth;
  final double coverHeight;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: coverHeight + 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SkeletonBox(width: coverWidth, height: coverHeight),
            const SizedBox(height: 8),
            SkeletonBox(width: coverWidth * 0.85, height: 12, radius: 6),
            const SizedBox(height: 6),
            SkeletonBox(width: coverWidth * 0.55, height: 10, radius: 5),
          ],
        ),
      ),
    );
  }
}