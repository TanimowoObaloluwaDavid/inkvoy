import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/tokens.dart';
import 'shimmer.dart';

/// Deterministic neutral (ink-and-paper) palette per book for placeholder covers.
class CoverPalette {
  static const _pairs = [
    [Color(0xFF4A4A4A), Color(0xFF2E2E2E)],
    [Color(0xFF5A5A5A), Color(0xFF383838)],
    [Color(0xFF3D3D3D), Color(0xFF262626)],
    [Color(0xFF525252), Color(0xFF303030)],
    [Color(0xFF3A3A3A), Color(0xFF212121)],
    [Color(0xFF464646), Color(0xFF292929)],
    [Color(0xFF5E5E5E), Color(0xFF3B3B3B)],
    [Color(0xFF424242), Color(0xFF272727)],
  ];

  static List<Color> forBook(Book book) {
    var h = book.key.hashCode ^ book.title.hashCode;
    h = h.abs();
    return _pairs[h % _pairs.length];
  }
}

/// Rounded book "front cover" that tries every real cover candidate before
/// falling back to a neutral initials placeholder.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    required this.width,
    required this.height,
    this.radius = 8,
    this.borderRadiusOverride,
    this.errorBuilder,
    this.imageUrl,
    this.size = 'M',
  });

  final Book book;
  final double width;
  final double height;
  final double radius;
  final BorderRadius? borderRadiusOverride;
  final Widget? errorBuilder;
  final String? imageUrl;
  final String size;

  BorderRadius get _radius =>
      borderRadiusOverride ?? BorderRadius.circular(radius);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urls = imageUrl != null ? [imageUrl!] : book.coverCandidates(size);
    final placeholder = _CoverPlaceholder(
      book: book,
      radius: _radius,
      width: width,
      height: height,
    );
    final artwork = urls.isEmpty
        ? placeholder
        : _NetworkCover(
            urls: urls,
            radius: _radius,
            width: width,
            height: height,
            placeholder: placeholder,
            errorBuilder: errorBuilder,
          );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            artwork,
            Align(
              alignment: Alignment.centerLeft,
              child: IgnorePointer(
                child: Container(
                  width: (width * 0.07).clamp(2.5, 8.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: isDark
                          ? const [Color(0x000D0D0D), Color(0x00000000)]
                          : const [Color(0x33000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: (isDark ? AppColors.parchment : AppColors.ink)
                      .withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkCover extends StatefulWidget {
  const _NetworkCover({
    required this.urls,
    required this.radius,
    required this.width,
    required this.height,
    required this.placeholder,
    this.errorBuilder,
  });

  final List<String> urls;
  final BorderRadius radius;
  final double width;
  final double height;
  final Widget placeholder;
  final Widget? errorBuilder;

  @override
  State<_NetworkCover> createState() => _NetworkCoverState();
}

class _NetworkCoverState extends State<_NetworkCover> {
  int _idx = 0;

  bool get _hasNext => _idx + 1 < widget.urls.length;

  @override
  Widget build(BuildContext context) {
    if (_idx >= widget.urls.length) {
      return widget.errorBuilder ?? widget.placeholder;
    }
    return ClipRRect(
      borderRadius: widget.radius,
      child: CachedNetworkImage(
        key: ValueKey('${widget.urls[_idx]}|${widget.width}x${widget.height}'),
        imageUrl: widget.urls[_idx],
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        memCacheWidth: (widget.width * 3).round().clamp(40, 1200),
        memCacheHeight: (widget.height * 3).round().clamp(40, 1200),
        maxWidthDiskCache: (widget.width * 2).round().clamp(40, 800),
        maxHeightDiskCache: (widget.height * 2).round().clamp(40, 1200),
        fadeInDuration: const Duration(milliseconds: 240),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => Shimmer(child: widget.placeholder),
        errorWidget: (_, __, ___) {
          if (_hasNext) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _idx++);
            });
          }
          return widget.errorBuilder ?? widget.placeholder;
        },
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({
    required this.book,
    required this.radius,
    required this.width,
    required this.height,
  });

  final Book book;
  final BorderRadius radius;
  final double width;
  final double height;

  String get _initials {
    final words = book.title
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoverPalette.forBook(book);
    final muted = Colors.white.withValues(alpha: 0.72);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CoverDecoPainter(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _initials,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverDecoPainter extends CustomPainter {
  _CoverDecoPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const inset = 5.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      paint,
    );
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: 0.22), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      sheen,
    );
  }

  @override
  bool shouldRepaint(covariant _CoverDecoPainter oldDelegate) =>
      oldDelegate.color != color;
}
