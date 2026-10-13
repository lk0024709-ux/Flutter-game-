import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// PETRIFY - no damage, but the warrior's legs turn to stone.
///
/// 65% slow for 3s and a short stun, which is the chimera's window to charge.
class Petrify extends ChimeraAbility {
  Petrify() : super(ChimeraAbilityKind.petrify);

  @override
  double get maxRange => 460;

  @override
  void fire(Chimera chimera, BattleGame game) {
    chimera.petrify(game, slowAmount: 0.65, slowSeconds: 3.0, stunSeconds: 0.5);
  }
}
