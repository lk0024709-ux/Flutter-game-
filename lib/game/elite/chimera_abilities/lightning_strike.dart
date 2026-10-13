import '../../arena.dart';
import 'package:flame/extensions.dart';

import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// LIGHTNING STRIKE - calls a bolt onto the warrior's predicted position.
///
/// It uses the arena hazard telegraph, so the strike is announced by a filling
/// ring exactly like every other hazard in the game.
class LightningStrike extends ChimeraAbility {
  LightningStrike() : super(ChimeraAbilityKind.lightningStrike);

  @override
  void fire(Chimera chimera, BattleGame game) {
    final Vector2 impact = Chimera.predict(game.player, 0.55);
    game.arena.addHazard(
      ArenaHazard(
        kind: HazardKind.lightning,
        position: impact,
        radius: 96,
        telegraphSeconds: telegraph,
        oneShotDamage: damageFor(chimera),
        knockback: 220,
        life: telegraph + 0.5,
        owner: 'chimera',
        label: 'Lightning strike',
      ),
    );
    chimera.announceAbility(game, impact, '⚡ Bolt called');
  }
}
