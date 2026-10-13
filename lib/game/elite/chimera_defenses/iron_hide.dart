import '../chimera.dart';
import '../chimera_ability.dart';

/// IRON HIDE - the chimera simply takes 40% less damage from everything.
class IronHide extends ChimeraDefense {
  IronHide() : super(ChimeraDefenseKind.ironHide);

  static const double damageMultiplier = 0.60;

  @override
  double modifyIncomingDamage(Chimera chimera, double amount) =>
      amount * damageMultiplier;
}
