import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'creature.dart';
import 'effects.dart';
import 'npc.dart';

/// GRIFFIN - balanced and aggressive.
///
/// Ability: every 4 seconds it flaps its wings and dashes at double speed for
/// half a second (closing the gap before you can react).
class Griffin extends Npc {
  Griffin({
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
  }) : super(type: CreatureType.griffin) {
    abilityTimer = 4.0 * (0.6 + difficulty * 0.04);
  }

  static const double dashInterval = 4.0;
  static const double dashDuration = 0.5;
  static const double dashMultiplier = 2.0;

  double wingPhase = 0;

  @override
  void updateAbility(double dt, BattleGame game) {
    wingPhase += dt * (abilityActive > 0 ? 26 : 9);

    if (abilityActive > 0) {
      abilityActive -= dt;
      abilitySpeedMultiplier = dashMultiplier;
      if (abilityActive <= 0) {
        abilitySpeedMultiplier = 1;
        lockedDirection = null;
        abilityTimer = dashInterval;
      }
      return;
    }

    abilityTimer -= dt;
    if (abilityTimer <= 0 && target != null && target!.alive) {
      final Vector2 delta = target!.position - position;
      if (delta.length > 60) {
        lockedDirection = delta.clone()..normalize();
        abilityActive = dashDuration;
        game.addFloatingText('WING FLAP', position.clone(), const Color(0xFFC2410C), size: 13);
        game.addEffect(
          RingPulse(
            position: position.clone(),
            startRadius: radius * 0.6,
            endRadius: radius * 2.4,
            color: const Color(0xFFC2410C),
            life: 0.35,
          ),
        );
      } else {
        abilityTimer = 1.2;
      }
    }
  }

  @override
  void onDeath(BattleGame game) {
    super.onDeath(game);
    game.addFloatingText('SCREEE', position.clone(), const Color(0xFF8A5A2B), size: 13);
  }

  @override
  void renderBody(Canvas canvas) {
    final double flap = 0.55 + 0.45 * math.sin(wingPhase);
    final Color body = bodyColor;
    final Color accent = accentColor;

    // Wings first so they sit behind the torso.
    final Paint wingPaint = Paint()..color = accent.withAlpha(235);
    for (final int side in <int>[-1, 1]) {
      final Path wing = Path()
        ..moveTo(0, -radius * 0.1)
        ..quadraticBezierTo(
          side * radius * (1.1 + flap * 0.9),
          -radius * (1.5 + flap * 0.7),
          side * radius * (1.9 + flap * 1.1),
          radius * 0.15,
        )
        ..quadraticBezierTo(
          side * radius * 1.25,
          radius * 0.5,
          0,
          radius * 0.35,
        )
        ..close();
      canvas.drawPath(wing, wingPaint);
      canvas.drawPath(
        wing,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x66000000),
      );
    }

    // Torso (lion half).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, radius * 0.1),
        width: radius * 1.75,
        height: radius * 1.5,
      ),
      Paint()..color = body,
    );

    // Facing-dependent head + beak (drawn along +X, the facing axis).
    final Offset head = Offset(radius * 1.0, -radius * 0.15);
    canvas.drawCircle(head, radius * 0.52, Paint()..color = body);
    canvas.drawCircle(head, radius * 0.52, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x55000000));

    final Path beak = Path()
      ..moveTo(head.dx + radius * 0.2, head.dy - radius * 0.18)
      ..lineTo(head.dx + radius * 0.95, head.dy + radius * 0.05)
      ..lineTo(head.dx + radius * 0.2, head.dy + radius * 0.28)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFE8B44A));
    canvas.drawCircle(head.translate(radius * 0.1, -radius * 0.1), radius * 0.1,
        Paint()..color = const Color(0xFF1C1917));

    // Tail tuft.
    final Path tail = Path()
      ..moveTo(-radius * 0.75, radius * 0.1)
      ..quadraticBezierTo(-radius * 1.5, radius * 0.2, -radius * 1.7, -radius * 0.35)
      ..lineTo(-radius * 1.15, -radius * 0.05)
      ..close();
    canvas.drawPath(tail, Paint()..color = accent);

    // Elite crown for elite variants.
    if (eliteVariant || isBoss) {
      canvas.drawCircle(
        head.translate(0, -radius * 0.62),
        radius * 0.2,
        Paint()..color = const Color(0xFFC9A227),
      );
    }
  }
}
