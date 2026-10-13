import '../../battle_game.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// MIRROR IMAGE - splits off a fighting clone, twice per fight.
///
/// The clone is a real, lesser beast: it hits for full damage but dies in a few
/// sword swings, which keeps the warrior busy while the chimera winds up.
class MirrorImage extends ChimeraDefense {
  MirrorImage() : super(ChimeraDefenseKind.mirrorImage);

  /// How many clones this defence may create per battle.
  static const int maxClones = 2;

  static const double cloneLife = 10.0;

  int clonesCreated = 0;

  @override
  void update(double dt, Chimera chimera, BattleGame game) {
    if (clonesCreated >= maxClones || chimera.hasClone) {
      return;
    }
    // Clone on the second and third phase, mirroring the phase breaks.
    final int expected = chimera.phaseState.index - 1;
    if (expected < 0 || clonesCreated > expected - 1) {
      return;
    }
    clonesCreated++;
    chimera.summonMirrorImage(game, life: cloneLife);
  }
}
