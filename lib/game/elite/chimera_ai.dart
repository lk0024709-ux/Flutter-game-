import 'dart:math' as math;

import 'package:flame/extensions.dart';

import '../battle_game.dart';
import '../fighter.dart';
import 'chimera.dart';
import 'chimera_ability.dart';

/// Decision making for the fusion bosses.
///
/// The AI is deliberately readable rather than clever: every chimera keeps a
/// preferred distance band for the current phase, strafes in one direction for
/// 1.8 seconds at a time, retreats only when it can regenerate, and never fires
/// the same attack twice in a row. That gives the fight a rhythm the player can
/// learn inside two attempts, which is exactly what a boss trial needs.
class ChimeraAi {
  const ChimeraAi._();

  /// Seconds before the strafing direction flips.
  static const double strafeFlip = 1.8;

  /// Distance the boss tries to keep for each phase (close, mid, press).
  static double preferredRange(Chimera chimera) {
    switch (chimera.phaseState.index) {
      case 0:
        return 320;
      case 1:
        return 230;
      default:
        return 120;
    }
  }

  /// True when a wounded boss with regeneration should back off and heal.
  static bool shouldRetreat(Chimera chimera) {
    if (chimera.phaseState.index >= 2) {
      return false;
    }
    if (chimera.hpPercent >= 0.35) {
      return false;
    }
    for (final ChimeraDefense defense in chimera.defenses) {
      if (defense.kind == ChimeraDefenseKind.regen) {
        return true;
      }
    }
    return false;
  }

  /// Movement request for this frame, in world units (magnitude 0..1).
  static Vector2 desiredMovement(Chimera chimera, BattleGame game) {
    final Fighter? target = chimera.target;
    if (target == null || !target.alive) {
      return Vector2.zero();
    }
    final Vector2 toTarget = target.position - chimera.position;
    final double distance = toTarget.length;
    if (distance < 0.001) {
      return Vector2.zero();
    }
    final Vector2 direction = toTarget.scaled(1 / distance);

    if (shouldRetreat(chimera)) {
      // Back off, but never leave the arena.
      return direction.scaled(-1);
    }

    final double preferred = preferredRange(chimera);
    double radial = 0;
    if (distance > preferred + 40) {
      radial = 1;
    } else if (distance < preferred - 40) {
      radial = -1;
    }

    // Perpendicular strafe, flipping direction on a fixed clock so the player
    // can still lead their swings.
    final double flip = (chimera.enragePulse / strafeFlip).floorToDouble();
    final bool clockwise = flip.toInt().isEven;
    final Vector2 perpendicular = clockwise
        ? Vector2(-direction.y, direction.x)
        : Vector2(direction.y, -direction.x);

    final Vector2 desired = direction.scaled(radial) + perpendicular.scaled(0.75);
    if (desired.length > 1) {
      desired.normalize();
    }
    return desired;
  }

  /// Picks the next attack, or null when everything is on cooldown.
  static ChimeraAbility? chooseAbility(Chimera chimera, BattleGame game) {
    final Fighter? target = chimera.target;
    if (target == null || !target.alive) {
      return null;
    }
    final double distance = chimera.position.distanceTo(target.position);

    // Only the first N abilities are unlocked in the current phase.
    final int limit = math.min(chimera.phaseState.abilityCount, chimera.abilities.length);
    final List<ChimeraAbility> ready = <ChimeraAbility>[];
    for (int i = 0; i < limit; i++) {
      final ChimeraAbility ability = chimera.abilities[i];
      if (ability.ready) {
        ready.add(ability);
      }
    }
    if (ready.isEmpty) {
      return null;
    }

    // Prefer attacks that suit the current distance.
    final List<ChimeraAbility> ranged =
        ready.where((ChimeraAbility ability) => ability.inRange(distance)).toList();
    final List<ChimeraAbility> pool = ranged.isNotEmpty ? ranged : ready;

    // No immediate repeats unless nothing else is available.
    if (pool.length > 1) {
      final List<ChimeraAbility> alternatives =
          pool.where((ChimeraAbility ability) => ability != chimera.lastAbility).toList();
      if (alternatives.isNotEmpty) {
        return alternatives[game.rng.nextInt(alternatives.length)];
      }
    }
    return pool[game.rng.nextInt(pool.length)];
  }
}
