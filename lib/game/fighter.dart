import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'poison_effect.dart';

/// The three damage channels used for the sub-score "damage taken" tracking.
enum DamageKind { melee, ranged, environment }

/// Base class for everything that can fight: the player and every NPC beast.
///
/// Fighters are plain Dart objects (not Flame components) so the whole battle
/// simulation stays allocation-light and testable. Rendering is done by a single
/// renderer component that walks the fighter lists, which keeps draw calls
/// batched and keeps 60 FPS on mobile.
abstract class Fighter {
  Fighter({
    required int fighterId,
    required int factionId,
    required Vector2 position,
    required double baseRadius,
    required double maxHp,
    required double baseSpeed,
    required double baseDamage,
    required double reach,
    required double attackInterval,
    double defensePercent = 0,
    bool isPlayer = false,
  })  : fighterId = fighterId,
        factionId = factionId,
        position = position,
        baseRadius = baseRadius,
        maxHp = maxHp,
        baseSpeed = baseSpeed,
        baseDamage = baseDamage,
        reach = reach,
        attackInterval = attackInterval,
        defensePercent = defensePercent,
        isPlayer = isPlayer,
        hp = maxHp,
        speed = baseSpeed,
        damage = baseDamage,
        radius = baseRadius;

  /// Unique runtime id (used for shrine cooldowns and HUD lookups).
  final int fighterId;

  /// Faction id. Every NPC rolls its own faction, so the arena is a true FFA.
  int factionId;

  /// True for the player-controlled warrior.
  final bool isPlayer;

  final Vector2 position;
  final Vector2 velocity = Vector2.zero();

  /// External push applied this frame (wind, conveyor effects).
  final Vector2 drift = Vector2.zero();

  final double baseRadius;
  final double maxHp;
  final double baseSpeed;
  final double baseDamage;

  /// Attack reach in world units.
  final double reach;

  /// Seconds between attacks.
  final double attackInterval;

  /// Damage reduction in the 0..1 range.
  double defensePercent;

  // ------------------------------------------------------------------ state
  double hp;
  double speed;
  double damage;
  double radius;
  double facing = 0;
  bool alive = true;

  double attackCooldown = 0;
  double hitFlash = 0;
  double invulnTimer = 0;
  double stunTimer = 0;
  double slowTimer = 0;
  double slowAmount = 0;
  double fearTimer = 0;
  double cowardTimer = 0;
  double combatTimer = 0;

  /// Movement responsiveness (1.0 normal, 0.25 while standing on ice).
  double traction = 1.0;

  double damageMultiplier = 1.0;
  double incomingDamageMultiplier = 1.0;
  double speedMultiplier = 1.0;

  /// Absorb shield (energy shield, ward power-up).
  double shield = 0;

  /// Poison stacks from venomtails.
  int poisonStacks = 0;
  double poisonTimer = 0;

  /// Poison immunity (Basilisk Scale).
  bool poisonImmune = false;

  /// Hits landed - used by the Chimera Fury elite power.
  int hitCount = 0;

  /// Extra life steal fraction (Vampirism power / Rann's Regalia).
  double vampirism = 0;

  /// Optional life steal for the attacker.
  double damageTakenThisBattle = 0;

  /// True once something has hit this fighter (wakes neutral bosses).
  bool wasAttacked = false;

  /// Set by the battle once the death effects have been played.
  bool deathHandled = false;

  // ------------------------------------------------------------- accessors
  double get hpPercent => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  bool get isDead => !alive;

  bool get isStunned => stunTimer > 0;

  bool get isSlowed => slowTimer > 0;

  bool get canAttack => alive && attackCooldown <= 0 && !isStunned;

  bool get canBeDamaged => alive && invulnTimer <= 0;

  bool get isCoward => cowardTimer > 0;

  /// Movement speed after every modifier.
  double get effectiveSpeed {
    if (isStunned) {
      return 0;
    }
    double value = speed * speedMultiplier;
    if (isSlowed) {
      value *= (1 - slowAmount).clamp(0.05, 1.0);
    }
    return value;
  }

  /// Total damage of one attack after buffs and debuffs.
  double get attackDamage {
    double value = damage * damageMultiplier;
    if (isCoward) {
      value *= 0.8;
    }
    return value;
  }

  /// Current body radius (overridden by bosses which scale up).
  double get bodyRadius => radius;

  /// Display name for the HUD ("Warrior", "Griffin", "Rann's Avatar", ...).
  String get displayName;

  /// Body colour (faction-tinted).
  Color get bodyColor;

  /// Secondary accent colour used for horns, tusks and wings.
  Color get accentColor;

  // ---------------------------------------------------------------- physics
  /// Moves the fighter along [direction] using velocity smoothing.
  void move(Vector2 direction, double dt, BattleGame game) {
    final Vector2 desired;
    if (direction.length2 > 0.0001) {
      desired = direction.clone()..normalize();
      desired.scale(effectiveSpeed);
      faceTowards(desired);
    } else {
      desired = Vector2.zero();
    }

    final double responsiveness = 13 * traction.clamp(0.15, 1.5);
    final double k = 1 - math.exp(-responsiveness * dt);
    velocity.x += (desired.x - velocity.x) * k;
    velocity.y += (desired.y - velocity.y) * k;

    if (velocity.length2 < 0.02) {
      velocity.setZero();
    }

    position
      ..x += (velocity.x + drift.x) * dt
      ..y += (velocity.y + drift.y) * dt;

    game.arena.resolve(this);
  }

  void faceTowards(Vector2 target) {
    if (target.length2 <= 0.0001) {
      return;
    }
    facing = math.atan2(target.y, target.x);
  }

  void applyKnockback(Vector2 direction, double force) {
    if (direction.length2 <= 0.0001) {
      return;
    }
    final Vector2 push = direction.clone()..normalize();
    push.scale(force);
    velocity.add(push);
  }

  // ------------------------------------------------------------- lifecycle
  void updateTimers(double dt, BattleGame? game) {
    if (attackCooldown > 0) {
      attackCooldown = math.max(0.0, attackCooldown - dt);
    }
    if (hitFlash > 0) {
      hitFlash = math.max(0.0, hitFlash - dt);
    }
    if (invulnTimer > 0) {
      invulnTimer = math.max(0.0, invulnTimer - dt);
    }
    if (stunTimer > 0) {
      stunTimer = math.max(0.0, stunTimer - dt);
    }
    if (slowTimer > 0) {
      slowTimer = math.max(0.0, slowTimer - dt);
    }
    if (fearTimer > 0) {
      fearTimer = math.max(0.0, fearTimer - dt);
    }
    if (cowardTimer > 0) {
      cowardTimer = math.max(0.0, cowardTimer - dt);
    }
    combatTimer += dt;
    if (shield > 0) {
      shield = math.max(0.0, shield - dt * 4);
    }
    PoisonEffect.tick(this, dt, game);
  }

  /// Applies damage with defense, shields, reflection hooks and death handling.
  void takeDamage(
    double raw, {
    Fighter? source,
    bool ignoreDefense = false,
    bool environmental = false,
    String label = '',
  }) {
    if (!alive) {
      return;
    }
    if (invulnTimer > 0 && !environmental) {
      return;
    }
    double amount = raw * incomingDamageMultiplier;
    if (!ignoreDefense) {
      amount *= (1 - defensePercent.clamp(0.0, 0.9));
    }
    if (shield > 0) {
      final double absorbed = math.min(shield, amount);
      shield -= absorbed;
      amount -= absorbed;
    }
    if (amount <= 0) {
      return;
    }
    hp -= amount;
    damageTakenThisBattle += amount;
    hitFlash = 0.16;
    combatTimer = 0;
    wasAttacked = true;
    if (source != null) {
      source.combatTimer = 0;
      if (source.vampirism > 0 && !environmental) {
        source.heal(amount * source.vampirism);
      }
    }
    if (hp <= 0) {
      hp = 0;
      alive = false;
    }
  }

  void heal(double amount) {
    if (!alive || amount <= 0) {
      return;
    }
    hp = math.min(maxHp, hp + amount);
  }

  /// Slows the fighter for [seconds]; stronger slows replace weaker ones.
  void applySlow(double amount, double seconds) {
    slowAmount = math.max(slowAmount, amount.clamp(0.0, 0.9));
    slowTimer = math.max(slowTimer, seconds);
  }

  void applyStun(double seconds) {
    stunTimer = math.max(stunTimer, seconds);
    velocity.setZero();
  }

  void cleanse() {
    poisonStacks = 0;
    poisonTimer = 0;
    slowTimer = 0;
    slowAmount = 0;
    stunTimer = 0;
    fearTimer = 0;
  }

  /// Push away from other fighters so the arena never becomes a single blob.
  void separate(BattleGame game) {
    for (final Fighter other in game.fighters) {
      if (identical(other, this) || !other.alive) {
        continue;
      }
      final Vector2 delta = position - other.position;
      final double minDistance = radius + other.radius;
      final double distance = delta.length;
      if (distance > 0.001 && distance < minDistance) {
        final double push = (minDistance - distance) * 0.5;
        delta.normalize();
        position.x += delta.x * push;
        position.y += delta.y * push;
        other.position.x -= delta.x * push;
        other.position.y -= delta.y * push;
      }
    }
  }

  // ----------------------------------------------------------------- render
  /// Soft ellipse shadow underneath the body.
  void renderShadow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: position.toOffset().translate(0, bodyRadius * 0.75),
        width: bodyRadius * 2.1,
        height: bodyRadius * 0.9,
      ),
      Paint()
        ..color = const Color(0x26000000)
        ..style = PaintingStyle.fill,
    );
  }

  /// Draws shadow, body, hit flash and (when hurt) the health bar.
  void render(Canvas canvas, BattleGame game) {
    renderShadow(canvas);
    canvas.save();
    canvas.translate(position.x, position.y);
    // Creature art is authored facing +X, so the body rotates with [facing].
    canvas.rotate(facing);
    renderBody(canvas);
    canvas.restore();
    if (hitFlash > 0) {
      final double alpha = (hitFlash / 0.16).clamp(0.0, 1.0) * 0.7;
      canvas.drawCircle(
        position.toOffset(),
        bodyRadius * 1.02,
        Paint()..color = const Color(0xFFF5F1EA).withAlpha((alpha * 255).round()),
      );
    }
    renderHealthBar(canvas);
    renderStatusIcons(canvas);
  }

  /// Body drawing in local space (origin = fighter centre).
  void renderBody(Canvas canvas);

  /// Thin rounded health bar, only drawn once the fighter has been hurt.
  void renderHealthBar(Canvas canvas) {
    if (hpPercent >= 0.999) {
      return;
    }
    final double width = math.max(34.0, bodyRadius * 2.4);
    final double height = 5;
    final Rect track = Rect.fromLTWH(
      position.x - width / 2,
      position.y - bodyRadius - 16,
      width,
      height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(3)),
      Paint()..color = const Color(0x66000000),
    );
    final Color fill = isPlayer
        ? const Color(0xFFD97706)
        : Color.lerp(const Color(0xFFB91C1C), const Color(0xFF3F6212), hpPercent)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(track.left, track.top, track.width * hpPercent, height),
        const Radius.circular(3),
      ),
      Paint()..color = fill,
    );
    if (shield > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            track.left,
            track.top - 4,
            track.width * (shield / math.max(1.0, maxHp * 0.4)).clamp(0.0, 1.0),
            3,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF0891B2),
      );
    }
  }

  /// Small icons above the health bar for poison / stun / fear states.
  void renderStatusIcons(Canvas canvas) {
    double offsetX = -bodyRadius;
    final double y = position.y - bodyRadius - 26;
    if (poisonStacks > 0) {
      canvas.drawCircle(
        Offset(position.x + offsetX, y),
        3.5,
        Paint()..color = Color(0xFF4D7C0F),
      );
      offsetX += 9;
    }
    if (isStunned) {
      canvas.drawCircle(
        Offset(position.x + offsetX, y),
        3.5,
        Paint()..color = const Color(0xFFB45309),
      );
      offsetX += 9;
    }
    if (fearTimer > 0) {
      canvas.drawCircle(
        Offset(position.x + offsetX, y),
        3.5,
        Paint()..color = const Color(0xFF7E22CE),
      );
    }
  }

  /// Circle-circle overlap test.
  bool overlaps(Fighter other) =>
      position.distanceTo(other.position) < radius + other.radius;
}

/// Shortest signed angle between two directions (in radians, -PI..PI).
double angleDelta(double a, double b) {
  double d = (a - b) % (2 * math.pi);
  if (d > math.pi) {
    d -= 2 * math.pi;
  }
  if (d < -math.pi) {
    d += 2 * math.pi;
  }
  return d;
}

/// Rotates [current] toward [target] by the fraction [t] of the shortest path.
double approachAngle(double current, double target, double t) {
  return current + angleDelta(target, current) * t.clamp(0.0, 1.0);
}

/// True when a hit lands: distance and facing arc both have to agree.
bool isInsideArc({
  required Vector2 origin,
  required Vector2 targetPosition,
  required double targetRadius,
  required double reach,
  required double facing,
  required double arc,
}) {
  final Vector2 delta = targetPosition - origin;
  final double distance = delta.length;
  if (distance > reach + targetRadius) {
    return false;
  }
  final double angle = math.atan2(delta.y, delta.x);
  return angleDelta(angle, facing).abs() <= arc / 2;
}
