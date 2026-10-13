import '../battle_game.dart';
import 'chimera.dart';

/// The ten chimera attacks.
///
/// [damage] is the nominal hit value; every ability scales it by the chimera's
/// current damage multiplier so phase 3 genuinely hurts more.
enum ChimeraAbilityKind {
  diveStrike('Dive Strike', '🦅', 45, 8.0, 1.0, 'Swoops across the arena.'),
  shockwave('Shockwave', '💥', 40, 12.0, 0.9, 'Ground slam in a wide ring.'),
  poisonBreath('Poison Breath', '☠️', 25, 10.0, 1.0, 'Wide cone of venom.'),
  fireballs('Fireballs', '🔥', 20, 9.0, 0.8, 'Three homing fireballs.'),
  petrify('Petrify', '🪨', 0, 14.0, 1.0, 'A gaze that locks your legs.'),
  charge('Charge', '🐗', 60, 11.0, 0.6, 'Tramples and stuns.'),
  roar('Roar', '📣', 0, 16.0, 0.8, 'Fear, knockback and reinforcements.'),
  rollAttack('Roll Attack', '🌀', 50, 10.0, 0.7, 'Rolls through you, armoured.'),
  tailSwipe('Tail Swipe', '〰️', 35, 5.0, 0.4, 'Fast 360 swipe.'),
  lightningStrike('Lightning Strike', '⚡', 30, 9.0, 1.2, 'Calls a bolt to your feet.');

  const ChimeraAbilityKind(
    this.label,
    this.icon,
    this.damage,
    this.cooldown,
    this.telegraph,
    this.description,
  );

  final String label;
  final String icon;

  /// Nominal damage before the chimera's damage multiplier.
  final double damage;

  /// Seconds before the ability can be used again.
  final double cooldown;

  /// Wind-up time; the player can always dodge inside this window.
  final double telegraph;

  final String description;
}

/// Base class for a single chimera attack.
abstract class ChimeraAbility {
  ChimeraAbility(this.kind);

  final ChimeraAbilityKind kind;

  /// Seconds remaining before this attack is available again.
  double cooldownLeft = 0;

  bool get ready => cooldownLeft <= 0;

  String get label => kind.label;

  String get icon => kind.icon;

  double get telegraph => kind.telegraph;

  /// Damage this attack deals right now.
  double damageFor(Chimera chimera) => kind.damage * chimera.damageMultiplier;

  /// Distance band the AI should respect when picking this attack.
  double get minRange => 0;

  double get maxRange => double.infinity;

  bool inRange(double distance) => distance >= minRange && distance <= maxRange;

  void update(double dt) {
    if (cooldownLeft > 0) {
      cooldownLeft -= dt;
    }
  }

  /// Puts the attack on cooldown after it fires.
  void startCooldown([double multiplier = 1.0]) {
    cooldownLeft = kind.cooldown * multiplier;
  }

  /// The attack itself - implemented by the ten concrete abilities.
  void fire(Chimera chimera, BattleGame game);
}

/// The eight chimera defensive passives.
enum ChimeraDefenseKind {
  ironHide('Iron Hide', '🛡️', 'Takes 40% less damage.'),
  regen('Regeneration', '❤️', 'Heals 15 HP/s below half health.'),
  energyShield('Energy Shield', '🔵', 'Absorbs 200 damage, recharges in 15s.'),
  dodgeInstinct('Dodge Instinct', '💨', 'Dodges 30% of incoming attacks.'),
  damageReflect('Damage Reflect', '🪞', 'Reflects 25% of damage taken.'),
  phaseShift('Phase Shift', '👻', '1s of invulnerability at each phase break.'),
  summonMinions('Summon Minions', '🐾', 'Summons two 150 HP minions every 20s.'),
  mirrorImage('Mirror Image', '🎭', 'Splits off a 10s fighting clone.');

  const ChimeraDefenseKind(this.label, this.icon, this.description);

  final String label;
  final String icon;
  final String description;
}

/// Base class for chimera defensive passives.
abstract class ChimeraDefense {
  ChimeraDefense(this.kind);

  final ChimeraDefenseKind kind;

  /// Countdown used by the summoning defences.
  double cooldownLeft = 0;

  bool get ready => cooldownLeft <= 0;

  String get label => kind.label;

  String get icon => kind.icon;

  /// Chance to ignore an incoming hit completely.
  double get dodgeChance => 0;

  /// Fraction of incoming damage reflected back at the attacker.
  double get reflectPercent => 0;

  /// Applied every frame while the chimera is alive.
  void update(double dt, Chimera chimera, BattleGame game) {}

  /// Called when the chimera takes damage; returns the damage multiplier.
  double modifyIncomingDamage(Chimera chimera, double amount) => amount;

  /// Called when the chimera crosses a phase threshold.
  void onPhaseChange(Chimera chimera, BattleGame game) {}
}
