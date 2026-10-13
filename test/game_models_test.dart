import 'package:flutter_test/flutter_test.dart';
import 'package:battle_of_sword_master/domain/game_models.dart';

void main() {
  group('campaign catalog', () {
    test('contains seven ranks and maps to 350 levels', () {
      expect(Rank.values.length, 7);
      expect(arenaMaps.length, 7);
      expect(GameLevel(rank: Rank.grandMasters, levelInRank: 50).globalLevel, 350);
    });

    test('creature roster expands with campaign phases', () {
      expect(creaturesFor(const GameLevel(rank: Rank.bronze, levelInRank: 5)).length, 1);
      expect(creaturesFor(const GameLevel(rank: Rank.bronze, levelInRank: 15)).length, 2);
      expect(creaturesFor(const GameLevel(rank: Rank.bronze, levelInRank: 25)).length, 3);
      expect(creaturesFor(const GameLevel(rank: Rank.bronze, levelInRank: 45)).length, 5);
    });

    test('the lowest performance category determines the grade', () {
      expect(finalGradeFor(seconds: 48, hpPercent: 0.9, damageTaken: 0), LevelGrade.s);
      expect(finalGradeFor(seconds: 65, hpPercent: 0.35, damageTaken: 22), LevelGrade.c);
      expect(finalGradeFor(seconds: 160, hpPercent: 0.1, damageTaken: 120), LevelGrade.d);
    });
  });

  group('Forge tiers', () {
    test('weapon merge order has six tiers with expected stats', () {
      expect(WeaponTier.values.length, 6);
      expect(WeaponTierData.fromLevel(4), WeaponTier.trident);
      expect(WeaponTier.mythic.damage, 120);
      expect(WeaponTier.axe.reach, 75);
    });

    test('rank thresholds and armor stats are data-driven', () {
      expect(Rank.grandMasters.unlockWins, 60);
      expect(Rank.platinum.rewardRankMultiplier, 3);
      expect(ArmorRank.epic.hpBonus, 100);
      expect(ArmorRank.advanced.defense, 0.12);
    });
  });
}
