import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../battle_game.dart';
import '../fighter.dart';
import '../levels/level_modifier.dart';
import 'zone_controller.dart';

/// A healing shrine: stand on it for one second and it pours 5 HP/s into you
/// (stacking with armour regeneration). Each fighter has a 15s cooldown and the
/// shrines relocate every 40 seconds.
class HealingShrine {
  HealingShrine({required this.position});

  static const double radius = 120;
  static const double healPerSecond = 5.0;
  static const double chargeSeconds = 1.0;
  static const double cooldownSeconds = 15.0;
  static const double relocateSeconds = 40.0;

  final Vector2 position;
  final Map<int, double> _charge = <int, double>{};
  final Map<int, double> _cooldown = <int, double>{};
  double relocateTimer = relocateSeconds;
  double pulse = 0;
  Fighter? lastUser;

  bool canUse(Fighter fighter) => (_cooldown[fighter.fighterId] ?? 0) <= 0;

  double cooldownLeft(Fighter fighter) => _cooldown[fighter.fighterId] ?? 0;

  /// Charge progress 0..1 for the ring indicator.
  double chargeOf(Fighter fighter) =>
      ((_charge[fighter.fighterId] ?? 0) / chargeSeconds).clamp(0.0, 1.0);

  void update(double dt, BattleGame game, ZoneController zones) {
    pulse += dt;

    // Cooldowns tick down for everyone who ever used this shrine.
    for (final int id in _cooldown.keys.toList()) {
      final double left = (_cooldown[id] ?? 0) - dt;
      if (left <= 0) {
        _cooldown.remove(id);
      } else {
        _cooldown[id] = left;
      }
    }

    if (!zones.enabled) {
      return;
    }

    relocateTimer -= dt;
    if (relocateTimer <= 0) {
      relocateTimer = relocateSeconds;
      final math.Random rng = game.rng;
      final double angle = rng.nextDouble() * math.pi * 2;
      final double distance = rng.nextDouble() * math.max(40.0, zones.radius * 0.6);
      final Vector2 candidate = Vector2(
        zones.center.x + math.cos(angle) * distance,
        zones.center.y + math.sin(angle) * distance,
      );
      position.setFrom(game.arena.randomPointInside(rng, radius, margin: 180));
      // Prefer a spot inside the ring when possible.
      if (candidate.distanceTo(zones.center) < zones.radius - radius) {
        position.setFrom(_clampToWorld(candidate, game));
      }
      _charge.clear();
      _cooldown.clear();
      game.addFloatingText('SHRINE MOVED', position, const Color(0xFF15803D), size: 14);
      return;
    }

    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive) {
        continue;
      }
      final bool inside = fighter.position.distanceTo(position) <= radius;
      if (!inside) {
        if ((_charge[fighter.fighterId] ?? 0) > 0) {
          release(fighter);
        }
        continue;
      }
      if (!canUse(fighter)) {
        continue;
      }
      final double charge = (_charge[fighter.fighterId] ?? 0) + dt;
      _charge[fighter.fighterId] = charge;
      if (charge >= chargeSeconds) {
        // Standing in the light heals; `noHeal` modifiers block it.
        if (!game.modifierActive(LevelModifier.noHeal)) {
          final double multiplier = fighter.isPlayer ? game.healMultiplierForPlayer : 1.0;
          fighter.heal(healPerSecond * multiplier * dt);
          lastUser = fighter;
        }
      }
    }
  }

  /// Applies the 15 second cooldown for a fighter that just left the shrine.
  void release(Fighter fighter) {
    if ((_charge[fighter.fighterId] ?? 0) >= chargeSeconds) {
      _cooldown[fighter.fighterId] = cooldownSeconds;
    }
    _charge[fighter.fighterId] = 0;
  }

  Vector2 _clampToWorld(Vector2 point, BattleGame game) {
    final Size size = game.worldSize;
    return Vector2(
      point.x.clamp(radius + 40, size.width - radius - 40),
      point.y.clamp(radius + 40, size.height - radius - 40),
    );
  }

  void render(Canvas canvas, Fighter? player) {
    final Offset centre = position.toOffset();
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Soft green radial glow.
    paint.shader = RadialGradient(
      colors: <Color>[const Color(0x5515803D), const Color(0x0015803D)],
    ).createShader(Rect.fromCircle(center: centre, radius: radius));
    canvas.drawCircle(centre, radius, paint);
    paint.shader = null;

    // Cream ring, gently pulsing.
    final double pulseAlpha = 0.55 + 0.25 * math.sin(pulse * 2.2);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFFF5F1EA).withAlpha((pulseAlpha * 255).round());
    canvas.drawCircle(centre, radius * 0.78, paint);

    // Inner cross (+).
    paint
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(centre.translate(-16, 0), centre.translate(16, 0), paint);
    canvas.drawLine(centre.translate(0, -16), centre.translate(0, 16), paint);

    // Charge arc for the local player.
    if (player != null && canUse(player)) {
      final double charge = chargeOf(player);
      if (charge > 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFF15803D);
        canvas.drawArc(
          Rect.fromCircle(center: centre, radius: radius * 0.62),
          -math.pi / 2,
          math.pi * 2 * charge,
          false,
          paint,
        );
      }
    }

    // Cooldown dim.
    if (player != null && !canUse(player)) {
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x66000000);
      canvas.drawCircle(centre, radius * 0.78, paint);
    }
    paint.style = PaintingStyle.fill;
  }
}
