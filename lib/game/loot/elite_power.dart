/// Permanent passives unlocked from elite chests.
enum ElitePowerKind {
  chimeraFury(
    'Chimera Fury',
    '⚡',
    'Every 5th landed hit deals triple damage.',
  ),
  apexPredator(
    'Apex Predator',
    '🦁',
    '+25% damage against beasts below 30% health.',
  ),
  ironWill(
    'Iron Will',
    '🛡️',
    'Survive one fatal hit with 1 HP (once per battle).',
  ),
  swiftStrike(
    'Swift Strike',
    '💨',
    '+20% attack speed, permanently.',
  ),
  regeneration(
    'Regeneration',
    '❤️',
    'Recover 2 HP every second.',
  ),
  vampirism(
    'Vampirism',
    '🩸',
    'Heal 5% of all damage you deal.',
  ),
  treasureHunter(
    'Treasure Hunter',
    '🪙',
    '+20% coins from every source.',
  ),
  stormcaller(
    'Stormcaller',
    '🌩️',
    'Every 10s lightning strikes the nearest beast.',
  ),
  phaseShift(
    'Phase Shift',
    '👻',
    '1s invulnerability when dropping below 20% HP.',
  ),
  omegaAura(
    'Omega Aura',
    '🐲',
    'Nearby enemies take 5 damage per second.',
  );

  const ElitePowerKind(this.label, this.icon, this.description);

  final String label;
  final String icon;
  final String description;

  /// Powers are handed out in this order by the loot table.
  static const List<ElitePowerKind> unlockOrder = <ElitePowerKind>[
    ElitePowerKind.regeneration,
    ElitePowerKind.swiftStrike,
    ElitePowerKind.apexPredator,
    ElitePowerKind.vampirism,
    ElitePowerKind.treasureHunter,
    ElitePowerKind.chimeraFury,
    ElitePowerKind.stormcaller,
    ElitePowerKind.ironWill,
    ElitePowerKind.phaseShift,
    ElitePowerKind.omegaAura,
  ];
}
