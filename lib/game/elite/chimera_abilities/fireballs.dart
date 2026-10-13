import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// FIREBALLS - three homing fireballs, 20 damage each.
class Fireballs extends ChimeraAbility {
  Fireballs() : super(ChimeraAbilityKind.fireballs);

  @override
  double get minRange => 190;

  @override
  void fire(Chimera chimera, BattleGame game) {
    chimera.spawnFireballVolley(
      game,
      count: chimera.phaseState.index >= 2 ? 5 : 3,
      damage: damageFor(chimera),
    );
  }
}
