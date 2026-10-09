import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  /// Bundled families — see `fonts:` in pubspec.yaml.
  static const String serifFamily = 'CormorantGaramond';
  static const String sansFamily = 'Inter';

  static TextStyle serif({
    double size = 20,
    FontWeight weight = FontWeight.w500,
    bool italic = false,
    Color? color,
    double height = 1.15,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextTheme _textTheme(Color paint, Color muted) {
    const serif = TextStyle(fontFamily: serifFamily);
    const sans = TextStyle(fontFamily: sansFamily);
    return TextTheme(
      displayLarge: serif.copyWith(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        height: 1.02,
        letterSpacing: -0.5,
        color: paint,
      ),
      displayMedium: serif.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        height: 1.08,
        color: paint,
      ),
      headlineLarge: serif.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -0.4,
        color: paint,
      ),
      headlineMedium: serif.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.3,
        color: paint,
      ),
      headlineSmall: serif.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.2,
        color: paint,
      ),
      titleLarge: serif.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: paint,
      ),
      titleMedium: sans.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: paint,
      ),
      titleSmall: sans.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: muted,
      ),
      bodyLarge: sans.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: paint,
      ),
      bodyMedium: sans.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: paint,
      ),
      bodySmall: sans.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: muted,
      ),
      labelLarge: sans.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: paint,
      ),
      labelMedium: sans.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.3,
        color: muted,
      ),
    ).apply(displayColor: paint, bodyColor: paint);
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: Brightness.light,
      primary: AppColors.ink,
      secondary: AppColors.inkMuted,
      surface: AppColors.paperSurface,
      surfaceContainerLowest: AppColors.paper,
      surfaceContainerLow: AppColors.paper,
      surfaceContainer: AppColors.paperSurfaceContainer,
      surfaceContainerHigh: AppColors.paperSurfaceHigh,
      onPrimary: AppColors.paperSurface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      outlineVariant: AppColors.ink.withValues(alpha: 0.14),
    );
    return _base(scheme, _textTheme(AppColors.ink, AppColors.inkMuted));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.parchment,
      brightness: Brightness.dark,
      primary: AppColors.parchment,
      secondary: AppColors.parchment,
      surface: AppColors.espressoSurface,
      surfaceContainerLowest: AppColors.espresso,
      surfaceContainerLow: AppColors.espressoSurface,
      surfaceContainer: AppColors.espressoSurfaceContainer,
      surfaceContainerHigh: AppColors.espressoSurfaceHigh,
      onPrimary: AppColors.espresso,
      onSurface: AppColors.parchment,
      onSurfaceVariant: AppColors.parchmentMuted,
      outlineVariant: AppColors.parchment.withValues(alpha: 0.16),
    );
    return _base(
      scheme,
      _textTheme(AppColors.parchment, AppColors.parchmentMuted),
    );
  }

  static ThemeData _base(ColorScheme scheme, TextTheme textTheme) {
    final hairline = scheme.outlineVariant;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary,
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        checkmarkColor: scheme.onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        filled: true,
        fillColor: scheme.surface,
        suffixIconColor: scheme.onSurfaceVariant,
        prefixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.08),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: scheme.outlineVariant, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.onSurface.withValues(alpha: 0.10),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
