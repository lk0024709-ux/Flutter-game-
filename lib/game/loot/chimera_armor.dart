import '../elite/chimera.dart';

/// Mechanical hooks an elite armour can grant the warrior.
enum EliteArmorEffect {
  diveDash,
  poisonImmunity,
  knockbackResist,
  dodgeInstinct,
  poisonAura,
  phaseShift,

  /// Rann's Regalia grants every other effect.
  allEffects,
}

/// Elite-exclusive armours. They stack on top of the base armour and each one
/// drops from its own chimera.
enum ChimeraArmorKind {
  gryphonPlate(
    'Gryphon Plate',
    '🦅',
    ChimeraType.gryphonPrime,
    150,
    0.40,
    0.10,
    'Dive dash every 8s for 20 damage.',
    EliteArmorEffect.diveDash,
    0xFF8A8F98,
  ),
  basiliskScale(
    'Basilisk Scale',
    '🐍',
    ChimeraType.basilisk,
    130,
    0.38,
    0.08,
    'Poison immunity + 15% damage reflect.',
    EliteArmorEffect.poisonImmunity,
    0xFF3F6212,
    reflectPercent: 0.15,
  ),
  ravagerHide(
    'Ravager Hide',
    '🐗',
    ChimeraType.ravager,
    200,
    0.45,
    0.05,
    'Charge knockback resistance, 60%.',
    EliteArmorEffect.knockbackResist,
    0xFF78350F,
    knockbackResist: 0.60,
  ),
  wyvernWing(
    'Wyvern Wing',
    '🪶',
    ChimeraType.wyvern,
    120,
    0.35,
    0.15,
    '15% dodge chance plus longer reach.',
    EliteArmorEffect.dodgeInstinct,
    0xFF0E7490,
    dodgeChance: 0.15,
    reachBonus: 10,
  ),
  deathrollShell(
    'Deathroll Shell',
    '🐚',
    ChimeraType.deathroll,
    180,
    0.42,
    0.06,
    'Poison aura burns nearby beasts.',
    EliteArmorEffect.poisonAura,
    0xFF4D7C0F,
  ),
  rannsRegalia(
    "Rann's Regalia",
    '👑',
    ChimeraType.rannsChimera,
    250,
    0.50,
    0.12,
    'Every previous elite effect at once.',
    EliteArmorEffect.allEffects,
    0xFF1C1917,
    dodgeChance: 0.12,
    knockbackResist: 0.5,
    reflectPercent: 0.12,
    reachBonus: 10,
  ),
  omegaCore(
    'Omega Core',
    '🐲',
    ChimeraType.omegaChimera,
    400,
    0.60,
    0.20,
    'Phase shift below 33% health.',
    EliteArmorEffect.phaseShift,
    0xFF4C1D95,
    reachBonus: 14,
  );

  const ChimeraArmorKind(
    this.label,
    this.icon,
    this.chimera,
    this.hpBonus,
    this.defensePercent,
    this.speedBonusPercent,
    this.description,
    this.effect,
    this.colorValue, {
    this.reflectPercent = 0,
    this.knockbackResist = 0,
    this.dodgeChance = 0,
    this.reachBonus = 0,
  });

  final String label;
  final String icon;
  final ChimeraType chimera;
  final int hpBonus;
  final double defensePercent;
  final double speedBonusPercent;
  final String description;
  final EliteArmorEffect effect;
  final int colorValue;
  final double reflectPercent;
  final double knockbackResist;
  final double dodgeChance;
  final double reachBonus;

  /// True when this armour grants [effect] (Regalia grants everything).
  bool hasEffect(EliteArmorEffect effect) {
    if (this.effect == effect) {
      return true;
    }
    return this.effect == EliteArmorEffect.allEffects &&
        effect != EliteArmorEffect.allEffects;
  }

  static ChimeraArmorKind? byName(String? name) {
    for (final ChimeraArmorKind armor in ChimeraArmorKind.values) {
      if (armor.name == name) {
        return armor;
      }
    }
    return null;
  }

  /// The armour a given chimera drops.
  static ChimeraArmorKind forChimera(ChimeraType type) {
    for (final ChimeraArmorKind armor in ChimeraArmorKind.values) {
      if (armor.chimera == type) {
        return armor;
      }
    }
    return ChimeraArmorKind.gryphonPlate;
  }
}
