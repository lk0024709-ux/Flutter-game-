import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography helpers built on google_fonts.
///
/// Headings use Manrope (700-800, tight letter spacing); body copy and
/// controls use Inter. Every helper accepts an optional colour override so
/// widgets can stay declarative.
class AppText {
  const AppText._();

  static TextStyle display({
    double size = 34,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w800,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.5,
      color: color,
      height: 1.1,
    );
  }

  static TextStyle heading({
    double size = 24,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w700,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.5,
      color: color,
      height: 1.15,
    );
  }

  static TextStyle title({
    double size = 18,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w700,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.3,
      color: color,
    );
  }

  static TextStyle body({
    double size = 14,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.35,
    );
  }

  static TextStyle label({
    double size = 12,
    Color color = AppColors.textMuted,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.1,
    );
  }

  static TextStyle button({
    double size = 15,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.2,
    );
  }

  static TextStyle number({
    double size = 15,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.2,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }
}

/// Material theme wiring. Only stable, long-lived ThemeData fields are used so
/// the app builds identically on older and newer Flutter stable channels.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      primaryTextTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.surface,
        displayColor: AppColors.surface,
      ),
      splashFactory: InkRipple.splashFactory,
      dividerColor: AppColors.border,
    );
  }

  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      error: AppColors.danger,
    );
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),
      dividerColor: AppColors.darkBorder,
    );
  }
}

/// Convenience soft shadow used by every card in the app.
List<BoxShadow> softShadow({bool strong = false}) {
  return <BoxShadow>[
    BoxShadow(
      color: strong ? AppColors.shadowStrong : AppColors.shadow,
      blurRadius: strong ? 24 : 16,
      offset: const Offset(0, 4),
    ),
  ];
}
