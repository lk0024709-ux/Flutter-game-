import '../creature.dart';
import '../game_map.dart';
import '../rank.dart';
import 'boss_levels.dart';
import 'level_modifier.dart';

/// The six level phases inside every rank (50 levels each).
enum LevelPhase {
  onboarding('Onboarding', 'One species, gentle pressure', 1),
  duo('Two Species', 'The war for the arena begins', 2),
  twist('Twist Focus', 'The map itself joins the fight', 3),
  escalation('Escalation', 'Four species, stacked modifiers', 4),
  gauntlet('Gauntlet', 'Everything at once', 5),
  rankBoss('Rank Boss', 'Handcrafted boss encounter', 6);

  const LevelPhase(this.label, this.description, this.unlockCount);

  final String label;
  final String description;

  /// How many creature types appear in this phase.
  final int unlockCount;
}

/// One campaign level out of the 350 procedurally generated ones.
class GameLevel {
  const GameLevel({
    required this.number,
    required this.rank,
    required this.levelInRank,
    required this.map,
    required this.phase,
    required this.modifiers,
    required this.creatureMix,
    required this.npcCount,
    required this.boss,
  });

  /// 1..350.
  final int number;
  final Rank rank;

  /// 1..50 inside the rank.
  final int levelInRank;
  final GameMapDef map;
  final LevelPhase phase;
  final List<LevelModifier> modifiers;
  final List<CreatureType> creatureMix;
  final int npcCount;
  final BossLevelDef? boss;

  bool get isBoss => boss != null;

  /// Mini-boss tiles (every 10th level) are marked with a star.
  bool get isMiniBoss => !isBoss && levelInRank % 10 == 0;

  /// Difficulty inside the rank: 1.0 -> 3.0.
  double get withinRankDifficulty => 1.0 + (levelInRank / Rank.levelsPerRank) * 2.0;

  /// Overall difficulty (within-rank x rank multiplier).
  double get difficulty => withinRankDifficulty * rank.difficultyMultiplier;

  /// Coin multiplier from the ranked-map table.
  double get mapCoinMultiplier => rank.mapCoinMultiplier;

  /// Base coins from the level formula: 40 + (levelInRank * 8).
  int get baseCoins => 40 + levelInRank * 8;

  /// Reward preview shown in the level-detail modal.
  int get previewCoins => (baseCoins * rank.coinMultiplier).round() + (isBoss ? boss!.coinReward : 0);

  String get label => '${rank.label} • Level $number';

  String get shortLabel => '${rank.emoji} $number';

  /// Difficulty tag for the detail modal.
  String get difficultyTag {
    if (isBoss) {
      return 'RANK BOSS';
    }
    if (isMiniBoss) {
      return 'MINI BOSS';
    }
    if (difficulty >= 6) {
      return 'BRUTAL';
    }
    if (difficulty >= 3) {
      return 'HARD';
    }
    if (difficulty >= 1.6) {
      return 'MEDIUM';
    }
    return 'EASY';
  }
}
