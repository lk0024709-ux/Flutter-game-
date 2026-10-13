import 'dart:ui';

import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// SHOCKWAVE - 40 damage in a 250 unit ring plus heavy knockback.
class Shockwave extends ChimeraAbility {
  Shockwave() : super(ChimeraAbilityKind.shockwave);

  @override
  double get maxRange => 320;

  @override
  void fire(Chimera chimera, BattleGame game) {
    chimera.areaDamage(
      game,
      radius: 250,
      damage: damageFor(chimera),
      knockback: 420,
      label: 'Shockwave',
      color: const Color(0xFFB45309),
    );
  }
}
