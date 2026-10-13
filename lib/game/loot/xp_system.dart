import 'dart:math' as math;

import '../store_state.dart';

/// Reward granted when the warrior reaches a new level.
class LevelUpInfo {
  const LevelUpInfo({
    required this.level,
    required this.coinReward,
    required this.fragmentReward,
    this.booster,
    this.cosmetic,
    this.title,
  });

  final int level;
  final int coinReward;
  final int fragmentReward;
  final BoosterKind? booster;
  final String? cosmetic;
  final String? title;

  String get summary {
    final List<String> parts = <String>['+$coinReward 🪙'];
    if (fragmentReward > 0) {
      parts.add('+$fragmentReward 🗡️');
    }
    if (booster != null) {
      parts.add('${booster!.icon} ${booster!.label}');
    }
    if (cosmetic != null) {
      parts.add('🎨 $cosmetic');
    }
    if (title != null) {
      parts.add('🏷️ $title');
    }
    return parts.join(' • ');
  }
}

/// Player level maths.
///
/// Level N requires `100 * N^1.5` experience, cumulative across the ladder.
/// Levels run from 1 to 100. Rewards: +50 coins per level, +1 weapon fragment
/// every 10 levels, a random booster every 25 levels, an exclusive cosmetic at
/// level 50 and the "Rannslayer Prime" title at level 100.
class XpSystem {
  const XpSystem._();

  static const int maxLevel = 100;

  /// XP needed to walk from [level] to [level] + 1.
  static int xpForNextLevel(int level) {
    final int clamped = level.clamp(1, maxLevel);
    return (100 * _pow(clamped, 1.5)).round();
  }

  /// Total XP required to reach [level] from level 1.
  static int cumulativeXpForLevel(int level) {
    int total = 0;
    for (int i = 1; i < level.clamp(1, maxLevel); i++) {
      total += xpForNextLevel(i);
    }
    return total;
  }

  /// Resolves the level for a lifetime-XP total.
  static int levelForXp(int xp) {
    int level = 1;
    int remaining = xp;
    while (level < maxLevel) {
      final int need = xpForNextLevel(level);
      if (remaining < need) {
        break;
      }
      remaining -= need;
      level++;
    }
    return level;
  }

  /// XP earned inside the current level.
  static int xpIntoLevel(int xp) {
    return xp - cumulativeXpForLevel(levelForXp(xp));
  }

  /// XP required for the current level (0 at max level).
  static int xpForCurrentLevel(int xp) {
    final int level = levelForXp(xp);
    return level >= maxLevel ? 0 : xpForNextLevel(level);
  }

  static double progressFor(int xp) {
    final int need = xpForCurrentLevel(xp);
    if (need <= 0) {
      return 1;
    }
    return (xpIntoLevel(xp) / need).clamp(0.0, 1.0);
  }

  /// Every reward handed out between two levels (exclusive of [fromLevel]).
  static List<LevelUpInfo> levelUpsBetween(int fromLevel, int toLevel) {
    final List<LevelUpInfo> rewards = <LevelUpInfo>[];
    for (int level = fromLevel + 1; level <= toLevel; level++) {
      rewards.add(
        LevelUpInfo(
          level: level,
          coinReward: 50,
          fragmentReward: level % 10 == 0 ? 1 : 0,
          booster: level % 25 == 0
              ? BoosterKind.values[(level ~/ 25 - 1) % BoosterKind.values.length]
              : null,
          cosmetic: level == 50 ? 'Rannslayer Sigil' : null,
          title: level == 100 ? 'Rannslayer Prime' : null,
        ),
      );
    }
    return rewards;
  }

  /// n^1.5 for the XP curve.
  static double _pow(num value, double exponent) => math.pow(value, exponent).toDouble();
}
