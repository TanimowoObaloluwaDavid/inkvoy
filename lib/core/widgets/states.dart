import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding:
          padding ??
          const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.kicker,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? kicker;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = fg.withValues(alpha: 0.55);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.all(32),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 22 : 30,
          vertical: compact ? 22 : 30,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            AppShadows.soft(
              theme.colorScheme.surface,
              alpha: 0.05,
              blur: 18,
              dy: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RingBadge(
              icon: icon,
              color: theme.colorScheme.primary,
              muted: muted,
            ).animate().scale(
              begin: const Offset(0.6, 0.6),
              duration: 500.ms,
              curve: Curves.elasticOut,
            ),
            const SizedBox(height: 18),
            if (kicker != null) ...[
              Text(
                kicker!.toUpperCase(),
                style: AppTheme.sans(
                  size: 10.5,
                  weight: FontWeight.w800,
                  letterSpacing: 2,
                  color: muted,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.serif(
                size: 21,
                weight: FontWeight.w700,
                color: fg,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.45,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    final muted = fg.withValues(alpha: 0.55);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RingBadge(
              icon: PhosphorIconsRegular.cloudWarning,
              color: theme.colorScheme.onSurfaceVariant,
              muted: muted,
            ).animate().scale(
              begin: const Offset(0.6, 0.6),
              duration: 500.ms,
              curve: Curves.elasticOut,
            ),
            const SizedBox(height: 18),
            Text(
              'CONNECTION',
              style: AppTheme.sans(
                size: 10.5,
                weight: FontWeight.w800,
                letterSpacing: 2,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not reach the shelves',
              textAlign: TextAlign.center,
              style: AppTheme.serif(
                size: 21,
                weight: FontWeight.w700,
                color: fg,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.45,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Concentric hairline badge for empty & error states — the editorial mark.
class _RingBadge extends StatelessWidget {
  const _RingBadge({
    required this.icon,
    required this.color,
    required this.muted,
  });
  final IconData icon;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                color: color.withValues(alpha: 0.22),
                dot: muted.withValues(alpha: 0.5),
              ),
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Icon(icon, size: 26, color: color),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.dot});
  final Color color;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width * 0.46, paint);
    canvas.drawCircle(
      c,
      size.width * 0.38,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Small ornament on the outer ring.
    canvas.drawCircle(
      c.translate(size.width * 0.44, -size.width * 0.32),
      2.5,
      Paint()..color = dot,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.color != color || old.dot != dot;
}
