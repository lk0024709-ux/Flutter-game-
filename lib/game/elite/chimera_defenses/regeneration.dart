import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// REGENERATION - heals 15 HP per second while below half health.
class Regeneration extends ChimeraDefense {
  Regeneration() : super(ChimeraDefenseKind.regen);

  static const double healPerSecond = 15.0;

  @override
  void update(double dt, Chimera chimera, BattleGame game) {
    // Phase 3 rages too hard to bother healing.
    if (chimera.hpPercent >= 0.5 || chimera.phaseState.index >= 2) {
      return;
    }
    chimera.heal(healPerSecond * dt);
  }
}
