import 'level_grade.dart';
import 'levels/game_level.dart';
import 'rank.dart';

/// A single line of the reward breakdown shown in the result modal.
class RewardLine {
  const RewardLine(this.label, this.coins, {this.icon = '🪙'});

  final String label;
  final int coins;
  final String icon;
}

/// Immutable outcome of a finished battle.
///
/// Coin maths follow the specification:
///  * level reward  = (40 + levelInRank * 8) * gradeMultiplier * rankMultiplier
///    * (firstClear ? 1.5 : 1.0)
///  * bonus lines   = first clear +300, new best +200, no damage +100,
///    sub-60s +75, daily first win +100, loss consolation +30
///  * elite reward  = chimera coin reward * grade multiplier
class BattleResult {
  const BattleResult({
    required this.win,
    required this.grade,
    required this.breakdown,
    required this.rewardLines,
    required this.timeSeconds,
    required this.hpPercent,
    required this.damageTaken,
    required this.kills,
    required this.firstClear,
    required this.newBest,
    required this.contextLabel,
    required this.isElite,
    required this.levelNumber,
    required this.rank,
    this.eliteTrialIndex = -1,
  });

  final bool win;
  final LevelGrade grade;
  final GradeBreakdown breakdown;
  final List<RewardLine> rewardLines;
  final double timeSeconds;
  final double hpPercent;
  final double damageTaken;
  final int kills;
  final bool firstClear;
  final bool newBest;

  /// Human readable context: "Bronze • Level 7" or "Chimera Trial • Basilisk".
  final String contextLabel;
  final bool isElite;
  final int levelNumber;
  final Rank rank;
  final int eliteTrialIndex;

  /// Total coins awarded by this battle.
  int get coins {
    int total = 0;
    for (final RewardLine line in rewardLines) {
      total += line.coins;
    }
    return total;
  }

  bool get flawless => grade == LevelGrade.ss;

  /// Builds a campaign victory result.
  factory BattleResult.campaignWin({
    required GameLevel level,
    required GradeBreakdown breakdown,
    required double timeSeconds,
    required double hpPercent,
    required double damageTaken,
    required int kills,
    required bool firstClear,
    required bool newBest,
    required bool dailyFirstWin,
  }) {
    final LevelGrade grade = breakdown.finalGrade;
    final int levelInRank = level.levelInRank;
    final int base = 40 + levelInRank * 8;
    final double rankMultiplier = level.rank.coinMultiplier;
    final double clearMultiplier = firstClear ? 1.5 : 1.0;
    final int levelReward = (base * grade.coinMultiplier * rankMultiplier * clearMultiplier).round();

    final List<RewardLine> lines = <RewardLine>[
      RewardLine('Level reward (${grade.label})', levelReward, icon: '⚔️'),
    ];
    if (firstClear) {
      lines.add(const RewardLine('First clear bonus', 300, icon: '🏅'));
    }
    if (newBest) {
      lines.add(const RewardLine('New personal best', 200, icon: '📈'));
    }
    if (damageTaken <= 0) {
      lines.add(const RewardLine('Untouched bonus', 100, icon: '🛡️'));
    }
    if (timeSeconds < 60) {
      lines.add(const RewardLine('Swift victory bonus', 75, icon: '⚡'));
    }
    if (dailyFirstWin) {
      lines.add(const RewardLine('Daily first win', 100, icon: '☀️'));
    }

    return BattleResult(
      win: true,
      grade: grade,
      breakdown: breakdown,
      rewardLines: lines,
      timeSeconds: timeSeconds,
      hpPercent: hpPercent,
      damageTaken: damageTaken,
      kills: kills,
      firstClear: firstClear,
      newBest: newBest,
      contextLabel: '${level.rank.label} • Level ${level.number}',
      isElite: false,
      levelNumber: level.number,
      rank: level.rank,
    );
  }

  /// Builds a campaign defeat result (small consolation purse).
  factory BattleResult.campaignLoss({
    required GameLevel level,
    required GradeBreakdown breakdown,
    required double timeSeconds,
    required double hpPercent,
    required double damageTaken,
    required int kills,
  }) {
    return BattleResult(
      win: false,
      grade: LevelGrade.none,
      breakdown: breakdown,
      rewardLines: const <RewardLine>[RewardLine('Warrior\'s consolation', 30, icon: '🕯️')],
      timeSeconds: timeSeconds,
      hpPercent: hpPercent,
      damageTaken: damageTaken,
      kills: kills,
      firstClear: false,
      newBest: false,
      contextLabel: '${level.rank.label} • Level ${level.number}',
      isElite: false,
      levelNumber: level.number,
      rank: level.rank,
    );
  }

  /// Builds an elite trial result.
  factory BattleResult.elite({
    required int trialIndex,
    required String chimeraName,
    required GradeBreakdown breakdown,
    required double timeSeconds,
    required double hpPercent,
    required double damageTaken,
    required int kills,
    required bool firstClear,
    required bool newBest,
    required int baseCoinReward,
    required int cappedGradeIndex,
  }) {
    LevelGrade grade = breakdown.finalGrade;
    // Assist mode caps the grade at B (index 3).
    if (grade.index < cappedGradeIndex) {
      grade = LevelGrade.values[cappedGradeIndex];
    }
    final int reward = (baseCoinReward * grade.coinMultiplier * (firstClear ? 1.5 : 1.0)).round();
    final List<RewardLine> lines = <RewardLine>[
      RewardLine('$chimeraName bounty', reward, icon: '🐲'),
    ];
    if (firstClear) {
      lines.add(const RewardLine('First trial clear', 300, icon: '🏅'));
    }
    if (damageTaken <= 0) {
      lines.add(const RewardLine('Untouched bonus', 250, icon: '🛡️'));
    }
    if (timeSeconds < 90) {
      lines.add(const RewardLine('Swift hunt bonus', 150, icon: '⚡'));
    }

    return BattleResult(
      win: true,
      grade: grade,
      breakdown: breakdown,
      rewardLines: lines,
      timeSeconds: timeSeconds,
      hpPercent: hpPercent,
      damageTaken: damageTaken,
      kills: kills,
      firstClear: firstClear,
      newBest: newBest,
      contextLabel: 'Chimera Trial • $chimeraName',
      isElite: true,
      levelNumber: 0,
      rank: Rank.grandMasters,
      eliteTrialIndex: trialIndex,
    );
  }

  /// Builds an elite trial defeat result.
  factory BattleResult.eliteLoss({
    required int trialIndex,
    required String chimeraName,
    required GradeBreakdown breakdown,
    required double timeSeconds,
    required double hpPercent,
    required double damageTaken,
    required int kills,
  }) {
    return BattleResult(
      win: false,
      grade: LevelGrade.none,
      breakdown: breakdown,
      rewardLines: const <RewardLine>[RewardLine('Trial consolation', 40, icon: '🕯️')],
      timeSeconds: timeSeconds,
      hpPercent: hpPercent,
      damageTaken: damageTaken,
      kills: kills,
      firstClear: false,
      newBest: false,
      contextLabel: 'Chimera Trial • $chimeraName',
      isElite: true,
      levelNumber: 0,
      rank: Rank.grandMasters,
      eliteTrialIndex: trialIndex,
    );
  }

  /// XP granted for the battle (used by [StoreState]).
  int get xpReward {
    if (isElite) {
      if (!win) {
        return 150;
      }
      return (500 * grade.coinMultiplier).round();
    }
    if (!win) {
      return 20;
    }
    return (50 * grade.coinMultiplier).round();
  }
}
