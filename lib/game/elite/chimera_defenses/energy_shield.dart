import 'dart:ui';

import '../../battle_game.dart';
import '../../effects.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// ENERGY SHIELD - absorbs 200 damage, then recharges after 15 seconds.
///
/// The shield uses the shared [Fighter.shield] pool, so the regular damage
/// pipeline absorbs it before health is touched.
class EnergyShield extends ChimeraDefense {
  EnergyShield() : super(ChimeraDefenseKind.energyShield);

  static const double capacity = 200;

  /// Seconds left until the shield comes back (0 while it is up).
  double rechargeLeft = 0;

  @override
  void update(double dt, Chimera chimera, BattleGame game) {
    if (chimera.shield > 0) {
      // Shield is currently up.
      rechargeLeft = rechargeDelay;
      return;
    }
    if (rechargeLeft <= 0) {
      // First activation (or the shield was never broken).
      chimera.shield = capacity;
      rechargeLeft = rechargeDelay;
      game.addFloatingText(
        '${icon} SHIELD UP',
        chimera.position.clone(),
        const Color(0xFF0891B2),
        size: 15,
      );
      return;
    }
    rechargeLeft -= dt;
    if (rechargeLeft <= 0) {
      rechargeLeft = rechargeDelay;
      chimera.shield = capacity;
      game.addEffect(
        RingPulse(
          position: chimera.position.clone(),
          startRadius: chimera.radius * 2.4,
          endRadius: chimera.radius * 1.2,
          color: const Color(0xFF0891B2),
          life: 0.5,
        ),
      );
      game.addFloatingText(
        '${icon} SHIELD UP',
        chimera.position.clone(),
        const Color(0xFF0891B2),
        size: 15,
      );
    }
  }

  /// Recharge delay after the shield breaks, in seconds.
  static const double rechargeDelay = 15.0;
}
