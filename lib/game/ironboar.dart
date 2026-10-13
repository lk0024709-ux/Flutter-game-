import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'creature.dart';
import 'effects.dart';
import 'fighter.dart';
import 'npc.dart';

/// IRONBOAR - the charging tank.
///
/// Ability: every 5 seconds it telegraphs for 0.6s (hooves pawing the ground)
/// then charges at 2.5x speed for 1s. A connect deals 30 damage plus heavy
/// knockback.
class Ironboar extends Npc {
  Ironboar({
    required super.fighterId,
    required super.factionId,
    required super.position,
    required super.difficulty,
    super.elite,
    super.mirrorClone,
    super.neutral,
    super.boss,
    super.permanent,
    super.hpOverride,
    super.nameOverride,
    super.bossProfile,
  }) : super(type: CreatureType.ironboar);

  static const double chargeInterval = 5.0;
  static const double chargeTelegraph = 0.6;
  static const double chargeDuration = 1.0;
  static const double chargeMultiplier = 2.5;
  static const double chargeDamage = 30;
  static const double chargeKnockback = 320;

  double _telegraphTimer = 0;
  double shake = 0;
  final Set<int> _gored = <int>{};

  @override
  void updateAbility(double dt, BattleGame game) {

    if (telegraphing) {
      _telegraphTimer -= dt;
      shake = math.sin(game.elapsed * 50) * 3;
      // Wind up: face the target while the ground shakes.
      if (target != null) {
        faceTowards(target!.position - position);
      }
      if (_telegraphTimer <= 0) {
        telegraphing = false;
        shake = 0;
        abilityActive = chargeDuration;
        _gored.clear();
        lockedDirection = target != null
            ? (target!.position - position)..normalize()
            : Vector2(math.cos(facing), math.sin(facing));
        game.addEffect(
          RingPulse(
            position: position.clone(),
            startRadius: radius * 0.6,
            endRadius: radius * 3,
            color: const Color(0xFF44403C),
            life: 0.4,
          ),
        );
        game.addFloatingText('CHARGE!', position.clone(), const Color(0xFF44403C), size: 16);
      }
      return;
    }

    if (abilityActive > 0) {
      abilityActive -= dt;
      abilitySpeedMultiplier = chargeMultiplier;
      for (final Fighter other in game.fighters) {
        if (identical(other, this) || !other.alive || _gored.contains(other.fighterId)) {
          continue;
        }
        if (other is Npc && other.neutral) {
          continue;
        }
        if (position.distanceTo(other.position) <= radius + other.radius) {
          _gored.add(other.fighterId);
          other.takeDamage(chargeDamage * damageScaleFor(difficulty), source: this, label: 'Gore');
          other.applyKnockback(
            lockedDirection ?? Vector2(math.cos(facing), math.sin(facing)),
            chargeKnockback,
          );
          other.applyStun(0.3);
          game.addEffect(
            HitSpark(
              position: other.position.clone(),
              radius: other.radius,
              color: const Color(0xFF44403C),
              count: 7,
            ),
          );
        }
      }
      if (abilityActive <= 0) {
        abilitySpeedMultiplier = 1;
        lockedDirection = null;
        abilityTimer = chargeInterval;
      }
      return;
    }

    abilityTimer -= dt;
    if (abilityTimer <= 0 && target != null && target!.alive) {
      telegraphing = true;
      _telegraphTimer = chargeTelegraph;
      game.addEffect(
        TelegraphRing(
          position: target!.position.clone(),
          radius: (target!.position - position).length.clamp(60.0, 420.0),
          color: const Color(0xFF78350F),
          life: chargeTelegraph,
        ),
      );
    }
  }

  @override
  void renderBody(Canvas canvas) {
    canvas.translate(shake, 0);
    final Color body = bodyColor;
    final Color accent = accentColor;

    // Bristly back.
    final Paint bristle = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = accent;
    for (int i = -3; i <= 3; i++) {
      canvas.drawLine(
        Offset(i * radius * 0.22, -radius * 0.55),
        Offset(i * radius * 0.22 - radius * 0.06, -radius * 0.95),
        bristle,
      );
    }

    // Barrel body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: radius * 2.3, height: radius * 1.55),
        Radius.circular(radius * 0.6),
      ),
      Paint()..color = body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -radius * 0.18),
          width: radius * 1.9,
          height: radius * 0.7,
        ),
        Radius.circular(radius * 0.35),
      ),
      Paint()..color = Color.lerp(body, const Color(0xFFF5F1EA), 0.12)!,
    );

    // Head + snout.
    final Offset head = Offset(radius * 1.15, radius * 0.1);
    canvas.drawCircle(head, radius * 0.55, Paint()..color = body);
    canvas.drawOval(
      Rect.fromCenter(center: head.translate(radius * 0.45, 0), width: radius * 0.7, height: radius * 0.5),
      Paint()..color = Color.lerp(body, const Color(0xFF1C1917), 0.25)!,
    );
    // Nostrils.
    for (final int side in <int>[-1, 1]) {
      canvas.drawCircle(
        head.translate(radius * 0.75, side * radius * 0.12),
        radius * 0.06,
        Paint()..color = const Color(0xFF1C1917),
      );
    }
    // Eyes (red while charging).
    final bool charging = abilityActive > 0 || telegraphing;
    for (final int side in <int>[-1, 1]) {
      canvas.drawCircle(
        head.translate(radius * 0.1, side * radius * 0.28),
        radius * 0.09,
        Paint()
          ..color = charging ? const Color(0xFFB91C1C) : const Color(0xFF1C1917),
      );
    }
    // Tusks.
    for (final int side in <int>[-1, 1]) {
      final Path tusk = Path()
        ..moveTo(head.dx + radius * 0.5, head.dy + side * radius * 0.28)
        ..quadraticBezierTo(
          head.dx + radius * 1.15,
          head.dy + side * radius * 0.5,
          head.dx + radius * 1.3,
          head.dy + side * radius * 0.05,
        )
        ..quadraticBezierTo(
          head.dx + radius * 0.95,
          head.dy + side * radius * 0.32,
          head.dx + radius * 0.5,
          head.dy + side * radius * 0.18,
        )
        ..close();
      canvas.drawPath(tusk, Paint()..color = const Color(0xFFEDE7DB));
    }
    // Legs.
    final Paint legPaint = Paint()
      ..strokeWidth = radius * 0.28
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(body, const Color(0xFF1C1917), 0.35)!;
    for (int i = -1; i <= 1; i += 2) {
      canvas.drawLine(
        Offset(i * radius * 0.6, radius * 0.55),
        Offset(i * radius * 0.6, radius * 0.95),
        legPaint,
      );
      canvas.drawLine(
        Offset(i * radius * 1.0, radius * 0.5),
        Offset(i * radius * 1.0, radius * 0.9),
        legPaint,
      );
    }
    if (eliteVariant || isBoss) {
      canvas.drawCircle(
        Offset(0, -radius * 1.1),
        radius * 0.2,
        Paint()..color = const Color(0xFFC9A227),
      );
    }
  }
}
