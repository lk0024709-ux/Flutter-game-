import 'package:flutter/material.dart';

import '../level_grade.dart';
import 'loot_rarity.dart';

/// Chest tiers awarded by elite trials (and the campaign rank bosses).
enum ChestRarity {
  bronze(
    'Bronze Chest',
    '🥉',
    3,
    500,
    800,
    100,
    150,
    0,
    0.00,
    0.00,
    0.00,
    0.00,
    Color(0xFFA16207),
  ),
  silver(
    'Silver Chest',
    '🥈',
    3,
    900,
    1400,
    180,
    250,
    0,
    0.00,
    0.00,
    0.00,
    0.00,
    Color(0xFF94A3B8),
  ),
  gold(
    'Gold Chest',
    '🥇',
    4,
    1800,
    2600,
    300,
    400,
    1,
    0.00,
    0.00,
    0.00,
    0.00,
    Color(0xFFD97706),
  ),
  platinum(
    'Platinum Chest',
    '💠',
    5,
    3000,
    4500,
    500,
    650,
    1,
    0.25,
    0.00,
    0.00,
    0.00,
    Color(0xFF0891B2),
  ),
  diamond(
    'Diamond Chest',
    '💎',
    6,
    5000,
    7500,
    800,
    1100,
    2,
    1.00,
    0.20,
    0.00,
    0.00,
    Color(0xFF6366F1),
  ),
  mythic(
    'Mythic Chest',
    '👑',
    7,
    8000,
    12000,
    1500,
    2000,
    3,
    1.00,
    1.00,
    1.00,
    1.00,
    Color(0xFFB91C1C),
  );

  const ChestRarity(
    this.label,
    this.icon,
    this.itemCount,
    this.minCoins,
    this.maxCoins,
    this.minXp,
    this.maxXp,
    this.guaranteedEpics,
    this.powerChance,
    this.armorChance,
    this.weaponChance,
    this.titleChance,
    this.color,
  );

  final String label;
  final String icon;

  /// Total number of loot cards revealed (coins and XP count as cards).
  final int itemCount;
  final int minCoins;
  final int maxCoins;
  final int minXp;
  final int maxXp;

  /// Guaranteed elite-power drops.
  final int guaranteedEpics;

  /// Chance (0..1) for each of the special reward types.
  final double powerChance;
  final double armorChance;
  final double weaponChance;
  final double titleChance;

  final Color color;

  /// Grade -> chest mapping: D bronze, C silver, B gold, A platinum, S diamond, SS mythic.
  static ChestRarity forGrade(LevelGrade grade) {
    switch (grade) {
      case LevelGrade.ss:
        return ChestRarity.mythic;
      case LevelGrade.s:
        return ChestRarity.diamond;
      case LevelGrade.a:
        return ChestRarity.platinum;
      case LevelGrade.b:
        return ChestRarity.gold;
      case LevelGrade.c:
        return ChestRarity.silver;
      case LevelGrade.d:
      case LevelGrade.none:
        return ChestRarity.bronze;
    }
  }

  double get averageCoins => (minCoins + maxCoins) / 2;

  /// Rarity bone for the reveal animation.
  LootRarity get lootRarity => LootRarity.values[index.clamp(0, LootRarity.values.length - 1)];
}
