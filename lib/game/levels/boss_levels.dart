import '../creature.dart';
import '../level_grade.dart';
import '../rank.dart';
import 'level_modifier.dart';

/// Abilities a rank boss can use during a fight.
enum BossAbility {
  melee,
  fireball,
  shockwave,
  dive,
  summonSkyhawks,
  charge,
  poisonBite,
}

/// One health-phase of a boss.
class BossPhase {
  const BossPhase({
    required this.index,
    required this.label,
    required this.hpThreshold,
    required this.damageMultiplier,
    required this.speedMultiplier,
    required this.abilities,
    this.summonInterval = 15,
  });

  final int index;
  final String label;

  /// The phase is active while `hpPercent > hpThreshold`.
  final double hpThreshold;
  final double damageMultiplier;
  final double speedMultiplier;
  final Set<BossAbility> abilities;
  final double summonInterval;

  bool has(BossAbility ability) => abilities.contains(ability);
}

/// Behaviour profile shared by rank bosses, Rann's Avatar and chimera adds.
class BossProfile {
  const BossProfile({
    required this.name,
    required this.phases,
    this.isTwin = false,
    this.cloneCount = 0,
    this.cloneHp = 0,
  });

  final String name;
  final List<BossPhase> phases;

  /// Twin guardians spawn two bosses at once.
  final bool isTwin;

  /// Permanent clones that spawn with the boss (Crystal Queen).
  final int cloneCount;
  final double cloneHp;

  BossPhase phaseFor(double hpPercent) {
    for (final BossPhase phase in phases) {
      if (hpPercent > phase.hpThreshold) {
        return phase;
      }
    }
    return phases.last;
  }
}

/// Handcrafted definition of a rank boss (levels 50, 100, ... 350).
class BossLevelDef {
  const BossLevelDef({
    required this.levelNumber,
    required this.rank,
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.baseCreature,
    required this.hp,
    required this.adds,
    required this.addCount,
    required this.addsElite,
    required this.mapId,
    required this.modifiers,
    required this.coinReward,
    required this.profile,
    this.unlocksRank,
    this.titleReward,
    this.permanentCoinMultiplier = 1.0,
  });

  final int levelNumber;
  final Rank rank;
  final String name;
  final String emoji;
  final String subtitle;
  final CreatureType baseCreature;
  final double hp;
  final List<CreatureType> adds;
  final int addCount;
  final bool addsElite;
  final String mapId;
  final List<LevelModifier> modifiers;
  final int coinReward;
  final BossProfile profile;

  /// Rank unlocked by beating this boss.
  final Rank? unlocksRank;

  /// Title granted on the first kill.
  final String? titleReward;

  /// Permanent coin multiplier unlocked by the final boss.
  final double permanentCoinMultiplier;
}

/// The seven handcrafted rank bosses - one per rank, every 50 levels.
class BossLevels {
  const BossLevels._();

  static const BossProfile alphaGriffinProfile = BossProfile(
    name: 'Alpha Griffin',
    phases: <BossPhase>[
      BossPhase(
        index: 0,
        label: 'Prowling',
        hpThreshold: 0.5,
        damageMultiplier: 1.0,
        speedMultiplier: 1.0,
        abilities: <BossAbility>{BossAbility.melee, BossAbility.dive},
      ),
      BossPhase(
        index: 1,
        label: 'Raging',
        hpThreshold: -1,
        damageMultiplier: 1.3,
        speedMultiplier: 1.15,
        abilities: <BossAbility>{BossAbility.melee, BossAbility.dive, BossAbility.shockwave},
      ),
    ],
  );

  static const BossProfile frostTyrantProfile = BossProfile(
    name: 'Frost Tyrant',
    phases: <BossPhase>[
      BossPhase(
        index: 0,
        label: 'Frozen Calm',
        hpThreshold: 0.5,
        damageMultiplier: 1.0,
        speedMultiplier: 1.05,
        abilities: <BossAbility>{BossAbility.fireball, BossAbility.melee},
      ),
      BossPhase(
        index: 1,
        label: 'Glacier Wrath',
        hpThreshold: -1,
        damageMultiplier: 1.35,
        speedMultiplier: 1.2,
        abilities: <BossAbility>{BossAbility.fireball, BossAbility.shockwave, BossAbility.melee},
      ),
    ],
  );

  static const BossProfile emberlordProfile = BossProfile(
    name: 'Emberlord',
    phases: <BossPhase>[
      BossPhase(
        index: 0,
        label: 'Smouldering',
        hpThreshold: 0.66,
        damageMultiplier: 1.0,
        speedMultiplier: 1.0,
        abilities: <BossAbility>{BossAbility.charge, BossAbility.melee},
      ),
      BossPhase(
        index: 1,
        label: 'Burning',
        hpThreshold: 0.33,
        damageMultiplier: 1.25,
        speedMultiplier: 1.15,
        abilities: <BossAbility>{BossAbility.charge, BossAbility.shockwave, BossAbility.melee},
      ),
      BossPhase(
        index: 2,
        label: 'Molten Core',
        hpThreshold: -1,
        damageMultiplier: 1.5,
        speedMultiplier: 1.3,
        abilities: <BossAbility>{
          BossAbility.charge,
          BossAbility.shockwave,
          BossAbility.fireball,
          BossAbility.melee,
        },
      ),
    ],
  );

  static const BossProfile templeGuardianProfile = BossProfile(
    name: 'Temple Guardian',
    isTwin: true,
    phases: <BossPhase>[
      BossPhase(
        index: 0,
        label: 'Vigil',
        hpThreshold: 0.5,
        damageMultiplier: 1.0,
        speedMultiplier: 1.0,
        abilities: <BossAbility>{BossAbility.melee, BossAbility.shockwave},
      ),
      BossPhase(
        index: 1,
        label: 'Judgement',
        hpThreshold: -1,
        damageMultiplier: 1.3,
        speedMultiplier: 1.1,
        abilities: <BossAbility>{BossAbility.melee, BossAbility.shockwave, BossAbility.dive},
      ),
    ],
  );

  static const BossProfile crystalQueenProfile = BossProfile(
    name: 'Crystal Queen',
    cloneCount: 6,
    cloneHp: 150,
    phases: <BossPhase>[
      BossPhase(
        index: 0,
        label: 'Refracted',
        hpThreshold: 0.6,
        damageMultiplier: 1.0,
        speedMultiplier: 1.0,
        abilities: <BossAbility>{BossAbility.poisonBite, BossAbility.melee},
      ),
      BossPhase(
        index: 1,
        label: 'Shattering',
        hpThreshold: -1,
        damageMultiplier: 1.4,
        speedMultiplier: 1.25,
        abilities: <BossAbility>{BossAbility.poisonBite, BossAbility.shockwave, BossAbility.melee},
      ),
    ],
  );

  static const BossProfile stormlordProfile = BossProfile(
    name: 'Stormlord',
    phases: <BossPhase>[
      BossPhase(
        index: 0,
        label: 'Overcast',
        hpThreshold: 0.66,
        damageMultiplier: 1.0,
        speedMultiplier: 1.1,
        abilities: <BossAbility>{BossAbility.fireball, BossAbility.melee},
      ),
      BossPhase(
        index: 1,
        label: 'Thunderhead',
        hpThreshold: 0.33,
        damageMultiplier: 1.3,
        speedMultiplier: 1.25,
        abilities: <BossAbility>{
          BossAbility.fireball,
          BossAbility.shockwave,
          BossAbility.summonSkyhawks,
          BossAbility.melee,
        },
      ),
      BossPhase(
        index: 2,
        label: 'Tempest',
        hpThreshold: -1,
        damageMultiplier: 1.6,
        speedMultiplier: 1.4,
        abilities: <BossAbility>{
          BossAbility.fireball,
          BossAbility.shockwave,
          BossAbility.summonSkyhawks,
          BossAbility.dive,
          BossAbility.melee,
        },
      ),
    ],
  );

  static const BossProfile rannAvatarProfile = BossProfile(
    name: "Rann's Avatar",
    cloneCount: 0,
    phases: <BossPhase>[
      BossPhase(
        index: 0,
        label: 'Griffin Aspect',
        hpThreshold: 0.66,
        damageMultiplier: 1.0,
        speedMultiplier: 1.1,
        abilities: <BossAbility>{BossAbility.dive, BossAbility.melee},
      ),
      BossPhase(
        index: 1,
        label: 'Drake Aspect',
        hpThreshold: 0.33,
        damageMultiplier: 1.4,
        speedMultiplier: 1.2,
        abilities: <BossAbility>{
          BossAbility.fireball,
          BossAbility.summonSkyhawks,
          BossAbility.melee,
        },
        summonInterval: 15,
      ),
      BossPhase(
        index: 2,
        label: 'Rann Incarnate',
        hpThreshold: -1,
        damageMultiplier: 1.8,
        speedMultiplier: 1.35,
        abilities: <BossAbility>{
          BossAbility.fireball,
          BossAbility.shockwave,
          BossAbility.dive,
          BossAbility.charge,
          BossAbility.summonSkyhawks,
          BossAbility.melee,
        },
      ),
    ],
  );

  static const List<BossLevelDef> all = <BossLevelDef>[
    BossLevelDef(
      levelNumber: 50,
      rank: Rank.bronze,
      name: 'Alpha Griffin',
      emoji: '🦅',
      subtitle: 'The pit-mother of the Dust Bowl.',
      baseCreature: CreatureType.griffin,
      hp: 400,
      adds: <CreatureType>[CreatureType.griffin],
      addCount: 6,
      addsElite: false,
      mapId: 'dust_pit',
      modifiers: <LevelModifier>[LevelModifier.npcFierce],
      coinReward: 2000,
      unlocksRank: Rank.silver,
      profile: alphaGriffinProfile,
    ),
    BossLevelDef(
      levelNumber: 100,
      rank: Rank.silver,
      name: 'Frost Tyrant',
      emoji: '🐉',
      subtitle: 'The ice remembers every warrior it kept.',
      baseCreature: CreatureType.drake,
      hp: 500,
      adds: <CreatureType>[CreatureType.drake, CreatureType.skyhawk],
      addCount: 8,
      addsElite: false,
      mapId: 'frost_hollow',
      modifiers: <LevelModifier>[LevelModifier.noHeal, LevelModifier.fastStorm],
      coinReward: 4000,
      unlocksRank: Rank.gold,
      profile: frostTyrantProfile,
    ),
    BossLevelDef(
      levelNumber: 150,
      rank: Rank.gold,
      name: 'Emberlord',
      emoji: '🐗',
      subtitle: 'Born in the forge, fed on the fallen.',
      baseCreature: CreatureType.ironboar,
      hp: 700,
      adds: <CreatureType>[CreatureType.ironboar, CreatureType.venomtail],
      addCount: 8,
      addsElite: false,
      mapId: 'ember_forge',
      modifiers: <LevelModifier>[LevelModifier.risingLava, LevelModifier.npcTough],
      coinReward: 7000,
      unlocksRank: Rank.platinum,
      profile: emberlordProfile,
    ),
    BossLevelDef(
      levelNumber: 200,
      rank: Rank.platinum,
      name: 'Temple Guardian',
      emoji: '💠',
      subtitle: 'Two statues. One verdict.',
      baseCreature: CreatureType.griffin,
      hp: 500,
      adds: <CreatureType>[
        CreatureType.griffin,
        CreatureType.drake,
        CreatureType.ironboar,
        CreatureType.venomtail,
      ],
      addCount: 8,
      addsElite: false,
      mapId: 'jade_temple',
      modifiers: <LevelModifier>[LevelModifier.mirrorMatch, LevelModifier.noShield],
      coinReward: 11000,
      unlocksRank: Rank.diamond,
      profile: templeGuardianProfile,
    ),
    BossLevelDef(
      levelNumber: 250,
      rank: Rank.diamond,
      name: 'Crystal Queen',
      emoji: '💎',
      subtitle: 'Break the mirror, break the crown.',
      baseCreature: CreatureType.venomtail,
      hp: 500,
      adds: <CreatureType>[
        CreatureType.skyhawk,
        CreatureType.drake,
        CreatureType.venomtail,
      ],
      addCount: 6,
      addsElite: true,
      mapId: 'crystal_cavern',
      modifiers: <LevelModifier>[LevelModifier.darkness, LevelModifier.noPowers],
      coinReward: 16000,
      unlocksRank: Rank.masters,
      profile: crystalQueenProfile,
    ),
    BossLevelDef(
      levelNumber: 300,
      rank: Rank.masters,
      name: 'Stormlord',
      emoji: '🌩️',
      subtitle: 'He does not summon the storm. He is the storm.',
      baseCreature: CreatureType.drake,
      hp: 900,
      adds: <CreatureType>[
        CreatureType.skyhawk,
        CreatureType.drake,
        CreatureType.griffin,
        CreatureType.ironboar,
      ],
      addCount: 10,
      addsElite: true,
      mapId: 'storm_citadel',
      modifiers: <LevelModifier>[
        LevelModifier.lowGravity,
        LevelModifier.fastStorm,
        LevelModifier.npcSwift,
      ],
      coinReward: 22000,
      unlocksRank: Rank.grandMasters,
      profile: stormlordProfile,
    ),
    BossLevelDef(
      levelNumber: 350,
      rank: Rank.grandMasters,
      name: "Rann's Avatar",
      emoji: '👑',
      subtitle: 'The arena itself stands up to fight you.',
      baseCreature: CreatureType.griffin,
      hp: 1500,
      adds: <CreatureType>[
        CreatureType.griffin,
        CreatureType.drake,
        CreatureType.skyhawk,
        CreatureType.ironboar,
        CreatureType.venomtail,
      ],
      addCount: 12,
      addsElite: true,
      mapId: 'throne_of_rann',
      modifiers: <LevelModifier>[
        LevelModifier.npcTough,
        LevelModifier.npcFierce,
        LevelModifier.npcSwift,
        LevelModifier.npcElite,
        LevelModifier.fastStorm,
        LevelModifier.lowGravity,
        LevelModifier.noHeal,
        LevelModifier.mirrorMatch,
      ],
      coinReward: 50000,
      titleReward: 'Rannslayer',
      permanentCoinMultiplier: 1.5,
      profile: rannAvatarProfile,
    ),
  ];

  static BossLevelDef? forLevel(int levelNumber) {
    for (final BossLevelDef boss in all) {
      if (boss.levelNumber == levelNumber) {
        return boss;
      }
    }
    return null;
  }

  /// Grade required to count a boss as "mastered" (used by the profile screen).
  static LevelGrade masteryGradeFor(int levelNumber) =>
      levelNumber >= 350 ? LevelGrade.s : LevelGrade.a;
}
