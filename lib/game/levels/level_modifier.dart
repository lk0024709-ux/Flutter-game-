import 'package:flutter/material.dart';

/// Buckets used by the level-detail modal to group the modifier chips.
enum ModifierKind { npcBoost, playerNerf, environment, special }

/// The twenty level modifiers. A level stacks between one and four of them
/// (see [LevelsData.modifiersFor]); boss levels list theirs by hand.
enum LevelModifier {
  npcTough('Tough Hide', '🐗', '+25% beast health', ModifierKind.npcBoost),
  npcFierce('Fierce', '🩸', '+25% beast damage', ModifierKind.npcBoost),
  npcSwift('Swift', '💨', '+20% beast speed', ModifierKind.npcBoost),
  npcLegion('Legion', '👥', '5 extra beasts join', ModifierKind.npcBoost),
  npcElite('Elite Tier', '🎖️', 'Beasts spawn as elite variants', ModifierKind.npcBoost),
  noHeal('No Healing', '🚫', 'Shrines and regeneration are dead', ModifierKind.playerNerf),
  noShield('No Shield', '🛡️', 'Your defense is halved', ModifierKind.playerNerf),
  ironSkinless('Iron Skinless', '🪓', 'Armour effect cut by half', ModifierKind.playerNerf),
  slowForge('Slow Forge', '⚒️', 'Attack cooldown +30%', ModifierKind.playerNerf),
  fastStorm('Fast Storm', '🌪️', 'The ring closes 30% faster', ModifierKind.environment),
  lowGravity('Low Gravity', '🌀', '+50% knockback for everyone', ModifierKind.environment),
  slippery('Slippery', '🧊', 'Grip is halved across the arena', ModifierKind.environment),
  darkness('Darkness', '🌑', 'Vision reduced by 30%', ModifierKind.environment),
  risingLava('Rising Lava', '🌋', 'Lava pools keep growing', ModifierKind.environment),
  thinAir('Thin Air', '🌬️', 'Everybody moves 10% slower', ModifierKind.environment),
  bossRush('Boss Rush', '👑', 'An extra elite beast joins', ModifierKind.special),
  ironman('Ironman', '💀', 'You fight with a single hit point', ModifierKind.special),
  speedrun('Speedrun', '⏱️', 'The storm collapses after 60s', ModifierKind.special),
  noPowers('No Powers', '⚡', 'No power-ups drop at all', ModifierKind.special),
  mirrorMatch('Mirror Match', '🪞', 'You take +25% incoming damage', ModifierKind.special);

  const LevelModifier(this.label, this.icon, this.description, this.kind);

  final String label;
  final String icon;
  final String description;
  final ModifierKind kind;

  /// Muted chip tint (never neon).
  Color get color {
    switch (kind) {
      case ModifierKind.npcBoost:
        return const Color(0xFFB91C1C);
      case ModifierKind.playerNerf:
        return const Color(0xFF7C2D12);
      case ModifierKind.environment:
        return const Color(0xFF0891B2);
      case ModifierKind.special:
        return const Color(0xFF1C1917);
    }
  }

  /// Short type badge for the level-detail modal.
  String get kindLabel {
    switch (kind) {
      case ModifierKind.npcBoost:
        return 'BEASTS';
      case ModifierKind.playerNerf:
        return 'WARRIOR';
      case ModifierKind.environment:
        return 'ARENA';
      case ModifierKind.special:
        return 'SPECIAL';
    }
  }
}
