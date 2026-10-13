/// Phase tuning for a chimera fight.
///
/// The fusion bosses fight in three phases driven purely by health:
///
///  * Phase 1 (100-66%): two attacks, 2.5s cadence, a full second of telegraph.
///  * Phase 2 (66-33%): a phase shift, three attacks, faster cadence, summons.
///  * Phase 3 (33-0%): the full arsenal, 1.2s cadence, enraged damage/speed.
///
/// Keeping the tuning in one immutable record means balancing the trials never
/// requires touching the AI code.
class ChimeraPhaseState {
  const ChimeraPhaseState({
    required this.index,
    required this.label,
    required this.attackInterval,
    required this.telegraph,
    required this.damageMultiplier,
    required this.speedMultiplier,
    required this.abilityCount,
    required this.minionBatch,
    required this.enraged,
  });

  /// 0-based phase index.
  final int index;

  /// Short flavour label for the HUD ("Testing you", "Unleashed", "Enraged").
  final String label;

  /// Seconds between attack decisions.
  final double attackInterval;

  /// Telegraph length for every ability in this phase.
  final double telegraph;

  final double damageMultiplier;
  final double speedMultiplier;

  /// How many of the chimera's abilities the phase unlocks.
  final int abilityCount;

  /// Minions summoned when the phase begins.
  final int minionBatch;

  /// Phase 3 flag: the boss attacks without any pause.
  final bool enraged;

  /// Banner text shown when the phase starts.
  String get banner => 'PHASE ${index + 1} • $label';

  static const List<ChimeraPhaseState> phases = <ChimeraPhaseState>[
    ChimeraPhaseState(
      index: 0,
      label: 'Testing you',
      attackInterval: 2.5,
      telegraph: 1.0,
      damageMultiplier: 1.0,
      speedMultiplier: 1.0,
      abilityCount: 2,
      minionBatch: 0,
      enraged: false,
    ),
    ChimeraPhaseState(
      index: 1,
      label: 'Unleashed',
      attackInterval: 1.8,
      telegraph: 0.7,
      damageMultiplier: 1.2,
      speedMultiplier: 1.1,
      abilityCount: 3,
      minionBatch: 2,
      enraged: false,
    ),
    ChimeraPhaseState(
      index: 2,
      label: 'Enraged',
      attackInterval: 1.2,
      telegraph: 0.5,
      damageMultiplier: 1.35,
      speedMultiplier: 1.18,
      abilityCount: 10,
      minionBatch: 3,
      enraged: true,
    ),
  ];

  /// Resolves the phase for a health percentage.
  static ChimeraPhaseState forHp(double hpPercent) {
    if (hpPercent > 0.66) {
      return phases[0];
    }
    if (hpPercent > 0.33) {
      return phases[1];
    }
    return phases[2];
  }
}
