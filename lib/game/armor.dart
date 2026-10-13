/// Passive effect granted by an armour rank.
enum ArmorEffect {
  /// Nothing beyond the flat stats.
  none,

  /// +5 HP regeneration per second while in battle.
  regen,

  /// Reflects 10% of every hit back to the attacker.
  reflect,

  /// Grants one automatic revive per battle.
  revive,
}

/// Purchasable base armours. Exactly one can be equipped at a time and the
/// starter "Cloth Tunic" (the [ArmorRank.normal] entry) is owned by default.
enum ArmorRank {
  normal(
    'Normal',
    '🥉',
    0xFF9E9E9E,
    100,
    10,
    0.05,
    0.00,
    'Basic protection',
    ArmorEffect.none,
    'Cloth Tunic',
  ),
  advanced(
    'Advanced',
    '🥈',
    0xFF66BB6A,
    350,
    25,
    0.12,
    0.03,
    '+5 HP regen / sec',
    ArmorEffect.regen,
    'Advanced Mail',
  ),
  legend(
    'Legend',
    '🥇',
    0xFFAB47BC,
    900,
    50,
    0.22,
    0.05,
    'Reflect 10% damage',
    ArmorEffect.reflect,
    'Legend Plate',
  ),
  epic(
    'Epic',
    '💎',
    0xFFC107,
    2200,
    100,
    0.35,
    0.08,
    'Revive once per battle',
    ArmorEffect.revive,
    'Epic Aegis',
  );

  const ArmorRank(
    this.label,
    this.icon,
    this.colorValue,
    this.price,
    this.hpBonus,
    this.defensePercent,
    this.speedBonusPercent,
    this.description,
    this.effect,
    this.setName,
  );

  /// Rank name shown in the store.
  final String label;

  /// Rank medal.
  final String icon;

  /// Tint used by the store card and the HUD shield chip.
  final int colorValue;

  /// Coin price (the starter armour is free / owned).
  final int price;

  /// Flat bonus health.
  final int hpBonus;

  /// Damage reduction in the 0..1 range.
  final double defensePercent;

  /// Movement speed bonus in the 0..1 range.
  final double speedBonusPercent;

  /// Short marketing line for the store card.
  final String description;

  /// Mechanical effect applied in battle.
  final ArmorEffect effect;

  /// Flavour name of the armour set.
  final String setName;

  /// Adds the armour bonuses on top of the player's base stats.
  double applyDefense(double raw) => raw * (1 - defensePercent);

  /// True when this is the free starter armour.
  bool get isStarter => this == ArmorRank.normal;

  /// The next tier up (used by the store "upgrade" hint).
  ArmorRank? get next {
    final int i = index;
    return i < ArmorRank.values.length - 1 ? ArmorRank.values[i + 1] : null;
  }

  static ArmorRank byName(String? name) {
    for (final ArmorRank rank in ArmorRank.values) {
      if (rank.name == name) {
        return rank;
      }
    }
    return ArmorRank.normal;
  }
}
