import 'package:flutter_test/flutter_test.dart';

import 'package:blade_brawl/game/level_grade.dart';
import 'package:blade_brawl/game/loot/chest_rarity.dart';

/// The grading rules from the design brief:
///   * three sub-scores - clear time, health left, damage taken;
///   * the final grade is the LOWEST of the three, never an average;
///   * grade -> chest tier mapping for the victory chest.
void main() {
  group('time sub-grade', () {
    test('is SS under 50 seconds and steps down through the brackets', () {
      expect(GradeCalculator.gradeTime(12), LevelGrade.ss);
      expect(GradeCalculator.gradeTime(49.9), LevelGrade.ss);
      expect(GradeCalculator.gradeTime(50), LevelGrade.s);
      expect(GradeCalculator.gradeTime(69.9), LevelGrade.s);
      expect(GradeCalculator.gradeTime(70), LevelGrade.a);
      expect(GradeCalculator.gradeTime(90), LevelGrade.b);
      expect(GradeCalculator.gradeTime(120), LevelGrade.c);
      expect(GradeCalculator.gradeTime(150), LevelGrade.d);
      expect(GradeCalculator.gradeTime(900), LevelGrade.d);
    });
  });

  group('health sub-grade', () {
    test('only a untouched health bar earns SS', () {
      expect(GradeCalculator.gradeHp(100), LevelGrade.ss);
      expect(GradeCalculator.gradeHp(99.999), LevelGrade.ss);
      expect(GradeCalculator.gradeHp(99.9), LevelGrade.s);
      expect(GradeCalculator.gradeHp(80), LevelGrade.s);
      expect(GradeCalculator.gradeHp(60), LevelGrade.a);
      expect(GradeCalculator.gradeHp(40), LevelGrade.b);
      expect(GradeCalculator.gradeHp(20), LevelGrade.c);
      expect(GradeCalculator.gradeHp(1), LevelGrade.d);
      expect(GradeCalculator.gradeHp(0), LevelGrade.d);
    });
  });

  group('damage sub-grade', () {
    test('rewards a clean run and punishes heavy damage', () {
      expect(GradeCalculator.gradeDamage(0), LevelGrade.ss);
      expect(GradeCalculator.gradeDamage(14.9), LevelGrade.s);
      expect(GradeCalculator.gradeDamage(15), LevelGrade.a);
      expect(GradeCalculator.gradeDamage(29.9), LevelGrade.a);
      expect(GradeCalculator.gradeDamage(30), LevelGrade.b);
      expect(GradeCalculator.gradeDamage(59.9), LevelGrade.b);
      expect(GradeCalculator.gradeDamage(60), LevelGrade.c);
      expect(GradeCalculator.gradeDamage(80), LevelGrade.c);
      expect(GradeCalculator.gradeDamage(99.9), LevelGrade.c);
      expect(GradeCalculator.gradeDamage(100), LevelGrade.d);
    });
  });

  group('final grade', () {
    test('takes the lowest sub-grade, not an average', () {
      final GradeBreakdown breakdown = GradeCalculator.evaluate(
        timeSeconds: 40,
        hpPercent: 100,
        damageTaken: 80,
      );
      expect(breakdown.timeGrade, LevelGrade.ss);
      expect(breakdown.hpGrade, LevelGrade.ss);
      expect(breakdown.damageGrade, LevelGrade.c);
      expect(breakdown.finalGrade, LevelGrade.c,
          reason: 'the worst sub-grade decides the clear');
    });

    test('a slow, hurt run is graded D even with a clean kill count', () {
      final GradeBreakdown breakdown = GradeCalculator.evaluate(
        timeSeconds: 260,
        hpPercent: 12,
        damageTaken: 240,
      );
      expect(breakdown.finalGrade, LevelGrade.d);
    });

    test('perfection on all three sub-grades is the only route to SS', () {
      final GradeBreakdown flawless = GradeCalculator.evaluate(
        timeSeconds: 44,
        hpPercent: 100,
        damageTaken: 0,
      );
      expect(flawless.finalGrade, LevelGrade.ss);

      final GradeBreakdown nearly = GradeCalculator.evaluate(
        timeSeconds: 44,
        hpPercent: 100,
        damageTaken: 0.5,
      );
      expect(nearly.finalGrade, LevelGrade.s,
          reason: 'a single scratch costs the flawless badge');
    });

    test('empty breakdowns report as not cleared', () {
      expect(GradeBreakdown.empty.finalGrade, LevelGrade.none);
      expect(LevelGrade.lowest(const <LevelGrade>[]), LevelGrade.none);
    });

    test('lowest() and best() agree with the index ordering', () {
      expect(
        LevelGrade.lowest(const <LevelGrade>[LevelGrade.ss, LevelGrade.d, LevelGrade.b]),
        LevelGrade.d,
      );
      expect(LevelGrade.best(LevelGrade.b, LevelGrade.s), LevelGrade.s);
      expect(LevelGrade.best(LevelGrade.s, LevelGrade.s), LevelGrade.s);
      expect(LevelGrade.a.betterThan(LevelGrade.b), isTrue);
      expect(LevelGrade.none.betterThan(LevelGrade.ss), isFalse);
    });
  });

  group('grade persistence helpers', () {
    test('round-trips through byName and defaults to none', () {
      for (final LevelGrade grade in LevelGrade.values) {
        expect(LevelGrade.byName(grade.name), grade);
      }
      expect(LevelGrade.byName('not-a-grade'), LevelGrade.none);
      expect(LevelGrade.byName(null), LevelGrade.none);
    });

    test('every cleared grade pays a coin multiplier and none pays nothing', () {
      expect(LevelGrade.none.coinMultiplier, 0);
      for (final LevelGrade grade in LevelGrade.values) {
        if (grade == LevelGrade.none) {
          continue;
        }
        expect(grade.isCleared, isTrue);
        expect(grade.coinMultiplier, greaterThan(0));
        expect(grade.baseReward, greaterThan(0));
      }
      expect(LevelGrade.ss.coinMultiplier, greaterThan(LevelGrade.d.coinMultiplier));
    });
  });

  group('chest tier for a grade', () {
    test('maps every grade to a chest, best grade to best chest', () {
      expect(ChestRarity.forGrade(LevelGrade.ss), ChestRarity.mythic);
      expect(ChestRarity.forGrade(LevelGrade.s), ChestRarity.diamond);
      expect(ChestRarity.forGrade(LevelGrade.a), ChestRarity.platinum);
      expect(ChestRarity.forGrade(LevelGrade.b), ChestRarity.gold);
      expect(ChestRarity.forGrade(LevelGrade.c), ChestRarity.silver);
      expect(ChestRarity.forGrade(LevelGrade.d), ChestRarity.bronze);
      expect(ChestRarity.forGrade(LevelGrade.none), ChestRarity.bronze);
    });

    test('chest tiers get richer in order', () {
      int previousCoins = 0;
      int previousXp = 0;
      for (final ChestRarity rarity in ChestRarity.values) {
        expect(rarity.itemCount, greaterThan(0));
        expect(rarity.minCoins, greaterThanOrEqualTo(previousCoins));
        expect(rarity.minXp, greaterThanOrEqualTo(previousXp));
        expect(rarity.maxCoins, greaterThanOrEqualTo(rarity.minCoins));
        expect(rarity.maxXp, greaterThanOrEqualTo(rarity.minXp));
        expect(rarity.powerChance, inInclusiveRange(0, 1));
        expect(rarity.armorChance, inInclusiveRange(0, 1));
        expect(rarity.weaponChance, inInclusiveRange(0, 1));
        expect(rarity.titleChance, inInclusiveRange(0, 1));
        previousCoins = rarity.minCoins;
        previousXp = rarity.minXp;
      }
      expect(ChestRarity.values.first.averageCoins, lessThan(ChestRarity.values.last.averageCoins));
    });

    test('high tiers guarantee an elite power, low tiers do not', () {
      expect(ChestRarity.mythic.guaranteedEpics, greaterThan(0));
      expect(ChestRarity.diamond.guaranteedEpics, greaterThan(0));
      expect(ChestRarity.bronze.guaranteedEpics, 0);
    });
  });
}
