import 'package:material_ui/material_ui.dart';

enum CreatureType { griffin, drake, skyhawk, ironboar, venomtail }

extension CreatureTypeData on CreatureType {
  String get title => switch (this) {
        CreatureType.griffin => 'Griffin',
        CreatureType.drake => 'Drake',
        CreatureType.skyhawk => 'Skyhawk',
        CreatureType.ironboar => 'Ironboar',
        CreatureType.venomtail => 'Venomtail',
      };

  String get emoji => switch (this) {
        CreatureType.griffin => '🦁',
        CreatureType.drake => '🐉',
        CreatureType.skyhawk => '🦅',
        CreatureType.ironboar => '🐗',
        CreatureType.venomtail => '🐍',
      };

  int get baseHp => switch (this) {
        CreatureType.griffin => 70,
        CreatureType.drake => 55,
        CreatureType.skyhawk => 45,
        CreatureType.ironboar => 120,
        CreatureType.venomtail => 60,
      };

  double get baseSpeed => switch (this) {
        CreatureType.griffin => 160,
        CreatureType.drake => 130,
        CreatureType.skyhawk => 220,
        CreatureType.ironboar => 110,
        CreatureType.venomtail => 150,
      };

  int get baseDamage => switch (this) {
        CreatureType.griffin => 14,
        CreatureType.drake => 16,
        CreatureType.skyhawk => 12,
        CreatureType.ironboar => 20,
        CreatureType.venomtail => 10,
      };

  double get baseRange => switch (this) {
        CreatureType.griffin => 65,
        CreatureType.drake => 220,
        CreatureType.skyhawk => 55,
        CreatureType.ironboar => 60,
        CreatureType.venomtail => 70,
      };

  double get attackInterval => switch (this) {
        CreatureType.griffin => 0.7,
        CreatureType.drake => 1.4,
        CreatureType.skyhawk => 0.5,
        CreatureType.ironboar => 1.1,
        CreatureType.venomtail => 0.8,
      };

  double get bodyRadius => switch (this) {
        CreatureType.griffin => 20,
        CreatureType.drake => 22,
        CreatureType.skyhawk => 16,
        CreatureType.ironboar => 26,
        CreatureType.venomtail => 18,
      };

  Color get baseColor => switch (this) {
        CreatureType.griffin => const Color(0xFFC2410C),
        CreatureType.drake => const Color(0xFF166534),
        CreatureType.skyhawk => const Color(0xFF92400E),
        CreatureType.ironboar => const Color(0xFF44403C),
        CreatureType.venomtail => const Color(0xFF4D7C0F),
      };
}

enum WeaponTier { dagger, sword, axe, trident, storm, mythic }

extension WeaponTierData on WeaponTier {
  int get level => index + 1;
  String get title => switch (this) {
        WeaponTier.dagger => 'Dagger',
        WeaponTier.sword => 'Sword',
        WeaponTier.axe => 'War Axe',
        WeaponTier.trident => 'Trident',
        WeaponTier.storm => 'Storm Blade',
        WeaponTier.mythic => 'Mythic Blade',
      };
  String get icon => switch (this) {
        WeaponTier.dagger => '🗡️',
        WeaponTier.sword => '⚔️',
        WeaponTier.axe => '🪓',
        WeaponTier.trident => '🔱',
        WeaponTier.storm => '⚡',
        WeaponTier.mythic => '💎',
      };
  int get damage => switch (this) {
        WeaponTier.dagger => 15,
        WeaponTier.sword => 22,
        WeaponTier.axe => 35,
        WeaponTier.trident => 50,
        WeaponTier.storm => 75,
        WeaponTier.mythic => 120,
      };
  double get reach => switch (this) {
        WeaponTier.dagger => 55,
        WeaponTier.sword => 70,
        WeaponTier.axe => 75,
        WeaponTier.trident => 95,
        WeaponTier.storm => 110,
        WeaponTier.mythic => 130,
      };
  double get cooldown => switch (this) {
        WeaponTier.dagger => 0.35,
        WeaponTier.sword => 0.45,
        WeaponTier.axe => 0.55,
        WeaponTier.trident => 0.60,
        WeaponTier.storm => 0.70,
        WeaponTier.mythic => 0.80,
      };
  Color get accent => switch (this) {
        WeaponTier.dagger => const Color(0xFF9A8C78),
        WeaponTier.sword => const Color(0xFF64748B),
        WeaponTier.axe => const Color(0xFFB45309),
        WeaponTier.trident => const Color(0xFF0F766E),
        WeaponTier.storm => const Color(0xFF6D5A45),
        WeaponTier.mythic => const Color(0xFF7C5B31),
      };

  static WeaponTier fromLevel(int level) =>
      WeaponTier.values[(level - 1).clamp(0, WeaponTier.values.length - 1)];
}

enum ArmorRank { normal, advanced, legend, epic }

extension ArmorRankData on ArmorRank {
  String get title => switch (this) {
        ArmorRank.normal => 'Cloth Tunic',
        ArmorRank.advanced => 'Warden Mail',
        ArmorRank.legend => 'Legend Mantle',
        ArmorRank.epic => 'Aegis of Rann',
      };
  String get rankName => switch (this) {
        ArmorRank.normal => 'Normal',
        ArmorRank.advanced => 'Advanced',
        ArmorRank.legend => 'Legend',
        ArmorRank.epic => 'Epic',
      };
  String get icon => switch (this) {
        ArmorRank.normal => '🥉',
        ArmorRank.advanced => '🥈',
        ArmorRank.legend => '🥇',
        ArmorRank.epic => '💎',
      };
  Color get color => switch (this) {
        ArmorRank.normal => const Color(0xFF9E9E9E),
        ArmorRank.advanced => const Color(0xFF66BB6A),
        ArmorRank.legend => const Color(0xFFAB47BC),
        ArmorRank.epic => const Color(0xFFFFC107),
      };
  int get price => switch (this) {
        ArmorRank.normal => 100,
        ArmorRank.advanced => 350,
        ArmorRank.legend => 900,
        ArmorRank.epic => 2200,
      };
  int get hpBonus => switch (this) {
        ArmorRank.normal => 10,
        ArmorRank.advanced => 25,
        ArmorRank.legend => 50,
        ArmorRank.epic => 100,
      };
  double get defense => switch (this) {
        ArmorRank.normal => 0.05,
        ArmorRank.advanced => 0.12,
        ArmorRank.legend => 0.22,
        ArmorRank.epic => 0.35,
      };
  double get speedBonus => switch (this) {
        ArmorRank.normal => 0,
        ArmorRank.advanced => 0.03,
        ArmorRank.legend => 0.05,
        ArmorRank.epic => 0.08,
      };
  String get description => switch (this) {
        ArmorRank.normal => 'A well-worn tunic. A good place to begin.',
        ArmorRank.advanced => '+5 HP regeneration each second.',
        ArmorRank.legend => 'Reflect 10% of incoming damage.',
        ArmorRank.epic => 'Revive once after a fatal blow.',
      };
}

enum Booster { revive, damage, magnet, ironSkin }

extension BoosterData on Booster {
  String get title => switch (this) {
        Booster.revive => 'Revive Potion',
        Booster.damage => 'Damage Elixir',
        Booster.magnet => 'Chest Magnet',
        Booster.ironSkin => 'Iron Skin',
      };
  String get icon => switch (this) {
        Booster.revive => '❤️',
        Booster.damage => '⚔️',
        Booster.magnet => '🧲',
        Booster.ironSkin => '🛡️',
      };
  int get price => switch (this) {
        Booster.revive => 200,
        Booster.damage => 150,
        Booster.magnet => 100,
        Booster.ironSkin => 180,
      };
  String get description => switch (this) {
        Booster.revive => 'One automatic revive in your next campaign battle.',
        Booster.damage => '+25% sword damage for one campaign battle.',
        Booster.magnet => 'Double the chance of battlefield drops.',
        Booster.ironSkin => '+20% damage reduction for one campaign battle.',
      };
}

enum Rank { bronze, silver, gold, platinum, diamond, masters, grandMasters }

extension RankData on Rank {
  String get title => switch (this) {
        Rank.bronze => 'Bronze',
        Rank.silver => 'Silver',
        Rank.gold => 'Gold',
        Rank.platinum => 'Platinum',
        Rank.diamond => 'Diamond',
        Rank.masters => 'Masters',
        Rank.grandMasters => 'Grand Masters',
      };
  String get icon => switch (this) {
        Rank.bronze => '🥉',
        Rank.silver => '🥈',
        Rank.gold => '🥇',
        Rank.platinum => '💠',
        Rank.diamond => '💎',
        Rank.masters => '🏆',
        Rank.grandMasters => '👑',
      };
  Color get color => switch (this) {
        Rank.bronze => const Color(0xFFA16207),
        Rank.silver => const Color(0xFF94A3B8),
        Rank.gold => const Color(0xFFD97706),
        Rank.platinum => const Color(0xFF0891B2),
        Rank.diamond => const Color(0xFF6366F1),
        Rank.masters => const Color(0xFF7C2D12),
        Rank.grandMasters => const Color(0xFF1C1917),
      };
  int get unlockWins => switch (this) {
        Rank.bronze => 0,
        Rank.silver => 3,
        Rank.gold => 8,
        Rank.platinum => 15,
        Rank.diamond => 25,
        Rank.masters => 40,
        Rank.grandMasters => 60,
      };
  double get coinMultiplier => switch (this) {
        Rank.bronze => 1,
        Rank.silver => 1.2,
        Rank.gold => 1.5,
        Rank.platinum => 2,
        Rank.diamond => 2.5,
        Rank.masters => 3,
        Rank.grandMasters => 5,
      };
  double get rewardRankMultiplier => switch (this) {
        Rank.bronze => 1,
        Rank.silver => 1.5,
        Rank.gold => 2,
        Rank.platinum => 3,
        Rank.diamond => 4,
        Rank.masters => 6,
        Rank.grandMasters => 8,
      };
}

class GameLevel {
  const GameLevel({required this.rank, required this.levelInRank});

  final Rank rank;
  final int levelInRank;

  int get globalLevel => rank.index * 50 + levelInRank;
  double get difficultyMultiplier => 1 + (levelInRank / 50) * 2;
  int get npcCount => 8 + (levelInRank ~/ 5) + rank.index * 2;
  bool get isMiniBoss => levelInRank == 10 || levelInRank == 20 || levelInRank == 30 || levelInRank == 40;
  bool get isRankBoss => levelInRank == 50;
  String get key => 'level_$globalLevel';
}

enum MapTwist { sandfog, ice, lava, movingWalls, mirrors, lightning, allTwists }

class ArenaMap {
  const ArenaMap({
    required this.title,
    required this.shortName,
    required this.description,
    required this.twist,
    required this.ground,
    required this.accent,
    required this.shrinkScale,
  });

  final String title;
  final String shortName;
  final String description;
  final String twist;
  final Color ground;
  final Color accent;
  final double shrinkScale;
}

const List<ArenaMap> arenaMaps = [
  ArenaMap(
    title: 'The Dust Pit',
    shortName: 'Dust Pit',
    description: 'A sun-bleached arena ringed with old bones and dead scrub.',
    twist: 'Sandfog rolls through every 12 seconds.',
    ground: Color(0xFFCBB88D),
    accent: Color(0xFF9A7440),
    shrinkScale: 1.2,
  ),
  ArenaMap(
    title: 'Frost Hollow',
    shortName: 'Frost Hollow',
    description: 'Pale pines and frozen ponds make every step uncertain.',
    twist: 'Slippery ice and biting heat zones.',
    ground: Color(0xFFB9CFD1),
    accent: Color(0xFF537A84),
    shrinkScale: 1,
  ),
  ArenaMap(
    title: 'Ember Forge',
    shortName: 'Ember Forge',
    description: 'Black volcanic stone, warm ash, and slow rivers of lava.',
    twist: 'Lava pools and telegraphed fire geysers.',
    ground: Color(0xFF544842),
    accent: Color(0xFFC65D31),
    shrinkScale: 1,
  ),
  ArenaMap(
    title: 'Jade Temple',
    shortName: 'Jade Temple',
    description: 'A forgotten sanctuary of jade stone and broken columns.',
    twist: 'Moving walls and treasure shrines.',
    ground: Color(0xFF8EAA8A),
    accent: Color(0xFF547558),
    shrinkScale: 0.9,
  ),
  ArenaMap(
    title: 'Crystal Cavern',
    shortName: 'Crystal Cavern',
    description: 'A deep cave threaded with old violet crystal seams.',
    twist: 'Mirror copies echo the strongest fighters.',
    ground: Color(0xFF6E6578),
    accent: Color(0xFFB596C4),
    shrinkScale: 0.9,
  ),
  ArenaMap(
    title: 'Storm Citadel',
    shortName: 'Storm Citadel',
    description: 'A high citadel under a dark, restless sky.',
    twist: 'Lightning strikes and shifting crosswinds.',
    ground: Color(0xFF686D70),
    accent: Color(0xFFB7C3C5),
    shrinkScale: 0.85,
  ),
  ArenaMap(
    title: 'Throne of Rann',
    shortName: 'Throne of Rann',
    description: 'Black marble beneath a sky scattered with gold constellations.',
    twist: 'Every arena twist returns in an unpredictable cycle.',
    ground: Color(0xFF302E2A),
    accent: Color(0xFFD5AD69),
    shrinkScale: 0.8,
  ),
];

String rankBossName(GameLevel level) {
  if (!level.isRankBoss) return 'Arena Champion';
  return switch (level.rank) {
    Rank.bronze => 'Alpha Griffin',
    Rank.silver => 'Frost Tyrant',
    Rank.gold => 'Emberlord',
    Rank.platinum => 'Temple Guardian',
    Rank.diamond => 'Crystal Queen',
    Rank.masters => 'Stormlord',
    Rank.grandMasters => 'Rann’s Avatar',
  };
}

List<CreatureType> creaturesFor(GameLevel level) {
  final count = switch (level.levelInRank) {
    <= 10 => 1,
    <= 20 => 2,
    <= 30 => 3,
    <= 40 => 4,
    _ => 5,
  };
  final available = CreatureType.values.take(count).toList();
  if (level.isRankBoss) {
    switch (level.rank) {
      case Rank.bronze:
        return [CreatureType.griffin];
      case Rank.silver:
        return [CreatureType.drake, CreatureType.skyhawk];
      case Rank.gold:
        return [CreatureType.ironboar, CreatureType.venomtail];
      case Rank.platinum:
        return CreatureType.values.take(4).toList();
      case Rank.diamond:
      case Rank.masters:
      case Rank.grandMasters:
        return CreatureType.values.toList();
    }
  }
  return available;
}

enum LevelModifier {
  npcTough,
  npcFierce,
  npcSwift,
  npcLegion,
  npcElite,
  noHeal,
  noShield,
  ironSkinless,
  slowForge,
  fastStorm,
  lowGravity,
  slippery,
  darkness,
  risingLava,
  bossRush,
  ironman,
  speedrun,
  noPowers,
  mirrorMatch,
}

extension LevelModifierData on LevelModifier {
  String get label => switch (this) {
        LevelModifier.npcTough => 'Tough hides',
        LevelModifier.npcFierce => 'Fierce foes',
        LevelModifier.npcSwift => 'Swift feet',
        LevelModifier.npcLegion => 'Reinforcements',
        LevelModifier.npcElite => 'Elite pack',
        LevelModifier.noHeal => 'No healing',
        LevelModifier.noShield => 'No shield',
        LevelModifier.ironSkinless => 'Armor weakened',
        LevelModifier.slowForge => 'Heavy blade',
        LevelModifier.fastStorm => 'Fast storm',
        LevelModifier.lowGravity => 'Low gravity',
        LevelModifier.slippery => 'Slippery ground',
        LevelModifier.darkness => 'Darkness',
        LevelModifier.risingLava => 'Rising lava',
        LevelModifier.bossRush => 'Boss rush',
        LevelModifier.ironman => 'Ironman',
        LevelModifier.speedrun => 'Speed run',
        LevelModifier.noPowers => 'No powers',
        LevelModifier.mirrorMatch => 'Mirror match',
      };
}

List<LevelModifier> modifiersFor(GameLevel level) {
  final result = <LevelModifier>[];
  if (level.levelInRank >= 11) result.add(LevelModifier.npcTough);
  if (level.levelInRank >= 21) result.add(LevelModifier.npcFierce);
  if (level.levelInRank >= 31) result.add(LevelModifier.npcSwift);
  if (level.levelInRank >= 41) result.add(LevelModifier.npcLegion);
  if (level.isRankBoss) {
    result.addAll(switch (level.rank) {
      Rank.bronze => [LevelModifier.npcFierce],
      Rank.silver => [LevelModifier.noHeal, LevelModifier.fastStorm],
      Rank.gold => [LevelModifier.risingLava, LevelModifier.npcTough],
      Rank.platinum => [LevelModifier.mirrorMatch, LevelModifier.noShield],
      Rank.diamond => [LevelModifier.darkness, LevelModifier.noPowers],
      Rank.masters => [LevelModifier.lowGravity, LevelModifier.fastStorm, LevelModifier.npcSwift],
      Rank.grandMasters => LevelModifier.values,
    });
  }
  return result.toSet().toList();
}

enum LevelGrade { none, d, c, b, a, s, ss }

extension LevelGradeData on LevelGrade {
  String get label => switch (this) {
        LevelGrade.none => '—',
        LevelGrade.d => 'D',
        LevelGrade.c => 'C',
        LevelGrade.b => 'B',
        LevelGrade.a => 'A',
        LevelGrade.s => 'S',
        LevelGrade.ss => 'SS',
      };
  String get title => switch (this) {
        LevelGrade.none => 'Not cleared',
        LevelGrade.d => 'Cleared',
        LevelGrade.c => 'Fair',
        LevelGrade.b => 'Good',
        LevelGrade.a => 'Excellent',
        LevelGrade.s => 'Master',
        LevelGrade.ss => 'Flawless',
      };
  int get baseReward => switch (this) {
        LevelGrade.none => 0,
        LevelGrade.d => 40,
        LevelGrade.c => 80,
        LevelGrade.b => 150,
        LevelGrade.a => 250,
        LevelGrade.s => 450,
        LevelGrade.ss => 800,
      };
  double get rewardMultiplier => switch (this) {
        LevelGrade.none => 0,
        LevelGrade.d => 1,
        LevelGrade.c => 1.2,
        LevelGrade.b => 1.5,
        LevelGrade.a => 2,
        LevelGrade.s => 3,
        LevelGrade.ss => 5,
      };
  int get score => index;
  Color get color => switch (this) {
        LevelGrade.none => const Color(0xFFA8A29E),
        LevelGrade.d => const Color(0xFF78716C),
        LevelGrade.c => const Color(0xFFA16207),
        LevelGrade.b => const Color(0xFF65A30D),
        LevelGrade.a => const Color(0xFF0891B2),
        LevelGrade.s => const Color(0xFF7E22CE),
        LevelGrade.ss => const Color(0xFFD97706),
      };
}

LevelGrade gradeForTime(int seconds) {
  if (seconds < 50) return LevelGrade.ss;
  if (seconds < 70) return LevelGrade.s;
  if (seconds < 90) return LevelGrade.a;
  if (seconds < 120) return LevelGrade.b;
  if (seconds < 150) return LevelGrade.c;
  return LevelGrade.d;
}

LevelGrade gradeForHealth(double hpPercent) {
  if (hpPercent >= 1) return LevelGrade.ss;
  if (hpPercent >= 0.8) return LevelGrade.s;
  if (hpPercent >= 0.6) return LevelGrade.a;
  if (hpPercent >= 0.4) return LevelGrade.b;
  if (hpPercent >= 0.2) return LevelGrade.c;
  return LevelGrade.d;
}

LevelGrade gradeForDamage(int damageTaken) {
  if (damageTaken <= 0) return LevelGrade.ss;
  if (damageTaken < 15) return LevelGrade.s;
  if (damageTaken < 30) return LevelGrade.a;
  if (damageTaken < 60) return LevelGrade.b;
  if (damageTaken < 100) return LevelGrade.c;
  return LevelGrade.d;
}

LevelGrade finalGradeFor({required int seconds, required double hpPercent, required int damageTaken}) {
  final scores = [gradeForTime(seconds), gradeForHealth(hpPercent), gradeForDamage(damageTaken)];
  return scores.reduce((lowest, next) => next.score < lowest.score ? next : lowest);
}

enum ChimeraType { gryphonPrime, basilisk, ravager, wyvern, deathroll, rannsChimera, omegaChimera }

extension ChimeraTypeData on ChimeraType {
  String get title => switch (this) {
        ChimeraType.gryphonPrime => 'Gryphon Prime',
        ChimeraType.basilisk => 'Basilisk',
        ChimeraType.ravager => 'Ravager',
        ChimeraType.wyvern => 'Wyvern',
        ChimeraType.deathroll => 'Deathroll',
        ChimeraType.rannsChimera => 'Rann’s Chimera',
        ChimeraType.omegaChimera => 'Omega Chimera',
      };
  String get emoji => switch (this) {
        ChimeraType.gryphonPrime => '🦁🦅',
        ChimeraType.basilisk => '🐉🐍',
        ChimeraType.ravager => '🐗🦁',
        ChimeraType.wyvern => '🦅🐉',
        ChimeraType.deathroll => '🐍🐗',
        ChimeraType.rannsChimera => '🦁🐗🦅',
        ChimeraType.omegaChimera => '🐲',
      };
  int get hp => switch (this) {
        ChimeraType.gryphonPrime => 800,
        ChimeraType.basilisk => 900,
        ChimeraType.ravager => 1200,
        ChimeraType.wyvern => 700,
        ChimeraType.deathroll => 1000,
        ChimeraType.rannsChimera => 1800,
        ChimeraType.omegaChimera => 3000,
      };
  double get difficulty => switch (this) {
        ChimeraType.gryphonPrime => 3.5,
        ChimeraType.basilisk => 4,
        ChimeraType.ravager => 4.5,
        ChimeraType.wyvern => 4,
        ChimeraType.deathroll => 4.5,
        ChimeraType.rannsChimera => 6,
        ChimeraType.omegaChimera => 8,
      };
  String get ability => switch (this) {
        ChimeraType.gryphonPrime => 'Dive strike · Shockwave',
        ChimeraType.basilisk => 'Poison breath · Petrify',
        ChimeraType.ravager => 'Charge · Roar',
        ChimeraType.wyvern => 'Fireballs · Sky dive',
        ChimeraType.deathroll => 'Venom aura · Roll',
        ChimeraType.rannsChimera => 'Full creature arsenal',
        ChimeraType.omegaChimera => 'Reality shift · All abilities',
      };
  Color get color => switch (this) {
        ChimeraType.gryphonPrime => const Color(0xFFB86E45),
        ChimeraType.basilisk => const Color(0xFF789366),
        ChimeraType.ravager => const Color(0xFF8E6650),
        ChimeraType.wyvern => const Color(0xFF65828C),
        ChimeraType.deathroll => const Color(0xFF807D49),
        ChimeraType.rannsChimera => const Color(0xFFAE8351),
        ChimeraType.omegaChimera => const Color(0xFF9B8575),
      };
  String get arena => switch (this) {
        ChimeraType.gryphonPrime => 'Highwind Peak',
        ChimeraType.basilisk => 'Serpent’s Hollow',
        ChimeraType.ravager => 'Ashen Basin',
        ChimeraType.wyvern => 'Cloudbreak Ridge',
        ChimeraType.deathroll => 'Venom Marsh',
        ChimeraType.rannsChimera => 'Throne of Rann',
        ChimeraType.omegaChimera => 'The First Arena',
      };
}

class BattleOutcome {
  const BattleOutcome({
    required this.won,
    required this.durationSeconds,
    required this.remainingHp,
    required this.maxHp,
    required this.damageTaken,
  });

  final bool won;
  final int durationSeconds;
  final double remainingHp;
  final double maxHp;
  final int damageTaken;
  double get hpPercent => maxHp <= 0 ? 0 : remainingHp / maxHp;
}

class RewardBreakdown {
  const RewardBreakdown({
    required this.grade,
    required this.baseCoins,
    required this.multiplier,
    required this.firstClear,
    required this.bonuses,
    required this.total,
    required this.timeGrade,
    required this.healthGrade,
    required this.damageGrade,
  });

  final LevelGrade grade;
  final int baseCoins;
  final double multiplier;
  final bool firstClear;
  final Map<String, int> bonuses;
  final int total;
  final LevelGrade timeGrade;
  final LevelGrade healthGrade;
  final LevelGrade damageGrade;
}
