import '../../fighter.dart';
import '../chimera.dart';
import '../chimera_ability.dart';

/// DAMAGE REFLECT - 25% of every hit comes straight back at the attacker.
class DamageReflect extends ChimeraDefense {
  DamageReflect() : super(ChimeraDefenseKind.damageReflect);

  @override
  double get reflectPercent => 0.25;

  /// Applies the reflected damage to the attacker.
  void reflect(Chimera chimera, Fighter source, double damageTaken) {
    if (damageTaken <= 0) {
      return;
    }
    source.takeDamage(
      damageTaken * reflectPercent,
      ignoreDefense: true,
      label: '${chimera.name} reflect',
    );
  }
}
