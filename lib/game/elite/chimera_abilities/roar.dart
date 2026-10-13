import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// ROAR - a 400 unit fear pulse that also calls reinforcements.
class Roar extends ChimeraAbility {
  Roar() : super(ChimeraAbilityKind.roar);

  @override
  double get maxRange => 420;

  @override
  void fire(Chimera chimera, BattleGame game) {
    chimera.roarEffect(game, radius: 400, fearSeconds: 2.0);
    if (chimera.phaseState.index >= 1) {
      chimera.summonMinions(game, 2, hp: 150);
    }
  }
}
