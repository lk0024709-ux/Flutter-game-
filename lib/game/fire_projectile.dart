import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'arena.dart';
import 'battle_game.dart';
import 'effects.dart';
import 'fighter.dart';

/// A fireball in flight (drake breath, boss volleys, chimera fireballs).
class FireProjectile {
  FireProjectile({
    required this.position,
    required this.velocity,
    required this.damage,
    required this.factionId,
    this.owner,
    this.radius = 8,
    this.life = 3.0,
    this.homing,
    this.homingStrength = 0,
    this.color = const Color(0xFFEA580C),
    this.burstRadius = 0,
    this.burstDamage = 0,
  });

  final Vector2 position;
  final Vector2 velocity;
  final double damage;
  final int factionId;
  final Fighter? owner;
  final double radius;
  final double life;

  /// Optional homing target (chimera fireballs).
  final Fighter? homing;
  final double homingStrength;

  final Color color;

  /// When above zero the fireball explodes on impact.
  final double burstRadius;
  final double burstDamage;

  double age = 0;
  bool dead = false;
  double spin = 0;

  void update(double dt, BattleGame game) {
    age += dt;
    spin += dt * 9;
    if (age >= life) {
      dead = true;
      return;
    }

    // Homing steering keeps the pressure on a moving warrior.
    final Fighter? prey = homing;
    if (prey != null && prey.alive && homingStrength > 0) {
      final Vector2 desired = (prey.position - position)..normalize();
      final Vector2 current = velocity.clone()..normalize();
      final double turn = homingStrength * dt;
      final Vector2 steered = Vector2(
        current.x + (desired.x - current.x) * turn,
        current.y + (desired.y - current.y) * turn,
      )..normalize();
      final double speed = velocity.length;
      velocity.setFrom(steered..scale(speed));
    }

    position.add(velocity.clone()..scale(dt));

    // Walls and world bounds stop the fireball.
    final Size bounds = game.worldSize;
    if (position.x < 0 ||
        position.y < 0 ||
        position.x > bounds.width ||
        position.y > bounds.height) {
      dead = true;
      return;
    }
    for (final ArenaWall wall in game.arena.walls) {
      if (wall.rect.inflate(radius).contains(position.toOffset())) {
        dead = true;
        game.addEffect(
          RingPulse(
            position: position.clone(),
            startRadius: radius,
            endRadius: radius * 3,
            color: color,
            life: 0.3,
          ),
        );
        return;
      }
    }

    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive || fighter.factionId == factionId) {
        continue;
      }
      if (position.distanceTo(fighter.position) <= radius + fighter.radius) {
        fighter.takeDamage(damage, source: owner, label: 'Fire');
        game.addEffect(
          HitSpark(
            position: fighter.position.clone(),
            radius: fighter.radius,
            color: color,
            count: 5,
          ),
        );
        if (burstRadius > 0) {
          game.damageArea(
            center: position.clone(),
            radius: burstRadius,
            damage: burstDamage,
            source: owner,
            label: 'Fire burst',
          );
          game.addEffect(
            RingPulse(
              position: position.clone(),
              startRadius: radius,
              endRadius: burstRadius,
              color: color,
              life: 0.4,
            ),
          );
        }
        dead = true;
        return;
      }
    }
  }

  void render(Canvas canvas) {
    final Offset centre = position.toOffset();
    final Paint paint = Paint()..style = PaintingStyle.fill;
    // Outer glow.
    paint
      ..shader = RadialGradient(
        colors: <Color>[color.withAlpha(200), color.withAlpha(0)],
      ).createShader(Rect.fromCircle(center: centre, radius: radius * 2.6));
    canvas.drawCircle(centre, radius * 2.6, paint);
    // Core.
    paint
      ..shader = null
      ..color = color;
    canvas.drawCircle(centre, radius, paint);
    paint.color = const Color(0xFFFDE68A);
    canvas.drawCircle(centre, radius * 0.5, paint);

    // Little trailing sparks.
    final double angle = math.atan2(velocity.y, velocity.x);
    paint.color = color.withAlpha(140);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        Offset(
          centre.dx - math.cos(angle) * radius * 1.6 * i,
          centre.dy - math.sin(angle) * radius * 1.6 * i,
        ),
        radius * (0.5 - i * 0.1),
        paint,
      );
    }
  }
}
