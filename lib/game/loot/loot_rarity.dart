import 'package:flutter/material.dart';

/// Rarity ladder used by every chest reward and inventory card.
enum LootRarity {
  common('Common', '⚪', Color(0xFF78716C)),
  rare('Rare', '🔵', Color(0xFF1D4ED8)),
  epic('Epic', '🟣', Color(0xFF7E22CE)),
  legendary('Legendary', '🟠', Color(0xFFC2410C)),
  mythic('Mythic', '🔴', Color(0xFFB91C1C));

  const LootRarity(this.label, this.icon, this.color);

  final String label;
  final String icon;
  final Color color;

  int get weight {
    switch (this) {
      case LootRarity.common:
        return 50;
      case LootRarity.rare:
        return 26;
      case LootRarity.epic:
        return 14;
      case LootRarity.legendary:
        return 7;
      case LootRarity.mythic:
        return 3;
    }
  }
}
