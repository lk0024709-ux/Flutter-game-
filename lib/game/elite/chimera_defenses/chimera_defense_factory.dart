import '../chimera_ability.dart';
import 'damage_reflect.dart';
import 'dodge_instinct.dart';
import 'energy_shield.dart';
import 'iron_hide.dart';
import 'mirror_image.dart';
import 'phase_shift.dart';
import 'regeneration.dart';
import 'summon_minions.dart';

/// Builds the concrete objects for every [ChimeraDefenseKind].
class ChimeraDefenseFactory {
  const ChimeraDefenseFactory._();

  /// Canonical ordering used by the elite codex UI.
  static const List<ChimeraDefenseKind> order = <ChimeraDefenseKind>[
    ChimeraDefenseKind.ironHide,
    ChimeraDefenseKind.regen,
    ChimeraDefenseKind.energyShield,
    ChimeraDefenseKind.dodgeInstinct,
    ChimeraDefenseKind.damageReflect,
    ChimeraDefenseKind.phaseShift,
    ChimeraDefenseKind.summonMinions,
    ChimeraDefenseKind.mirrorImage,
  ];

  static ChimeraDefense create(ChimeraDefenseKind kind) {
    switch (kind) {
      case ChimeraDefenseKind.ironHide:
        return IronHide();
      case ChimeraDefenseKind.regen:
        return Regeneration();
      case ChimeraDefenseKind.energyShield:
        return EnergyShield();
      case ChimeraDefenseKind.dodgeInstinct:
        return DodgeInstinct();
      case ChimeraDefenseKind.damageReflect:
        return DamageReflect();
      case ChimeraDefenseKind.phaseShift:
        return PhaseShift();
      case ChimeraDefenseKind.summonMinions:
        return SummonMinions();
      case ChimeraDefenseKind.mirrorImage:
        return MirrorImage();
    }
  }

  static List<ChimeraDefense> buildAll(Set<ChimeraDefenseKind> kinds) {
    final List<ChimeraDefense> result = <ChimeraDefense>[];
    for (final ChimeraDefenseKind kind in order) {
      if (kinds.contains(kind)) {
        result.add(create(kind));
      }
    }
    return result;
  }
}
