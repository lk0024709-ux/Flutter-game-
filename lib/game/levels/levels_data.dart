import 'dart:math' as math;

import '../creature.dart';
import '../game_map.dart';
import '../rank.dart';
import 'boss_levels.dart';
import 'game_level.dart';
import 'level_modifier.dart';

/// Procedural generator for the 350 campaign levels (7 ranks x 50 levels).
///
/// Everything is deterministic: the same level number always produces the same
/// creature mix, modifiers and spawn budget, which keeps leaderboards (and the
/// player's memory of a level) honest.
class LevelsData {
  const LevelsData._();

  static List<GameLevel>? _cache;

  /// All 350 levels, lazily generated once.
  static List<GameLevel> get all {
    final List<GameLevel>? cached = _cache;
    if (cached != null) {
      return cached;
    }
    final List<GameLevel> levels = <GameLevel>[];
    for (int number = 1; number <= Rank.totalLevels; number++) {
      levels.add(build(number));
    }
    _cache = levels;
    return levels;
  }

  static GameLevel byNumber(int number) {
    final int index = (number - 1).clamp(0, Rank.totalLevels - 1);
    return all[index];
  }

  static List<GameLevel> forRank(Rank rank) {
    return all.sublist(rank.firstLevel - 1, rank.lastLevel);
  }

  /// Creature pool per rank - the flavour of each rank's bestiary.
  static const Map<Rank, List<CreatureType>> _pools = <Rank, List<CreatureType>>{
    Rank.bronze: <CreatureType>[CreatureType.griffin, CreatureType.skyhawk],
    Rank.silver: <CreatureType>[
      CreatureType.drake,
      CreatureType.skyhawk,
      CreatureType.griffin,
    ],
    Rank.gold: <CreatureType>[
      CreatureType.ironboar,
      CreatureType.drake,
      CreatureType.griffin,
    ],
    Rank.platinum: <CreatureType>[
      CreatureType.venomtail,
      CreatureType.skyhawk,
      CreatureType.griffin,
      CreatureType.drake,
      CreatureType.ironboar,
    ],
    Rank.diamond: <CreatureType>[
      CreatureType.skyhawk,
      CreatureType.venomtail,
      CreatureType.drake,
      CreatureType.ironboar,
      CreatureType.griffin,
    ],
    Rank.masters: <CreatureType>[
      CreatureType.drake,
      CreatureType.ironboar,
      CreatureType.skyhawk,
      CreatureType.griffin,
      CreatureType.venomtail,
    ],
    Rank.grandMasters: CreatureType.values,
  };

  static List<CreatureType> _poolFor(Rank rank) =>
      _pools[rank] ?? CreatureType.values;

  /// Level phase from the level-in-rank (L1-10, L11-20, L21-30, L31-40, L41-49, L50).
  static LevelPhase phaseFor(int levelInRank) {
    if (levelInRank >= Rank.levelsPerRank) {
      return LevelPhase.rankBoss;
    }
    if (levelInRank <= 10) {
      return LevelPhase.onboarding;
    }
    if (levelInRank <= 20) {
      return LevelPhase.duo;
    }
    if (levelInRank <= 30) {
      return LevelPhase.twist;
    }
    if (levelInRank <= 40) {
      return LevelPhase.escalation;
    }
    return LevelPhase.gauntlet;
  }

  /// The creature mix for a level, honouring the phase's species count.
  static List<CreatureType> mixFor(Rank rank, LevelPhase phase, int levelInRank) {
    final List<CreatureType> pool = _poolFor(rank);
    final int count = phase == LevelPhase.rankBoss
        ? math.min(pool.length, 5)
        : math.min(pool.length, phase.unlockCount);
    final List<CreatureType> mix = <CreatureType>[];
    for (int i = 0; i < count; i++) {
      mix.add(pool[i % pool.length]);
    }
    if (mix.isEmpty) {
      mix.add(CreatureType.griffin);
    }
    return mix;
  }

  /// Modifier stack for a level: 0 early, up to 4 in the gauntlet.
  static List<LevelModifier> modifiersFor(Rank rank, int levelInRank) {
    final BossLevelDef? boss = BossLevels.forLevel(rank.firstLevel + levelInRank - 1);
    if (boss != null) {
      return boss.modifiers;
    }
    int stack;
    if (levelInRank < 5) {
      stack = 0;
    } else if (levelInRank < 15) {
      stack = 1;
    } else if (levelInRank < 30) {
      stack = 2;
    } else if (levelInRank < 45) {
      stack = 3;
    } else {
      stack = 4;
    }
    if (stack == 0) {
      return const <LevelModifier>[];
    }

    // Deterministic shuffle: the same level always rolls the same set.
    final math.Random rng = math.Random(rank.index * 7919 + levelInRank * 131);
    final List<LevelModifier> candidates = List<LevelModifier>.from(LevelModifier.values)
      ..shuffle(rng);
    final List<LevelModifier> picked = <LevelModifier>[];
    for (final LevelModifier modifier in candidates) {
      if (picked.length >= stack) {
        break;
      }
      // Keep the specials rare: at most one per level.
      final bool specialAlreadyPicked = picked.any(
        (LevelModifier m) => m.kind == ModifierKind.special,
      );
      if (modifier.kind == ModifierKind.special && specialAlreadyPicked) {
        continue;
      }
      picked.add(modifier);
    }
    return picked;
  }

  /// Spec spawn budget: 8 + floor(levelInRank / 5) + rankIndex * 2.
  static int npcCountFor(Rank rank, int levelInRank) {
    return 8 + (levelInRank / 5).floor() + rank.index * 2;
  }

  /// Builds a single level.
  static GameLevel build(int number) {
    final Rank rank = Rank.ofLevel(number);
    final int levelInRank = number - rank.firstLevel + 1;
    final BossLevelDef? boss = BossLevels.forLevel(number);
    final GameMapDef map = Maps.forRank(rank);
    final LevelPhase phase = phaseFor(levelInRank);
    final List<CreatureType> mix = boss != null
        ? <CreatureType>{...boss.adds, boss.baseCreature}.toList()
        : mixFor(rank, phase, levelInRank);
    return GameLevel(
      number: number,
      rank: rank,
      levelInRank: levelInRank,
      map: map,
      phase: phase,
      modifiers: modifiersFor(rank, levelInRank),
      creatureMix: mix,
      npcCount: npcCountFor(rank, levelInRank),
      boss: boss,
    );
  }

  /// How many of the 350 levels the player has already cleared (with a grade).
  static int clearedCount(bool Function(GameLevel level) isCleared) {
    int total = 0;
    for (final GameLevel level in all) {
      if (isCleared(level)) {
        total++;
      }
    }
    return total;
  }
}
