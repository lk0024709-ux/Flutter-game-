import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'creature.dart';
import 'effects.dart';
import 'fighter.dart';
import 'fire_projectile.dart';
import 'npc.dart';

/// DRAKE - ranged fire breather.
///
/// Ability: keeps its distance at 180 units and breathes a fire projectile
/// (12 damage, 400 units/second). It never commits to melee.
class Drake extends Npc {
  Drake({
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
  }) : super(type: CreatureType.drake);

  static const double fireDamage = 12;
  static const double fireSpeed = 400;

  double glow = 0;
  double _volleyTimer = 0;

  @override
  void updateAbility(double dt, BattleGame game) {
    glow = math.max(0.0, glow - dt * 2);
    _volleyTimer -= dt;
  }

  @override
  void attack(Fighter victim, BattleGame game) {
    final Vector2 delta = victim.position - position;
    final double distance = delta.length;
    if (distance > type.reach) {
      return;
    }
    glow = 1;
    breatheFire(victim, game, damage: fireDamage * damageScaleFor(difficulty), speed: fireSpeed);
    game.addEffect(
      RingPulse(
        position: position.clone(),
        startRadius: radius * 0.4,
        endRadius: radius * 1.3,
        color: const Color(0xFFB45309),
        life: 0.3,
      ),
    );
  }

  /// Bosses breathe three fireballs in a spread.
  void breatheVolley(BattleGame game, Fighter victim) {
    final Vector2 base = victim.position - position;
    if (base.length2 < 0.001) {
      return;
    }
    final double angle = math.atan2(base.y, base.x);
    for (int i = -1; i <= 1; i++) {
      final double spread = angle + i * 0.22;
      game.projectiles.add(
        FireProjectile(
          position: position.clone(),
          velocity: Vector2(math.cos(spread), math.sin(spread))..scale(fireSpeed * 0.9),
          damage: fireDamage * damageScaleFor(difficulty) * 1.4,
          factionId: factionId,
          owner: this,
          radius: 10,
          homing: victim,
        ),
      );
    }
  }

  @override
  void renderBody(Canvas canvas) {
    final Color body = bodyColor;
    final Color accent = accentColor;

    // Tail.
    final Path tail = Path()
      ..moveTo(-radius * 0.6, 0)
      ..quadraticBezierTo(-radius * 1.6, radius * 0.5, -radius * 2.1, -radius * 0.1)
      ..lineTo(-radius * 0.6, -radius * 0.35)
      ..close();
    canvas.drawPath(tail, Paint()..color = accent);

    // Serpentine body.
    final Path bodyPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2.3,
          height: radius * 1.35,
        ),
      );
    canvas.drawPath(bodyPath, Paint()..color = body);

    // Folded wings.
    final Paint wingPaint = Paint()..color = accent.withAlpha(200);
    for (final int side in <int>[-1, 1]) {
      final Path wing = Path()
        ..moveTo(-radius * 0.1, side * radius * 0.25)
        ..quadraticBezierTo(
          -radius * 0.9,
          side * radius * 1.35,
          radius * 0.55,
          side * radius * 0.75,
        )
        ..close();
      canvas.drawPath(wing, wingPaint);
    }

    // Head (facing +X).
    final Offset head = Offset(radius * 1.25, 0);
    canvas.drawOval(
      Rect.fromCenter(center: head, width: radius * 0.95, height: radius * 0.7),
      Paint()..color = body,
    );
    // Snout glow while breathing fire.
    canvas.drawCircle(
      head.translate(radius * 0.45, 0),
      radius * (0.18 + glow * 0.28),
      Paint()..color = Color(0xFFEA580C).withAlpha((120 + glow * 135).round()),
    );
    // Horns.
    for (final int side in <int>[-1, 1]) {
      final Path horn = Path()
        ..moveTo(head.dx - radius * 0.1, head.dy + side * radius * 0.16)
        ..lineTo(head.dx - radius * 0.55, head.dy + side * radius * 0.62)
        ..lineTo(head.dx - radius * 0.02, head.dy + side * radius * 0.28)
        ..close();
      canvas.drawPath(horn, Paint()..color = const Color(0xFFE7E1D3));
    }
    // Eye.
    canvas.drawCircle(
      head.translate(radius * 0.12, -radius * 0.16),
      radius * 0.09,
      Paint()..color = const Color(0xFFFFF7ED),
    );
    // Dorsal spines.
    for (int i = -1; i <= 1; i++) {
      final Path spine = Path()
        ..moveTo(i * radius * 0.5 - radius * 0.14, -radius * 0.62)
        ..lineTo(i * radius * 0.5, -radius * 1.05)
        ..lineTo(i * radius * 0.5 + radius * 0.14, -radius * 0.62)
        ..close();
      canvas.drawPath(spine, Paint()..color = accent);
    }
    if (eliteVariant || isBoss) {
      canvas.drawCircle(
        Offset(0, -radius * 1.2),
        radius * 0.2,
        Paint()..color = const Color(0xFFC9A227),
      );
    }
  }
}
