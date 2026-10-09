import 'package:flutter/material.dart';

/// Inkvoy design tokens — strict black & white editorial ("newsprint") identity.
/// Hierarchy by type-scale contrast, hairlines & inverted plates. No accent color.
abstract final class AppColors {
  /// True ink — the darkest point of the newsprint ramp. Never #000.
  static const Color ink = Color(0xFF0D0D0D);
  static const Color inkSoft = Color(0xFF1A1A1A);
  static const Color inkMuted = Color(0xFF595959);

  // ---- Light ("Newsprint") ----
  static const Color paper = Color(0xFFFAF8F4); // warm paper canvas, not white
  static const Color paperSurface = Color(0xFFFFFFFF); // cards
  static const Color paperSurfaceContainer = Color(0xFFF2F2F2);
  static const Color paperSurfaceHigh = Color(0xFFE9E9E9);

  // ---- Dark ("Ebon") ----
  static const Color espresso = Color(0xFF0D0D0D); // canvas, never pure black
  static const Color espressoSurface = Color(0xFF1A1A1A);
  static const Color espressoSurfaceContainer = Color(0xFF242424);
  static const Color espressoSurfaceHigh = Color(0xFF2E2E2E);
  static const Color parchment = Color(0xFFF2F2F2); // text, never pure white
  static const Color parchmentMuted = Color(0xFFA3A3A3);

  /// Inverted plate palette (used for black masthead / stat bands).
  static const Color plate = Color(0xFF0D0D0D);
  static const Color plateText = Color(0xFFF2F2F2);
  static const Color plateMuted = Color(0xFFA3A3A3);
  static const Color plateRule = Color(0xFF333333);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
  );
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 24;
}

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 100;
}

/// Soft, surface-tinted elevation shadows (never pure black-on-gray).
abstract final class AppShadows {
  /// Subtle resting shadow for cards & raised tiles.
  static BoxShadow soft(
    Color surface, {
    double alpha = 0.10,
    double blur = 16,
    double dy = 4,
  }) {
    return BoxShadow(
      color: Color.lerp(surface, Colors.black, 1.0)!.withValues(alpha: alpha),
      blurRadius: blur,
      offset: Offset(0, dy),
    );
  }

  /// A touch deeper shadow for hero/featured surfaces.
  static BoxShadow raised(
    Color surface, {
    double alpha = 0.16,
    double blur = 28,
    double dy = 10,
  }) {
    return BoxShadow(
      color: Color.lerp(surface, Colors.black, 1.0)!.withValues(alpha: alpha),
      blurRadius: blur,
      offset: Offset(0, dy),
    );
  }
}

/// Monochrome reading surfaces for the in-app reader.
abstract final class ReaderThemes {
  static const List<(String, Color, Color, Color)> all = [
    ('Bright', Color(0xFFFFFFFF), Color(0xFF181818), Color(0xFF4A4A4A)),
    ('Paper', Color(0xFFF2F2F2), Color(0xFF181818), Color(0xFF3F3F3F)),
    ('Slate', Color(0xFF3A3A3A), Color(0xFFF0F0F0), Color(0xFFB5B5B5)),
    ('Midnight', Color(0xFF141414), Color(0xFFF5F5F5), Color(0xFF9A9A9A)),
  ];
}
