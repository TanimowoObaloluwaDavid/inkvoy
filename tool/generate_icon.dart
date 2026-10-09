// Inkvoy brand asset generator.
// Pure Dart + package:image. Renders every required icon/splash PNG.
//
//   dart run tool/generate_icon.dart
//
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

class C {
  final double r, g, b, a;
  const C(this.r, this.g, this.b, [this.a = 1]);
  C withA(double v) => C(r, g, b, v);
}

// ---------------------------------------------------------------- geometry --
class Geo {
  final double xTL, xTR, gap, yTop, yBot, ySpine;
  final double starX, starY, starR, sparkR, sparkX, sparkY;
  const Geo({
    required this.xTL,
    required this.xTR,
    required this.gap,
    required this.yTop,
    required this.yBot,
    required this.ySpine,
    required this.starX,
    required this.starY,
    required this.starR,
    this.sparkR = 0.0,
    this.sparkX = 0.32,
    this.sparkY = 0.24,
  });
}

double _clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// y of a quadratic bezier at given x (single-valued in x).
double _bezY(double x0, double y0, double xc, double yc, double x1, double y1, double px) {
  final a = x0 - 2 * xc + x1;
  final b = 2 * (xc - x0);
  final c = x0 - px;
  double t;
  if (a.abs() < 1e-9) {
    if (b.abs() < 1e-9) return -1;
    t = -c / b;
  } else {
    final disc = b * b - 4 * a * c;
    if (disc < 0) return -1;
    final sq = math.sqrt(disc);
    t = (-b + sq) / (2 * a);
    if (t < 0 || t > 1) t = (-b - sq) / (2 * a);
  }
  t = _clamp(t, 0, 1);
  final u = 1 - t;
  return u * u * y0 + 2 * u * t * yc + t * t * y1;
}

bool _insidePage(double px, double py, Geo g, int side) {
  // side: -1 left, +1 right
  final cx = 0.5;
  final innerX = cx + side * g.gap;
  final outerX = side < 0 ? g.xTL : g.xTR;
  if (side < 0) {
    if (px > innerX || px < outerX) return false;
  } else {
    if (px < innerX || px > outerX) return false;
  }
  final top =
      _bezY(outerX, g.yTop, (outerX + innerX) / 2, g.yTop + (g.ySpine - g.yTop) * 0.55, innerX, g.ySpine, px);
  final bot = _bezY(outerX, g.yBot, (outerX + innerX) / 2, g.yBot - (g.yBot - g.ySpine) * 0.25, innerX, g.yBot, px);
  return py >= top && py <= bot;
}

bool _insideBook(double px, double py, Geo g) {
  if (py < g.yTop - 0.02 || py > g.yBot + 0.02) return false;
  return _insidePage(px, py, g, -1) || _insidePage(px, py, g, 1);
}

/// Superquadric 4-point sparkle.
bool _insideStar(double px, double py, double cx, double cy, double r) {
  final dx = (px - cx).abs();
  final dy = (py - cy).abs();
  const n = 0.7;
  final v = math.pow(dx, n).toDouble() + math.pow(dy, n).toDouble();
  return v <= math.pow(r, n).toDouble();
}

bool _insideRoundedRect(double px, double py, double inset, double radius) {
  const corners = 4;
  double b;
  double h;
  if (px < inset || px > 1 - inset || py < inset || py > 1 - inset) return false;
  // inscribed rounded rect via per-corner test
  b = 1 - 2 * inset;
  h = b;
  double dx = (px - 0.5).abs() - (b / 2 - radius);
  double dy = (py - 0.5).abs() - (h / 2 - radius);
  dx = dx > 0 ? dx : 0;
  dy = dy > 0 ? dy : 0;
  if (dx == 0 && dy == 0) return true;
  if (dx * dx + dy * dy <= radius * radius) return true;
  // corner quadrants fallback (ignore 'corners' lint shadow)
  return corners == 4 && dx * dx + dy * dy <= radius * radius;
}

/// A small page flying off the top-right of the book.
bool _insideFlyer(double px, double py) {
  const cx = 0.72, cy = 0.26;
  final dx = px - cx, dy = py - cy;
  // rotate by ~0.55 rad so the leaf tilts up-right
  final lx = dx * math.cos(0.55) - dy * math.sin(0.55);
  final ly = dx * math.sin(0.55) + dy * math.cos(0.55);
  const rx = 0.105, ry = 0.075;
  const n = 2.6;
  final ux = (lx.abs() / rx);
  final uy = (ly.abs() / ry);
  if (ux >= 1 || uy >= 1) return false;
  return math.pow(ux, n).toDouble() + math.pow(uy, n).toDouble() <= 1;
}

// ------------------------------------------------------------------ blend ---
C _over(C dst, C src, double cov) {
  cov = _clamp(cov, 0, 1);
  final sa = src.a * cov;
  final outA = sa + dst.a * (1 - sa);
  if (outA <= 1e-6) return const C(0, 0, 0, 0);
  double Channel(double s, double d) =>
      (s * sa + d * dst.a * (1 - sa)) / outA;
  return C(Channel(src.r, dst.r), Channel(src.g, dst.g), Channel(src.b, dst.b), outA);
}

double _glowWeight(double nx, double ny) {
  final dx = nx - 0.5;
  final dy = ny - 0.47;
  final d2 = dx * dx + dy * dy;
  return math.exp(-d2 / (0.11 * 0.11));
}

C _bgColor(double nx, double ny) {
  // diagonal monochrome gradient (near-black app icon)
  final t = _clamp((nx + ny) / 2, 0, 1);
  const a = C(0x1E / 255.0, 0x1E / 255.0, 0x1E / 255.0);
  const b = C(0x0C / 255.0, 0x0C / 255.0, 0x0C / 255.0);
  C lerp2(C x, C y, double u) => C(
        x.r + (y.r - x.r) * u,
        x.g + (y.g - x.g) * u,
        x.b + (y.b - x.b) * u,
      );
  return lerp2(a, b, t);
}

C _bookColor(double nx, double ny) {
  final t = _clamp((nx + ny) / 2, 0, 1);
  const a = C(0xE8 / 255.0, 0xE8 / 255.0, 0xE8 / 255.0);
  const b = C(0xB0 / 255.0, 0xB0 / 255.0, 0xB0 / 255.0);
  C lerp2(C x, C y, double u) => C(
        x.r + (y.r - x.r) * u,
        x.g + (y.g - x.g) * u,
        x.b + (y.b - x.b) * u,
      );
  return lerp2(a, b, t);
}

// ----------------------------------------------------------------- output --
class Variant {
  final String file;
  final int size;
  final bool background;
  final Geo geo;
  Variant(this.file, this.size, this.background, this.geo);
}

C _sample(double nx, double ny, Variant v) {
  final g = v.geo;
  C c = const C(0, 0, 0, 0);

  if (v.background) {
    final inBg = _insideRoundedRect(nx, ny, 0.0, 0.21);
    if (!inBg) return c;
    c = C(_bgColor(nx, ny).r, _bgColor(nx, ny).g, _bgColor(nx, ny).b, 1);
    // neutral glow behind glyph
    final gw = _glowWeight(nx, ny) * 0.30;
    if (gw > 0.001) {
      c = _over(c, const C(0xE0 / 255.0, 0xE0 / 255.0, 0xE0 / 255.0, 1).withA(gw), 1);
    }
    // soft vignette
    final dx = nx - 0.5, dy = ny - 0.5;
    final d = math.sqrt(dx * dx + dy * dy);
    final vg = _clamp((d - 0.5) / 0.33, 0, 1) * 0.38;
    if (vg > 0.001) {
      c = _over(c, const C(0x00 / 255.0, 0x00 / 255.0, 0x00 / 255.0, 1).withA(vg), 1);
    }
  }

  final cy = (g.yTop + g.yBot) / 2;

  // outline band (darker edge around the glyph for definition)
  double scaleOut(double p, double cc, double s) => cc + (p - cc) / s;
  final outer = _insideBook(scaleOut(nx, 0.5, 1.012), scaleOut(ny, cy, 1.012), g);
  final inner = _insideBook(scaleOut(nx, 0.5, 0.988), scaleOut(ny, cy, 0.988), g);
  if (outer && !inner) {
    c = _over(c, const C(0x00 / 255.0, 0x00 / 255.0, 0x00 / 255.0).withA(0.95), 1);
  }

  if (_insideStar(nx, ny, g.starX, g.starY, g.starR)) {
    c = _over(c, const C(0xF5 / 255.0, 0xF5 / 255.0, 0xF5 / 255.0, 1), 1);
  }
  if (g.sparkR > 0 && _insideStar(nx, ny, g.sparkX, g.sparkY, g.sparkR)) {
    c = _over(c, const C(0xF5 / 255.0, 0xF5 / 255.0, 0xF5 / 255.0).withA(0.85), 1);
  }

  if (_insideBook(nx, ny, g)) {
    c = _over(c, _bookColor(nx, ny), 1);
  }

  // flying page above-right, slightly lighter
  if (_insideFlyer(nx, ny)) {
    c = _over(c, C(0xF2 / 255.0, 0xF2 / 255.0, 0xF2 / 255.0), 1);
  }

  // page lines (only on the interior of the book)
  final cx = 0.5;
  final lines = <double>[g.ySpine + 0.045, g.ySpine + 0.105, g.ySpine + 0.165];
  for (final ly in lines) {
    if ((ny - ly).abs() > 0.004) continue;
    final leftX = g.xTL + 0.035;
    final rightX = g.xTR - 0.035;
    final onLeft = nx >= leftX + 0.02 && nx <= cx - g.gap - 0.016;
    final onRight = nx >= cx + g.gap + 0.016 && nx <= rightX - 0.02;
    if (onLeft && _insidePage(nx, ny, g, -1)) {
      c = _over(c, const C(0x6E / 255.0, 0x6E / 255.0, 0x6E / 255.0).withA(0.55), 1);
    } else if (onRight && _insidePage(nx, ny, g, 1)) {
      c = _over(c, const C(0x6E / 255.0, 0x6E / 255.0, 0x6E / 255.0).withA(0.55), 1);
    }
  }
  return c;
}

void render(Variant v) {
  const S = 3; // supersample
  final W = v.size, H = v.size;
  final out = img.Image(width: W, height: H, numChannels: 4);
  final n = S * S;
  for (int y = 0; y < H; y++) {
    if (y % 128 == 0) stdout.writeln('  ${v.file} $y/$H');
    for (int x = 0; x < W; x++) {
      double r = 0, g = 0, b = 0, a = 0;
      for (int sy = 0; sy < S; sy++) {
        for (int sx = 0; sx < S; sx++) {
          final nx = (x + (sx + 0.5) / S) / W;
          final ny = (y + (sy + 0.5) / S) / H;
          final c = _sample(nx, ny, v);
          r += c.r;
          g += c.g;
          b += c.b;
          a += c.a;
        }
      }
      final aa = (a / n).round().clamp(0, 255);
      if (aa == 0) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        out.setPixelRgba(
          x,
          y,
          (r / n).round().clamp(0, 255),
          (g / n).round().clamp(0, 255),
          (b / n).round().clamp(0, 255),
          aa,
        );
      }
    }
  }
  final f = File(v.file);
  f.createSync(recursive: true);
  f.writeAsBytesSync(img.encodePng(out));
  stdout.writeln('wrote ${v.file}');
}

const _iconGeo = Geo(
  xTL: 0.240, xTR: 0.760, gap: 0.035,
  yTop: 0.380, yBot: 0.810, ySpine: 0.510,
  starX: 0.5, starY: 0.185, starR: 0.075, sparkR: 0.030,
);

const _android12Geo = Geo(
  xTL: 0.355, xTR: 0.645, gap: 0.014,
  yTop: 0.420, yBot: 0.655, ySpine: 0.505,
  starX: 0.5, starY: 0.345, starR: 0.050, sparkR: 0.022, sparkX: 0.42, sparkY: 0.415,
);

void main() {
  Directory('assets/images').createSync(recursive: true);
  Directory('build/assets').createSync(recursive: true);
  final variants = <Variant>[
    // Full app icon (gradient rounded square).
    Variant('assets/images/icon_inkvoy.png', 1024, true, _iconGeo),
    // Adaptive foreground (transparent, glyph inside safe zone).
    Variant('assets/images/icon_inkvoy_fg.png', 1024, false, _iconGeo),
    // Native splash + in-app splash logo (transparent).
    Variant('assets/images/splash_logo.png', 512, false, _iconGeo),
    // Android 12 splash (icon must be small, ~200dp circle).
    Variant('assets/images/splash_logo_android12.png', 1080, false, _android12Geo),
  ];
  for (final v in variants) {
    render(v);
  }
  stdout.writeln('done');
}