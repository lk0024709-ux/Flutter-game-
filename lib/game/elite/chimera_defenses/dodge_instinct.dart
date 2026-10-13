import 'dart:math' as math;

import '../chimera.dart';
import '../chimera_ability.dart';

/// DODGE INSTINCT - one in three attacks simply misses.
class DodgeInstinct extends ChimeraDefense {
  DodgeInstinct() : super(ChimeraDefenseKind.dodgeInstinct);

  final math.Random _rng = math.Random(3391);

  @override
  double get dodgeChance => 0.30;

  @override
  double modifyIncomingDamage(Chimera chimera, double amount) {
    if (_rng.nextDouble() >= dodgeChance) {
      return amount;
    }
    // Blink the body so the dodge reads instantly on screen.
    chimera.dodgeFlashTimer = 0.25;
    return 0;
  }
}
