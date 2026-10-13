enum WeaponTier {
  dagger(1, '🗡️', 15, 55, 0.35, 'Dagger'),
  sword(2, '⚔️', 22, 70, 0.45, 'Sword'),
  axe(3, '🪓', 35, 75, 0.55, 'Axe'),
  trident(4, '🔱', 50, 95, 0.60, 'Trident'),
  storm(5, '⚡', 75, 110, 0.70, 'Storm Blade'),
  mythic(6, '💎', 120, 130, 0.80, 'Mythic Blade');

  const WeaponTier(this.level, this.icon, this.damage, this.reach, this.cooldown, this.label);
  final int level;
  final String icon;
  final double damage;
  final double reach;
  final double cooldown;
  final String label;
  WeaponTier get next => WeaponTier.values[index < WeaponTier.values.length - 1 ? index + 1 : index];
}
