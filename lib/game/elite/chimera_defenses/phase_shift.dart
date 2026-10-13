import 'dart:ui';

import '../../battle_game.dart';
import '../../effects.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// PHASE SHIFT - one second of invulnerability at every phase break.
///
/// This is the "you cannot burst me through my phase" rule: the chimera always
/// gets a beat to reposition when 66% and 33% are crossed.
class PhaseShift extends ChimeraDefense {
  PhaseShift() : super(ChimeraDefenseKind.phaseShift);

  static const double duration = 1.0;

  @override
  void onPhaseChange(Chimera chimera, BattleGame game) {
    chimera.invulnTimer = duration;
    game.addEffect(
      RingPulse(
        position: chimera.position.clone(),
        startRadius: chimera.radius * 3,
        endRadius: chimera.radius,
        color: const Color(0xFFF5F1EA),
        life: 0.6,
      ),
    );
    game.addFloatingText(
      '${icon} PHASE SHIFT',
      chimera.position.clone(),
      const Color(0xFFF5F1EA),
      size: 16,
    );
  }
}
