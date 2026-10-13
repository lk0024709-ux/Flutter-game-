import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'creature.dart';
import 'effects.dart';
import 'fighter.dart';
import 'npc.dart';
import 'poison_effect.dart';

/// VENOMTAIL - the poison assassin.
///
/// Ability: every bite injects a poison stack. Five stacks tick 2 HP/s each for
/// four seconds and the timer refreshes on every new hit.
class Venomtail extends Npc {
  Venomtail({
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
  }) : super(type: CreatureType.venomtail);

  double hiss = 0;
  double _auraTimer = 0;

  @override
  void updateAbility(double dt, BattleGame game) {
    hiss = math.max(0.0, hiss - dt * 1.5);

    // Elite venomtails leave a poison trail, which punishes corner camping.
    _auraTimer -= dt;
    if (_auraTimer <= 0 && (eliteVariant || isBoss)) {
      _auraTimer = 2.0;
      for (final Fighter other in game.fighters) {
        if (identical(other, this) || !other.alive) {
          continue;
        }
        if (position.distanceTo(other.position) < 120) {
          PoisonEffect.apply(other, game: game);
        }
      }
      game.addEffect(
        RingPulse(
          position: position.clone(),
          startRadius: radius * 0.8,
          endRadius: 120,
          color: const Color(0xFF4D7C0F),
          life: 0.6,
        ),
      );
    }
  }

  @override
  void attack(Fighter victim, BattleGame game) {
    hiss = 1;
    biteWithPoison(victim, game);
    game.addEffect(
      HitSpark(
        position: victim.position.clone(),
        radius: victim.radius,
        color: const Color(0xFF4D7C0F),
        count: 3,
      ),
    );
  }

  @override
  void renderBody(Canvas canvas) {
    final Color body = bodyColor;
    final Color accent = accentColor;

    // Coiled body: three arcs of decreasing radius.
    final Paint bodyPaint = Paint()..color = body;
    final Paint bellyPaint = Paint()
      ..color = accent.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.22;
    for (int i = 0; i < 4; i++) {
      final double t = i / 4.0;
      final double ringRadius = radius * (0.95 - t * 0.42);
      final Offset centre = Offset(-radius * (0.15 + t * 0.35), radius * (0.1 + t * 0.25));
      canvas.drawCircle(centre, ringRadius, bodyPaint);
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: ringRadius * 0.75),
        -math.pi / 3,
        math.pi * 0.9,
        false,
        bellyPaint,
      );
    }

    // Neck rising to the head.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(radius * 0.35, -radius * 0.35),
        width: radius * 1.0,
        height: radius * 0.75,
      ),
      bodyPaint,
    );

    // Head (facing +X) with a flared hood.
    final Offset head = Offset(radius * 1.0, -radius * 0.55);
    final Path hood = Path()
      ..moveTo(head.dx - radius * 0.6, head.dy)
      ..quadraticBezierTo(head.dx - radius * 0.1, head.dy - radius * 1.0, head.dx + radius * 0.45, head.dy - radius * 0.35)
      ..quadraticBezierTo(head.dx - radius * 0.05, head.dy + radius * 0.55, head.dx - radius * 0.6, head.dy)
      ..close();
    canvas.drawPath(hood, Paint()..color = body);
    canvas.drawOval(
      Rect.fromCenter(center: head, width: radius * 0.9, height: radius * 0.5),
      Paint()..color = Color.lerp(body, const Color(0xFF1C1917), 0.15)!,
    );
    // Eyes.
    for (final int side in <int>[-1, 1]) {
      canvas.drawCircle(
        head.translate(radius * 0.22, side * radius * 0.12),
        radius * 0.06,
        Paint()..color = const Color(0xFFFACC15),
      );
    }
    // Flicking tongue.
    if (hiss > 0) {
      final Path tongue = Path()
        ..moveTo(head.dx + radius * 0.45, head.dy)
        ..lineTo(head.dx + radius * (0.9 + hiss * 0.5), head.dy - radius * 0.08)
        ..lineTo(head.dx + radius * 0.45, head.dy + radius * 0.04)
        ..close();
      canvas.drawPath(tongue, Paint()..color = const Color(0xFFB91C1C));
    }
    // Rattling tail tip.
    final double rattle = math.sin(hiss * 20 * math.pi) * radius * 0.16;
    canvas.drawCircle(
      Offset(-radius * 1.35 + rattle, radius * 0.75),
      radius * 0.2,
      Paint()..color = const Color(0xFFA16207),
    );
    // Poison drip while stacking.
    if (poisonStacks > 0) {
      canvas.drawCircle(
        Offset(radius * 0.9, -radius * 0.1),
        radius * 0.09,
        Paint()..color = const Color(0xFF4D7C0F),
      );
    }
    if (eliteVariant || isBoss) {
      canvas.drawCircle(
        Offset(0, -radius * 1.15),
        radius * 0.18,
        Paint()..color = const Color(0xFFC9A227),
      );
    }
  }
}
