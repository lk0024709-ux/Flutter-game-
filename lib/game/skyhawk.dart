import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'creature.dart';
import 'effects.dart';
import 'fighter.dart';
import 'npc.dart';

/// SKYHAWK - the dive bomber.
///
/// Ability: circles its target at 150 units and dives every 3 seconds
/// (3x speed for 0.4s, 18 contact damage).
class Skyhawk extends Npc {
  Skyhawk({
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
  }) : super(type: CreatureType.skyhawk) {
    abilityTimer = 3.0;
  }

  static const double diveInterval = 3.0;
  static const double diveDuration = 0.4;
  static const double diveMultiplier = 3.0;
  static const double diveDamage = 18;

  double wingPhase = 0;
  final Set<int> _hitThisDive = <int>{};

  @override
  void updateAbility(double dt, BattleGame game) {
    wingPhase += dt * (abilityActive > 0 ? 40 : 14);

    if (abilityActive > 0) {
      abilityActive -= dt;
      abilitySpeedMultiplier = diveMultiplier;
      // Contact damage during the dive.
      for (final Fighter other in game.fighters) {
        if (identical(other, this) || !other.alive) {
          continue;
        }
        if (other is Npc && other.neutral) {
          continue;
        }
        if (_hitThisDive.contains(other.fighterId)) {
          continue;
        }
        if (position.distanceTo(other.position) <= radius + other.radius) {
          _hitThisDive.add(other.fighterId);
          other.takeDamage(diveDamage * damageScaleFor(difficulty), source: this, label: 'Dive');
          game.addEffect(
            HitSpark(
              position: other.position.clone(),
              radius: other.radius,
              color: const Color(0xFF92400E),
              count: 5,
            ),
          );
        }
      }
      if (abilityActive <= 0) {
        abilitySpeedMultiplier = 1;
        lockedDirection = null;
        abilityTimer = diveInterval;
        _hitThisDive.clear();
      }
      return;
    }

    if (telegraphing) {
      telegraphing = false;
    }

    abilityTimer -= dt;
    if (abilityTimer <= 0 && target != null && target!.alive) {
      final Vector2 aim = predictedTargetPosition() - position;
      if (aim.length2 > 0.01) {
        lockedDirection = aim..normalize();
        abilityActive = diveDuration;
        game.addEffect(
          TelegraphRing(
            position: target!.position.clone(),
            radius: target!.radius * 2.2,
            color: const Color(0xFF92400E),
            life: 0.35,
          ),
        );
      } else {
        abilityTimer = 0.6;
      }
    }
  }

  @override
  void renderBody(Canvas canvas) {
    final double flap = math.sin(wingPhase);
    final Color body = bodyColor;
    final Color accent = accentColor;

    // Swept wings.
    final Paint wingPaint = Paint()..color = accent;
    for (final int side in <int>[-1, 1]) {
      final Path wing = Path()
        ..moveTo(-radius * 0.2, 0)
        ..quadraticBezierTo(
          side * radius * 0.9,
          side * (radius * (1.5 + flap * 0.4)),
          side * radius * 2.4,
          side * radius * 0.25,
        )
        ..quadraticBezierTo(
          side * radius * 0.9,
          side * radius * 0.55,
          -radius * 0.2,
          side * radius * 0.35,
        )
        ..close();
      canvas.drawPath(wing, wingPaint);
    }

    // Streamlined body.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.1,
        height: radius * 1.05,
      ),
      Paint()..color = body,
    );

    // Head + hooked beak.
    final Offset head = Offset(radius * 1.05, 0);
    canvas.drawCircle(head, radius * 0.45, Paint()..color = body);
    final Path beak = Path()
      ..moveTo(head.dx + radius * 0.15, head.dy - radius * 0.12)
      ..lineTo(head.dx + radius * 0.72, head.dy + radius * 0.02)
      ..lineTo(head.dx + radius * 0.18, head.dy + radius * 0.2)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFE8B44A));
    canvas.drawCircle(
      head.translate(radius * 0.08, -radius * 0.12),
      radius * 0.08,
      Paint()..color = const Color(0xFF1C1917),
    );

    // Tail feathers.
    for (int i = -1; i <= 1; i++) {
      final Path feather = Path()
        ..moveTo(-radius * 0.85, 0)
        ..lineTo(-radius * 1.8, i * radius * 0.45)
        ..lineTo(-radius * 0.8, i * radius * 0.18)
        ..close();
      canvas.drawPath(feather, Paint()..color = accent.withAlpha(220));
    }

    if (abilityActive > 0) {
      canvas.drawCircle(
        Offset.zero,
        radius * 1.5,
        Paint()..color = const Color(0x33FFFFFF),
      );
    }
    if (eliteVariant || isBoss) {
      canvas.drawCircle(
        Offset(0, -radius * 0.8),
        radius * 0.18,
        Paint()..color = const Color(0xFFC9A227),
      );
    }
  }
}
