/// Weapon tiers produced by the Forge (see [ForgeState]).
///
/// Every tier carries the battle stats used by [Player] plus the special
/// behaviour flags that make higher tiers feel meaningfully different.
enum WeaponTier {
  dagger(1, '🗡️', 15, 55, 0.35, 'Dagger', 'Quick stabs with a narrow arc.'),
  sword(2, '⚔️', 22, 70, 0.45, 'Sword', 'Balanced reach and damage.'),
  axe(3, '🪓', 35, 75, 0.55, 'Axe', 'Wide cleaving arc (PI * 1.1).'),
  trident(4, '🔱', 50, 95, 0.60, 'Trident', 'Strikes up to 2 enemies per swing.'),
  storm(5, '⚡', 75, 110, 0.70, 'Storm Blade', 'Hits detonate a lightning burst.'),
  mythic(6, '💎', 120, 130, 0.80, 'Mythic Blade', 'Storm burst + 20% double hits.');

  const WeaponTier(
    this.level,
    this.icon,
    this.damage,
    this.reach,
    this.cooldown,
    this.label,
    this.perk,
  );

  /// 1-based tier level (also the merge index).
  final int level;

  /// Emoji used by the forge grid and loadout cards.
  final String icon;

  /// Base sword damage.
  final double damage;

  /// Attack reach in world units.
  final double reach;

  /// Seconds between swings.
  final double cooldown;

  /// Display name.
  final String label;

  /// Short description of the tier's special effect.
  final String perk;

  /// The next tier up, or itself when already mythic.
  WeaponTier get next {
    final int i = index;
    return i < WeaponTier.values.length - 1 ? WeaponTier.values[i + 1] : this;
  }

  bool get isMax => index == WeaponTier.values.length - 1;

  /// Axes and above sweep a wider arc.
  double get attackArc {
    if (level >= 3) {
      return 3.141592653589793 * 1.1;
    }
    return 3.141592653589793 * 0.85;
  }

  /// Trident and above can hit more than one enemy per swing.
  int get maxTargets => level >= 4 ? 2 : 1;

  /// Storm Blade and Mythic Blade detonate a lightning burst on hit.
  bool get hasStormBurst => level >= 5;

  /// Mythic Blade has a 20% chance to strike twice.
  double get doubleHitChance => level >= 6 ? 0.2 : 0.0;

  /// Radius of the storm burst AoE.
  static const double stormBurstRadius = 60;

  /// Damage dealt by the storm burst AoE.
  static const double stormBurstDamage = 15;

  /// Resolves a tier by its 1-based level.
  static WeaponTier byLevel(int level) {
    for (final WeaponTier tier in WeaponTier.values) {
      if (tier.level == level) {
        return tier;
      }
    }
    return WeaponTier.dagger;
  }
}
