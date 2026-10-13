import 'package:flame/extensions.dart';

import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// CHARGE - 60 damage, hard knockback and a 1.2s stun.
class Charge extends ChimeraAbility {
  Charge() : super(ChimeraAbilityKind.charge);

  @override
  double get minRange => 300;

  @override
  void fire(Chimera chimera, BattleGame game) {
    final Vector2 destination = Chimera.predict(game.player, 0.3);
    chimera.dashTo(
      game,
      destination: destination,
      speed: 780,
      contactDamage: damageFor(chimera),
      stunSeconds: 1.2,
      knockback: 480,
      armoured: false,
    );
  }
}
