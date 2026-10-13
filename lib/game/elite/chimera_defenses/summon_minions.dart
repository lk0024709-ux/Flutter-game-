import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// SUMMON MINIONS - two 150 HP minions every 20 seconds.
class SummonMinions extends ChimeraDefense {
  SummonMinions() : super(ChimeraDefenseKind.summonMinions);

  static const double interval = 20.0;
  static const double minionHp = 150.0;

  @override
  void update(double dt, Chimera chimera, BattleGame game) {
    if (cooldownLeft > 0) {
      cooldownLeft -= dt;
      return;
    }
    // The first batch arrives a few seconds into the fight, not on spawn.
    cooldownLeft = interval;
    chimera.summonMinions(game, 2, hp: minionHp);
  }
}
