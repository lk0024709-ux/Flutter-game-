import 'package:flutter/material.dart';

/// Central colour palette for Blade Brawl: Rannbhoomi.
///
/// The design language is "modern premium": warm, muted, earthy and editorial.
/// There is deliberately no neon, no chrome and no saturated glow anywhere in
/// the app - every colour below is a soft, desaturated tone.
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------- light mode
  static const Color background = Color(0xFFF5F1EA); // warm cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEDE7DB); // soft sand
  static const Color border = Color(0xFFE7E1D3);
  static const Color primary = Color(0xFFD97706); // amber
  static const Color primaryDark = Color(0xFFB45309);
  static const Color secondary = Color(0xFF3F6212); // forest
  static const Color accent = Color(0xFF7C2D12); // rust
  static const Color textPrimary = Color(0xFF1C1917);
  static const Color textMuted = Color(0xFF78716C);
  static const Color success = Color(0xFF15803D);
  static const Color danger = Color(0xFFB91C1C);

  // ----------------------------------------------------------------- dark mode
  static const Color darkBackground = Color(0xFF1C1917);
  static const Color darkSurface = Color(0xFF26241F);
  static const Color darkSurfaceAlt = Color(0xFF2E2B25);
  static const Color darkBorder = Color(0xFF3A372F);
  static const Color darkTextPrimary = Color(0xFFF5F5F4);
  static const Color darkTextMuted = Color(0xFFA8A29E);

  // ------------------------------------------------------------- soft shadows
  static const Color shadow = Color(0x14000000); // black @ 8%
  static const Color shadowStrong = Color(0x26000000); // black @ 15%

  // ------------------------------------------------------------ rank palette
  static const int rankBronzeValue = 0xFFA16207;
  static const int rankSilverValue = 0xFF94A3B8;
  static const int rankGoldValue = 0xFFD97706;
  static const int rankPlatinumValue = 0xFF0891B2;
  static const int rankDiamondValue = 0xFF6366F1;
  static const int rankMastersValue = 0xFF7C2D12;
  static const int rankGrandMastersValue = 0xFF1C1917;

  // ----------------------------------------------------------- grade palette
  static const Color gradeSS = Color(0xFFD97706);
  static const Color gradeS = Color(0xFF7E22CE);
  static const Color gradeA = Color(0xFF0891B2);
  static const Color gradeB = Color(0xFF65A30D);
  static const Color gradeC = Color(0xFFA16207);
  static const Color gradeD = Color(0xFF78716C);
  static const Color gradeNone = Color(0xFFA8A29E);

  // ----------------------------------------------------------- loot palette
  static const Color rarityCommon = Color(0xFF78716C);
  static const Color rarityRare = Color(0xFF1D4ED8);
  static const Color rarityEpic = Color(0xFF7E22CE);
  static const Color rarityLegendary = Color(0xFFC2410C);
  static const Color rarityMythic = Color(0xFFB91C1C);

  // -------------------------------------------------------- in-world colours
  static const Color arenaVoid = Color(0xFF14110F);
  static const Color hpGreen = Color(0xFF3F6212);
  static const Color hpAmber = Color(0xFFD97706);
  static const Color hpRed = Color(0xFFB91C1C);
  static const Color poison = Color(0xFF4D7C0F);
  static const Color stormBlue = Color(0xFF64748B);
  static const Color sanctuaryCream = Color(0xFFF5F1EA);
  static const Color shrineGreen = Color(0xFF15803D);
  static const Color furnaceEmber = Color(0xFFEA580C);
}

/// Spacing tokens (4pt base grid).
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// Corner radius tokens.
class AppRadius {
  const AppRadius._();
  static const double button = 12;
  static const double chip = 10;
  static const double card = 20;
  static const double cardLarge = 24;
  static const double pill = 999;
}

/// Motion tokens - everything in the UI animates between 200 and 300ms.
class AppMotion {
  const AppMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration reveal = Duration(milliseconds: 500);
}
