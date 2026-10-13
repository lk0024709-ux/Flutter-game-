import 'package:flutter_test/flutter_test.dart';

import 'package:blade_brawl/game/elite/chimera.dart';
import 'package:blade_brawl/game/level_grade.dart';
import 'package:blade_brawl/game/levels/levels_data.dart';
import 'package:blade_brawl/game/loot/chest_rarity.dart';
import 'package:blade_brawl/game/rank.dart';

void main() {
  test('campaign data contains 350 levels across seven 50-level ranks', () {
    expect(LevelsData.all, hasLength(350));
    for (final Rank rank in Rank.values) {
      expect(LevelsData.forRank(rank), hasLength(50));
    }
    expect(LevelsData.byNumber(50).isBoss, isTrue);
    expect(LevelsData.byNumber(350).rank, Rank.grandMasters);
    expect(LevelsData.byNumber(350).isBoss, isTrue);

    final Set<int> numbers = LevelsData.all.map((level) => level.number).toSet();
    expect(numbers, hasLength(350), reason: 'level numbers must be unique');
  });

  test('every rank ends on a boss level with a boss profile', () {
    for (final Rank rank in Rank.values) {
      final levels = LevelsData.forRank(rank);
      final bossLevels = levels.where((level) => level.isBoss).toList();
      expect(bossLevels, hasLength(1), reason: '${rank.label} should have one boss');
      expect(bossLevels.single.boss, isNotNull);
      expect(bossLevels.single.number, rank.lastLevel);
    }
  });

  test('all seven chimeras are distinct and combat ready', () {
    expect(ChimeraType.values, hasLength(7));
    expect(ChimeraType.values.map((type) => type.label).toSet(), hasLength(7));
    expect(ChimeraType.values.map((type) => type.arenaId).toSet(), hasLength(7));
    for (final ChimeraType type in ChimeraType.values) {
      expect(type.hp, greaterThan(0));
      expect(type.speed, greaterThan(0));
      expect(type.damage, greaterThan(0));
      expect(type.abilities, isNotEmpty);
      expect(type.defenses, isNotEmpty);
      expect(type.recommendedLevel, greaterThanOrEqualTo(60));
    }
  });

  test('every chimera trial unlocks a different elite armour', () {
    expect(EliteTrial.trials, hasLength(ChimeraType.values.length));
    final armours = EliteTrial.trials.map((trial) => trial.armorDrop).toSet();
    expect(armours, hasLength(EliteTrial.trials.length));
    for (final EliteTrial trial in EliteTrial.trials) {
      expect(trial.coinReward, greaterThan(0));
      expect(trial.xpReward, greaterThan(0));
      expect(trial.unlockAfterLevel, greaterThan(0));
    }
  });

  test('grades resolve to the correct chest tier', () {
    expect(ChestRarity.forGrade(LevelGrade.d), ChestRarity.bronze);
    expect(ChestRarity.forGrade(LevelGrade.c), ChestRarity.silver);
    expect(ChestRarity.forGrade(LevelGrade.b), ChestRarity.gold);
    expect(ChestRarity.forGrade(LevelGrade.a), ChestRarity.platinum);
    expect(ChestRarity.forGrade(LevelGrade.s), ChestRarity.diamond);
    expect(ChestRarity.forGrade(LevelGrade.ss), ChestRarity.mythic);
  });

  test('the final grade is the lowest of the three sub-grades', () {
    final GradeBreakdown breakdown = GradeCalculator.evaluate(
      timeSeconds: 45,
      hpPercent: 100,
      damageTaken: 80,
    );
    expect(breakdown.timeGrade, LevelGrade.ss);
    expect(breakdown.hpGrade, LevelGrade.ss);
    expect(breakdown.damageGrade, LevelGrade.c);
    expect(breakdown.finalGrade, LevelGrade.c);
  });
}
