import 'package:flame/extensions.dart';

import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// ROLL ATTACK - rolls through the warrior and armours up while rolling.
///
/// 50 damage on contact, but the chimera takes 40% less damage during the roll,
/// so trading hits inside the roll is the wrong answer.
class RollAttack extends ChimeraAbility {
  RollAttack() : super(ChimeraAbilityKind.rollAttack);

  @override
  void fire(Chimera chimera, BattleGame game) {
    final Vector2 destination = Chimera.predict(game.player, 0.25);
    chimera.dashTo(
      game,
      destination: destination,
      speed: 620,
      contactDamage: damageFor(chimera),
      knockback: 380,
      armoured: true,
    );
  }
}
