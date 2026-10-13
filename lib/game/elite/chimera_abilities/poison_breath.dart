import 'dart:math' as math;
import 'dart:ui';

import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// POISON BREATH - a 90 degree cone that adds two venom stacks.
class PoisonBreath extends ChimeraAbility {
  PoisonBreath() : super(ChimeraAbilityKind.poisonBreath);

  @override
  double get maxRange => 380;

  @override
  void fire(Chimera chimera, BattleGame game) {
    chimera.coneDamage(
      game,
      range: 340,
      arc: math.pi / 2,
      damage: damageFor(chimera),
      poisonStacks: 2,
      label: 'Poison breath',
      color: const Color(0xFF4D7C0F),
    );
  }
}
