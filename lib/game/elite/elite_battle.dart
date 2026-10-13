import 'package:flame/extensions.dart';

import '../battle_game.dart';
import '../level_grade.dart';
import '../store_state.dart';
import 'chimera.dart';

/// The elite trial simulation: a pure duel against one chimera.
///
/// Everything else (arena, storm ring, camera, HUD) is inherited from
/// [BattleGame]; this subclass only replaces the enemy spawn with the fusion
/// boss and exposes elite-specific conveniences to the UI.
class EliteBattleGame extends BattleGame {
  EliteBattleGame({
    required this.trial,
    required BattleInput input,
    bool assistMode = false,
  }) : super(
          config: BattleConfig.elite(
            eliteTrialIndex: EliteTrial.all.indexOf(trial),
            eliteName: trial.type.label,
            eliteArenaId: trial.type.arenaId,
            assistMode: assistMode,
          ),
          input: input,
        );

  /// Builds a game for a trial, honouring the stored assist preference.
  factory EliteBattleGame.forTrial(EliteTrial trial, {BattleInput? input}) {
    return EliteBattleGame(
      trial: trial,
      input: input ?? BattleInput(),
      assistMode: StoreState.instance.assistMode && StoreState.instance.assistAvailable(trial.type),
    );
  }

  final EliteTrial trial;

  /// The fusion boss, once spawned.
  Chimera? champion;

  /// True when this run is using the assist handicap.
  bool get assistModeUsed => config.assistMode;

  @override
  void spawnEliteChampion() {
    final Chimera boss = Chimera(
      type: trial.type,
      fighterId: nextFighterId(),
      position: Vector2(worldSize.x / 2, worldSize.y * 0.34),
      difficulty: 1.0,
      assistMode: config.assistMode,
    );
    boss.factionId = 900 + trial.type.index;
    champion = boss;
    registerNpc(boss);

    // Announce the duel once the arena has settled.
    addFloatingText(
      '${trial.type.icon}  ${trial.type.label.toUpperCase()}',
      Vector2(worldSize.x / 2, worldSize.y * 0.5),
      trial.type.color,
      size: 26,
    );
  }

  /// Live chimera access for the elite HUD (null before the first frame).
  Chimera? get championOrNull => champion;

  /// True once the chimera is dead.
  bool get championDefeated => champion != null && !(champion!.alive);

  /// Percent of the trial completed (used by the victory flourish).
  double get championHpPercent => champion?.hpPercent ?? 1.0;

  /// The grade breakdown for this trial.
  GradeBreakdown gradeBreakdown() {
    return GradeCalculator.evaluate(
      timeSeconds: elapsed,
      hpPercent: player.hpPercent * 100,
      damageTaken: player.damageTakenThisBattle,
    );
  }
}
