import 'package:flame/extensions.dart';

import '../../battle_game.dart';
import '../../fighter.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// DIVE STRIKE - 45 damage.
///
/// The chimera launches itself across the arena and hits everything it crosses
/// on the way. Long range only, so the AI uses it to close a gap.
class DiveStrike extends ChimeraAbility {
  DiveStrike() : super(ChimeraAbilityKind.diveStrike);

  @override
  double get minRange => 260;

  @override
  void fire(Chimera chimera, BattleGame game) {
    final Fighter target = game.player;
    final Vector2 destination = Chimera.predict(target, 0.45);
    chimera.dashTo(
      game,
      destination: destination,
      speed: 900,
      contactDamage: damageFor(chimera),
      stunSeconds: 0.25,
      armoured: false,
    );
  }
}
