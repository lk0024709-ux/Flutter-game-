import 'package:flutter/material.dart';
import 'package:flame/extensions.dart';

import 'drake.dart';
import 'griffin.dart';
import 'ironboar.dart';
import 'levels/boss_levels.dart';
import 'npc.dart';
import 'skyhawk.dart';
import 'venomtail.dart';

/// Signature behaviour of each wild creature.
enum CreatureSpecial {
  balancedAggressive,
  rangedFire,
  diveAttack,
  charge,
  poison,
}

/// The five wild mythical creatures of Rannbhoomi.
///
/// Every creature rolls its own faction on spawn, so the arena is a genuine
/// free-for-all: beasts fight each other exactly as hard as they fight you.
enum CreatureType {
  griffin(
    'Griffin',
    '🦅',
    70,
    160,
    14,
    65,
    0.7,
    20,
    0xFFC2410C,
    CreatureSpecial.balancedAggressive,
    'Balanced and aggressive. Wing-flap dash (2x speed, 0.5s) every 4s.',
  ),
  drake(
    'Drake',
    '🐉',
    55,
    130,
    16,
    220,
    1.4,
    22,
    0xFF166534,
    CreatureSpecial.rangedFire,
    'Ranged. Holds 180 units and breathes fire (12 dmg, 400 u/s).',
  ),
  skyhawk(
    'Skyhawk',
    '🪶',
    45,
    220,
    12,
    55,
    0.5,
    16,
    0xFF92400E,
    CreatureSpecial.diveAttack,
    'Circles at 150 units and dives every 3s (3x speed, 18 dmg contact).',
  ),
  ironboar(
    'Ironboar',
    '🐗',
    120,
    110,
    20,
    60,
    1.1,
    26,
    0xFF44403C,
    CreatureSpecial.charge,
    'Charges every 5s: 0.6s telegraph, 2.5x speed for 1s, 30 dmg + knockback.',
  ),
  venomtail(
    'Venomtail',
    '🐍',
    60,
    150,
    10,
    70,
    0.8,
    18,
    0xFF4D7C0F,
    CreatureSpecial.poison,
    'Bites apply poison stacks (max 5, 2 dmg/s each, 4s, refreshed on hit).',
  );

  const CreatureType(
    this.label,
    this.emoji,
    this.hp,
    this.speed,
    this.damage,
    this.reach,
    this.attackInterval,
    this.size,
    this.colorValue,
    this.special,
    this.description,
  );

  final String label;
  final String emoji;
  final double hp;
  final double speed;
  final double damage;
  final double reach;
  final double attackInterval;
  final double size;
  final int colorValue;
  final CreatureSpecial special;
  final String description;

  Color get baseColor => Color(colorValue);

  bool get isRanged => special == CreatureSpecial.rangedFire;

  /// Preferred fighting distance for the AI.
  double get preferredRange {
    switch (special) {
      case CreatureSpecial.rangedFire:
        return 180;
      case CreatureSpecial.diveAttack:
        return 150;
      case CreatureSpecial.charge:
        return reach;
      case CreatureSpecial.poison:
        return reach;
      case CreatureSpecial.balancedAggressive:
        return reach;
    }
  }

  /// Creates the concrete NPC subclass for this creature.
  Npc spawn({
    required Vector2 position,
    required int fighterId,
    required int factionId,
    required double difficulty,
    bool elite = false,
    bool mirrorClone = false,
    bool neutral = false,
    bool boss = false,
    bool permanent = false,
    double? hpOverride,
    String? nameOverride,
    BossProfile? bossProfile,
    double hpScaleMul = 1.0,
    double damageScaleMul = 1.0,
    double speedScaleMul = 1.0,
  }) {
    switch (this) {
      case CreatureType.griffin:
        return Griffin(
          fighterId: fighterId,
          factionId: factionId,
          position: position,
          difficulty: difficulty,
          elite: elite,
          mirrorClone: mirrorClone,
          neutral: neutral,
          boss: boss,
          permanent: permanent,
          hpOverride: hpOverride,
          nameOverride: nameOverride,
          bossProfile: bossProfile,
          hpScaleMul: hpScaleMul,
          damageScaleMul: damageScaleMul,
          speedScaleMul: speedScaleMul,
        );
      case CreatureType.drake:
        return Drake(
          fighterId: fighterId,
          factionId: factionId,
          position: position,
          difficulty: difficulty,
          elite: elite,
          mirrorClone: mirrorClone,
          neutral: neutral,
          boss: boss,
          permanent: permanent,
          hpOverride: hpOverride,
          nameOverride: nameOverride,
          bossProfile: bossProfile,
          hpScaleMul: hpScaleMul,
          damageScaleMul: damageScaleMul,
          speedScaleMul: speedScaleMul,
        );
      case CreatureType.skyhawk:
        return Skyhawk(
          fighterId: fighterId,
          factionId: factionId,
          position: position,
          difficulty: difficulty,
          elite: elite,
          mirrorClone: mirrorClone,
          neutral: neutral,
          boss: boss,
          permanent: permanent,
          hpOverride: hpOverride,
          nameOverride: nameOverride,
          bossProfile: bossProfile,
          hpScaleMul: hpScaleMul,
          damageScaleMul: damageScaleMul,
          speedScaleMul: speedScaleMul,
        );
      case CreatureType.ironboar:
        return Ironboar(
          fighterId: fighterId,
          factionId: factionId,
          position: position,
          difficulty: difficulty,
          elite: elite,
          mirrorClone: mirrorClone,
          neutral: neutral,
          boss: boss,
          permanent: permanent,
          hpOverride: hpOverride,
          nameOverride: nameOverride,
          bossProfile: bossProfile,
          hpScaleMul: hpScaleMul,
          damageScaleMul: damageScaleMul,
          speedScaleMul: speedScaleMul,
        );
      case CreatureType.venomtail:
        return Venomtail(
          fighterId: fighterId,
          factionId: factionId,
          position: position,
          difficulty: difficulty,
          elite: elite,
          mirrorClone: mirrorClone,
          neutral: neutral,
          boss: boss,
          permanent: permanent,
          hpOverride: hpOverride,
          nameOverride: nameOverride,
          bossProfile: bossProfile,
          hpScaleMul: hpScaleMul,
          damageScaleMul: damageScaleMul,
          speedScaleMul: speedScaleMul,
        );
    }
  }
}
