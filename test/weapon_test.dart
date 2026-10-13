import 'package:flutter_test/flutter_test.dart';
import 'package:blade_brawl/game/weapon.dart';

void main() {
  test('weapon tiers increase damage and reach across the merge chain', () {
    final tiers = WeaponTier.values;
    expect(tiers, hasLength(6));
    for (var i = 1; i < tiers.length; i++) {
      expect(tiers[i].level, tiers[i - 1].level + 1);
      expect(tiers[i].damage, greaterThan(tiers[i - 1].damage));
      expect(tiers[i].reach, greaterThan(tiers[i - 1].reach));
    }
  });

  test('mythic is the terminal merge tier', () {
    expect(WeaponTier.mythic.next, WeaponTier.mythic);
    expect(WeaponTier.dagger.next, WeaponTier.sword);
  });
}
