import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'creature.dart';
import 'effects.dart';
import 'fighter.dart';
import 'fire_projectile.dart';
import 'levels/boss_levels.dart';
import 'poison_effect.dart';

/// Base class for every wild creature.
///
/// Handles: nearest-enemy targeting (any faction), chase / back off / circle
/// strafe, separation, storm-ring obedience, boss phases and the shared attack
/// pipeline. Subclasses implement [updateAbility] and [renderBody].
abstract class Npc extends Fighter {
  Npc({
    required CreatureType type,
    required int fighterId,
    required int factionId,
    required Vector2 position,
    required double difficulty,
    bool elite = false,
    bool mirrorClone = false,
    bool neutral = false,
    bool boss = false,
    bool permanent = false,
    double? hpOverride,
    String? nameOverride,
    BossProfile? bossProfile,
    double hpScaleMul = 1.0,
    double damageScaleMul = 1.0,
    double speedScaleMul = 1.0,
  })  : type = type,
        difficulty = difficulty,
        eliteVariant = elite,
        isMirrorClone = mirrorClone,
        neutral = neutral,
        isBoss = boss,
        permanent = permanent,
        nameOverride = nameOverride,
        bossProfile = bossProfile,
        super(
          fighterId: fighterId,
          factionId: factionId,
          position: position,
          baseRadius: type.size,
          maxHp: (hpOverride ?? type.hp * hpScaleFor(difficulty) * (elite ? 3.2 : 1.0)) * hpScaleMul,
          baseSpeed: type.speed * speedScaleFor(difficulty) * (elite ? 0.92 : 1.0) * speedScaleMul,
          baseDamage: type.damage * damageScaleFor(difficulty) * (elite ? 1.6 : 1.0) * damageScaleMul,
          reach: type.reach,
          attackInterval: type.attackInterval,
          defensePercent: elite ? 0.15 : 0.0,
        ) {
    radius = baseRadius * (eliteVariant || isBoss ? 1.45 : 1.0);
  }

  /// Health scaling is deliberately sub-linear so rank 7 stays hard but fair.
  static double hpScaleFor(double difficulty) => 1 + (difficulty - 1) * 0.30;

  static double damageScaleFor(double difficulty) => 1 + (difficulty - 1) * 0.18;

  static double speedScaleFor(double difficulty) => 1 + (difficulty - 1) * 0.06;

  final CreatureType type;

  /// 0.8 .. ~15 - drives health, damage and speed scaling.
  final double difficulty;

  final bool eliteVariant;
  final bool isMirrorClone;

  /// Neutral beasts ignore everyone until somebody hits them (Rann's Avatar).
  bool neutral;

  final bool isBoss;

  /// Bosses spawned by a twist are not counted as level bosses.
  final bool permanent;

  final String? nameOverride;
  final BossProfile? bossProfile;

  // ------------------------------------------------------------------- AI state
  Fighter? target;
  double retargetTimer = 0;
  double strafeSign = 1;
  double strafeTimer = 0;
  double wanderAngle = 0;
  double wanderTimer = 0;
  double abilityTimer = 0;
  double abilityActive = 0;
  double abilitySpeedMultiplier = 1.0;
  double dashVelocity = 0;
  bool telegraphing = false;
  int phaseIndex = 0;
  double bossAbilityTimer = 4;
  double bossSummonTimer = 15;
  double bossRangedTimer = 3;
  bool bloodlust = false;
  Vector2? lockedDirection;

  double get scaleFactor => radius / type.size;

  @override
  String get displayName {
    if (nameOverride != null) {
      return nameOverride!;
    }
    if (isMirrorClone) {
      return '${type.label} Mirror';
    }
    if (eliteVariant) {
      return 'Elite ${type.label}';
    }
    return type.label;
  }

  /// Every beast gets its own faction hue, which makes the chaos readable.
  Color get factionColor {
    final Color base = type.baseColor;
    final HSLColor hsl = HSLColor.fromColor(base);
    final double hue = (hsl.hue + (factionId * 47) % 360) % 360;
    return hsl
        .withHue(hue)
        .withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Color get bodyColor => factionColor;

  @override
  Color get accentColor => Color.lerp(factionColor, const Color(0xFFF5F1EA), 0.35)!;

  @override
  double get effectiveSpeed => super.effectiveSpeed * abilitySpeedMultiplier;

  // ------------------------------------------------------------------ update
  void updateNpc(double dt, BattleGame game) {
    updateTimers(dt, game);
    if (!alive) {
      return;
    }

    // Bosses gear up as their health drops.
    _updateBossPhase(game);
    updateBossAbilities(dt, game);

    updateAbility(dt, game);
    if (!alive) {
      return;
    }

    _selectTarget(dt, game);
    _steer(dt, game);
    _maybeAttack(dt, game);
    separate(game);
  }

  void _updateBossPhase(BattleGame game) {
    final BossProfile? profile = bossProfile;
    if (profile == null) {
      return;
    }
    final BossPhase phase = profile.phaseFor(hpPercent);
    if (phase.index == phaseIndex) {
      damageMultiplier = phase.damageMultiplier;
      speedMultiplier = phase.speedMultiplier * (isBoss ? 1.0 : 1.0);
      return;
    }
    phaseIndex = phase.index;
    damageMultiplier = phase.damageMultiplier;
    speedMultiplier = phase.speedMultiplier;
    invulnTimer = 1.0;
    game.addFloatingText(
      'PHASE ${phase.index + 1}',
      position.clone(),
      const Color(0xFF7C2D12),
      size: 20,
    );
    game.addEffect(
      RingPulse(
        position: position.clone(),
        startRadius: radius,
        endRadius: radius * 4,
        color: const Color(0xFFB45309),
        life: 0.6,
      ),
    );
    game.pushArea(center: position.clone(), radius: radius * 4, force: 320);
  }

  void _selectTarget(double dt, BattleGame game) {
    retargetTimer -= dt;
    final bool needsTarget = target == null || !target!.alive || retargetTimer <= 0;
    if (!needsTarget) {
      return;
    }
    retargetTimer = 0.4 + game.rng.nextDouble() * 0.3;

    if (neutral) {
      target = null;
      return;
    }

    Fighter? best;
    double bestDistance = double.infinity;
    for (final Fighter other in game.fighters) {
      if (identical(other, this) || !other.alive) {
        continue;
      }
      if (other is Npc && other.neutral) {
        continue;
      }
      final double distance = position.distanceTo(other.position);
      if (distance < bestDistance) {
        best = other;
        bestDistance = distance;
      }
    }
    target = best;
  }

  void _steer(double dt, BattleGame game) {
    strafeTimer -= dt;
    if (strafeTimer <= 0) {
      strafeTimer = 1.2 + game.rng.nextDouble() * 1.4;
      strafeSign = game.rng.nextBool() ? 1 : -1;
    }

    // The storm always wins the argument: everything runs for the circle.
    if (game.zones.enabled && !game.zones.containsFighter(this)) {
      final Vector2 toCenter = game.zones.center - position;
      move(toCenter, dt, game);
      return;
    }

    final Fighter? currentTarget = target;
    if (currentTarget == null) {
      // Idle drift when there is nothing to hunt.
      wanderTimer -= dt;
      if (wanderTimer <= 0) {
        wanderTimer = 1.6 + game.rng.nextDouble() * 2.4;
        wanderAngle = game.rng.nextDouble() * math.pi * 2;
      }
      final Vector2 wander = Vector2(math.cos(wanderAngle), math.sin(wanderAngle));
      move(wander..scale(0.35), dt, game);
      return;
    }

    final Vector2 delta = currentTarget.position - position;
    final double distance = delta.length;
    final double preferred = type.preferredRange;
    final double attackRange = reach + currentTarget.radius;

    if (fearTimer > 0) {
      // Roared at: run away instead of committing.
      move(-delta, dt, game);
      return;
    }

    if (lockedDirection != null && abilityActive > 0) {
      move(lockedDirection!, dt, game);
      return;
    }

    if (telegraphing) {
      move(Vector2.zero(), dt, game);
      faceTowards(delta);
      return;
    }

    final Vector2 direction = Vector2.zero();
    if (type.isRanged) {
      if (distance > preferred + 20) {
        direction.setFrom(delta);
      } else if (distance < preferred - 40) {
        direction.setFrom(-delta);
      } else {
        direction.setFrom(_perpendicular(delta)..scale(strafeSign));
      }
    } else {
      if (distance > attackRange * 0.92) {
        direction.setFrom(delta);
      } else if (distance < attackRange * 0.5) {
        direction.setFrom((-delta)..scale(0.8));
      } else {
        direction.setFrom(_perpendicular(delta)..scale(strafeSign * 0.8));
      }
    }

    move(direction, dt, game);
    faceTowards(delta);
  }

  Vector2 _perpendicular(Vector2 delta) {
    final Vector2 result = delta.clone()..normalize();
    return Vector2(-result.y, result.x);
  }

  void _maybeAttack(double dt, BattleGame game) {
    attackCooldown = math.max(0.0, attackCooldown - dt);
    final Fighter? currentTarget = target;
    if (currentTarget == null || !canAttack) {
      return;
    }
    final Vector2 delta = currentTarget.position - position;
    final double distance = delta.length;
    if (distance > reach + currentTarget.radius) {
      return;
    }
    final double angle = math.atan2(delta.y, delta.x);
    if (angleDelta(angle, facing).abs() > 1.1) {
      return;
    }
    attackCooldown = attackInterval;
    attack(currentTarget, game);
  }

  /// Standard melee bite / claw / gore.
  void attack(Fighter victim, BattleGame game) {
    victim.takeDamage(attackDamage, source: this, label: displayName);
    game.addEffect(
      HitSpark(
        position: victim.position.clone(),
        radius: victim.radius,
        color: const Color(0xFFB45309),
        count: 4,
      ),
    );
  }

  /// Creature-specific ability tick (dashes, charges, dives, fire breath...).
  void updateAbility(double dt, BattleGame game) {}

  // ------------------------------------------------------------------ helpers
  /// Fires a fireball toward [victim].
  void breatheFire(Fighter victim, BattleGame game, {double damage, double speed = 400}) {
    final Vector2 direction = victim.position - position;
    if (direction.length2 < 0.001) {
      return;
    }
    game.projectiles.add(
      FireProjectile(
        position: position.clone(),
        velocity: direction.clone()
          ..normalize()
          ..scale(speed),
        damage: damage,
        factionId: factionId,
        owner: this,
        radius: 9,
      ),
    );
  }

  /// Position the AI predicts for the target (used by predictive abilities).
  Vector2 predictedTargetPosition() {
    final Fighter? currentTarget = target;
    if (currentTarget == null) {
      return position.clone();
    }
    return currentTarget.position.clone()
      ..add(currentTarget.velocity.clone()..scale(0.35));
  }

  /// Boss ability pipeline shared by the rank bosses and Rann's Avatar.
  void updateBossAbilities(double dt, BattleGame game) {
    final BossProfile? profile = bossProfile;
    if (profile == null || neutral) {
      return;
    }
    final BossPhase phase = profile.phaseFor(hpPercent);

    if (phase.has(BossAbility.shockwave)) {
      bossAbilityTimer -= dt;
      if (bossAbilityTimer <= 0) {
        bossAbilityTimer = 6.0;
        game.damageArea(
          center: position.clone(),
          radius: 230,
          damage: attackDamage * 1.4,
          source: this,
          label: 'Shockwave',
        );
        game.pushArea(center: position.clone(), radius: 230, force: 380);
        game.addEffect(
          RingPulse(
            position: position.clone(),
            startRadius: radius,
            endRadius: 230,
            color: const Color(0xFFB45309),
            life: 0.5,
          ),
        );
      }
    }

    if (phase.has(BossAbility.fireball)) {
      bossRangedTimer -= dt;
      if (bossRangedTimer <= 0) {
        bossRangedTimer = 2.6;
        final Fighter? victim = target;
        if (victim != null && victim.alive && position.distanceTo(victim.position) < 620) {
          breatheFire(victim, game, damage: attackDamage * 1.1);
        }
      }
    }

    if (phase.has(BossAbility.summonSkyhawks)) {
      bossSummonTimer -= dt;
      if (bossSummonTimer <= 0) {
        bossSummonTimer = phase.summonInterval;
        for (int i = 0; i < 3; i++) {
          game.spawnNpc(
            type: CreatureType.skyhawk,
            position: position.clone()
              ..add(Vector2(game.rng.nextDouble() * 200 - 100, 90 + game.rng.nextDouble() * 90)),
            difficulty: difficulty * 0.8,
          );
        }
        game.addFloatingText('REINFORCEMENTS', position.clone(), const Color(0xFFB45309), size: 16);
      }
    }
  }

  /// Called by the battle when this beast dies.
  void onDeath(BattleGame game) {
    game.addEffect(
      DeathBurst(position: position.clone(), color: bodyColor, radius: radius * 1.3),
    );
  }

  @override
  void renderBody(Canvas canvas) {
    // Shared fallback body - every concrete creature overrides this.
    canvas.drawCircle(Offset.zero, radius, Paint()..color = bodyColor);
  }

  /// Marks the beast as hit so neutral bosses wake up.
  void wakeIfNeutral(BattleGame game) {
    if (!neutral) {
      return;
    }
    neutral = false;
    game.addFloatingText('AWAKENED', position.clone(), const Color(0xFFB91C1C), size: 20);
    game.addEffect(
      RingPulse(
        position: position.clone(),
        startRadius: radius,
        endRadius: radius * 5,
        color: const Color(0xFFB91C1C),
        life: 0.7,
      ),
    );
  }

  /// Applies poison from venom bites.
  void biteWithPoison(Fighter victim, BattleGame game) {
    victim.takeDamage(attackDamage, source: this, label: 'Venom bite');
    PoisonEffect.apply(victim, game: game);
  }
}
