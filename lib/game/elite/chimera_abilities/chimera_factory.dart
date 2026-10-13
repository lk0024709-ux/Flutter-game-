import '../chimera_ability.dart';
import 'charge.dart';
import 'dive_strike.dart';
import 'fireballs.dart';
import 'lightning_strike.dart';
import 'petrify.dart';
import 'poison_breath.dart';
import 'roar.dart';
import 'roll_attack.dart';
import 'shockwave.dart';
import 'tail_swipe.dart';

/// Builds the concrete objects for every [ChimeraAbilityKind].
///
/// The list order is the progression order: a chimera unlocks its first N
/// abilities as the fight escalates, so signature moves always come first.
class ChimeraAbilityFactory {
  const ChimeraAbilityFactory._();

  /// Canonical ordering used when assembling a chimera's arsenal.
  static const List<ChimeraAbilityKind> order = <ChimeraAbilityKind>[
    ChimeraAbilityKind.diveStrike,
    ChimeraAbilityKind.shockwave,
    ChimeraAbilityKind.poisonBreath,
    ChimeraAbilityKind.fireballs,
    ChimeraAbilityKind.petrify,
    ChimeraAbilityKind.charge,
    ChimeraAbilityKind.roar,
    ChimeraAbilityKind.rollAttack,
    ChimeraAbilityKind.tailSwipe,
    ChimeraAbilityKind.lightningStrike,
  ];

  static ChimeraAbility create(ChimeraAbilityKind kind) {
    switch (kind) {
      case ChimeraAbilityKind.diveStrike:
        return DiveStrike();
      case ChimeraAbilityKind.shockwave:
        return Shockwave();
      case ChimeraAbilityKind.poisonBreath:
        return PoisonBreath();
      case ChimeraAbilityKind.fireballs:
        return Fireballs();
      case ChimeraAbilityKind.petrify:
        return Petrify();
      case ChimeraAbilityKind.charge:
        return Charge();
      case ChimeraAbilityKind.roar:
        return Roar();
      case ChimeraAbilityKind.rollAttack:
        return RollAttack();
      case ChimeraAbilityKind.tailSwipe:
        return TailSwipe();
      case ChimeraAbilityKind.lightningStrike:
        return LightningStrike();
    }
  }

  /// Builds a sorted arsenal from an unordered set of kinds.
  static List<ChimeraAbility> buildAll(Set<ChimeraAbilityKind> kinds) {
    final List<ChimeraAbility> result = <ChimeraAbility>[];
    for (final ChimeraAbilityKind kind in order) {
      if (kinds.contains(kind)) {
        result.add(create(kind));
      }
    }
    return result;
  }
}
