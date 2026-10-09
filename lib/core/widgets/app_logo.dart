import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../brand.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Geometric "open book, one page in flight" glyph used on dark surfaces (settings card).
class InkvoyMark extends StatelessWidget {
  const InkvoyMark({super.key, this.size = 40, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final paint = color ?? AppColors.parchment;
    return CustomPaint(size: Size.square(size), painter: _MarkPainter(paint));
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final book = Path()
      ..moveTo(w * 0.50, w * 0.30)
      ..cubicTo(w * 0.36, w * 0.20, w * 0.14, w * 0.32, w * 0.16, w * 0.52)
      ..lineTo(w * 0.16, w * 0.74)
      ..cubicTo(w * 0.28, w * 0.82, w * 0.42, w * 0.80, w * 0.50, w * 0.70)
      ..moveTo(w * 0.50, w * 0.30)
      ..cubicTo(w * 0.64, w * 0.20, w * 0.86, w * 0.32, w * 0.84, w * 0.52)
      ..lineTo(w * 0.84, w * 0.74)
      ..cubicTo(w * 0.72, w * 0.82, w * 0.58, w * 0.80, w * 0.50, w * 0.70);
    canvas.drawPath(book, stroke);
    canvas.drawLine(Offset(w * 0.50, w * 0.70), Offset(w * 0.50, w * 0.86), stroke);
    canvas.drawCircle(
      Offset(w * 0.50, w * 0.15),
      w * 0.075,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}

/// Rendered Inkvoy glyph (used on the in-app splash).
class InkvoyLogo extends StatelessWidget {
  const InkvoyLogo({super.key, this.size = 140});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/splash_logo.png',
      width: size,
      height: size,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// "Inkvoy" letter-by-letter animated wordmark.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.textColor, this.size = 46, this.tagline, this.taglineColor});

  final Color? textColor;
  final double size;
  final String? tagline;
  final Color? taglineColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paint = textColor ?? theme.colorScheme.onSurface;
    final letters = Brand.name.split('');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(letters.length, (i) {
            return Text(
              letters[i],
              style: AppTheme.serif(
                size: size,
                weight: FontWeight.w700,
                color: paint,
                height: 0.9,
              ),
            ).animate(
              delay: Duration(milliseconds: 250 + i * 70),
            ).fadeIn(
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
            ).slideY(
              begin: 0.35,
              end: 0,
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
            );
          }),
        ),
        if (tagline != null) ...[
          const SizedBox(height: 10),
          Text(
            tagline!,
            style: AppTheme.serif(
              size: size * 0.34,
              weight: FontWeight.w500,
              italic: true,
              color: taglineColor ?? theme.colorScheme.onSurfaceVariant,
              height: 1.2,
            ),
          ).animate(
            delay: Duration(milliseconds: 250 + letters.length * 70 + 120),
          ).fadeIn(duration: const Duration(milliseconds: 600)).slideY(begin: 0.3, end: 0),
        ],
      ],
    );
  }
}