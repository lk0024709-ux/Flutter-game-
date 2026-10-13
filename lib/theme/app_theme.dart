import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFFF5F1EA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEDE7DB);
  static const border = Color(0xFFE7E1D3);
  static const primary = Color(0xFFD97706);
  static const primaryDark = Color(0xFFB45309);
  static const secondary = Color(0xFF3F6212);
  static const accent = Color(0xFF7C2D12);
  static const textPrimary = Color(0xFF1C1917);
  static const textMuted = Color(0xFF78716C);
  static const success = Color(0xFF15803D);
  static const danger = Color(0xFFB91C1C);

  static const darkBackground = Color(0xFF1C1917);
  static const darkSurface = Color(0xFF26241F);
  static const darkSurfaceAlt = Color(0xFF2E2B25);
  static const darkBorder = Color(0xFF3A372F);
  static const darkText = Color(0xFFF5F5F4);
  static const darkMuted = Color(0xFFA8A29E);
}

abstract final class AppTheme {
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.darkMuted : AppColors.textMuted;
    final textPrimary = isDark ? AppColors.darkText : AppColors.textPrimary;
    final inter = GoogleFonts.interTextTheme();
    final textTheme = inter.copyWith(
      displayLarge: inter.displayLarge?.copyWith(
        fontFamily: GoogleFonts.manrope().fontFamily,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: textPrimary,
      ),
      displayMedium: inter.displayMedium?.copyWith(
        fontFamily: GoogleFonts.manrope().fontFamily,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: textPrimary,
      ),
      headlineLarge: inter.headlineLarge?.copyWith(
        fontFamily: GoogleFonts.manrope().fontFamily,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
        color: textPrimary,
      ),
      headlineMedium: inter.headlineMedium?.copyWith(
        fontFamily: GoogleFonts.manrope().fontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: textPrimary,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontFamily: GoogleFonts.manrope().fontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        color: textPrimary,
      ),
      titleMedium: inter.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(color: textPrimary, height: 1.45),
      bodyMedium: inter.bodyMedium?.copyWith(color: textPrimary, height: 1.4),
      bodySmall: inter.bodySmall?.copyWith(color: textMuted, height: 1.35),
      labelLarge: inter.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: textPrimary,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: textPrimary,
      ),
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      surface: isDark ? AppColors.darkSurface : AppColors.surface,
      primary: isDark ? const Color(0xFFE3A64B) : AppColors.primary,
      secondary: isDark ? const Color(0xFFA3B18A) : AppColors.secondary,
      error: isDark ? const Color(0xFFE07A6D) : AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      textTheme: textTheme,
      dividerColor: isDark ? AppColors.darkBorder : AppColors.border,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      iconTheme: IconThemeData(color: isDark ? AppColors.darkText : AppColors.textPrimary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
    );
  }
}
