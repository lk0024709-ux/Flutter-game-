import 'dart:math' as math;
import 'dart:ui';

import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// TAIL SWIPE - a fast 360 degree spin for 35 damage.
///
/// The shortest cooldown in the arsenal, so it punishes standing next to the
/// chimera for too long.
class TailSwipe extends ChimeraAbility {
  TailSwipe() : super(ChimeraAbilityKind.tailSwipe);

  @override
  double get maxRange => 220;

  @override
  void fire(Chimera chimera, BattleGame game) {
    chimera.areaDamage(
      game,
      radius: 190,
      damage: damageFor(chimera),
      knockback: 260,
      label: 'Tail swipe',
      color: const Color(0xFF78716C),
      spin: math.pi * 2,
    );
  }
}
