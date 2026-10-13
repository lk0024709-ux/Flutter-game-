import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

/// Base class for short-lived world-space visual effects.
abstract class GameEffect {
  GameEffect({required this.life});

  double age = 0;
  final double life;

  bool get dead => age >= life;

  double get progress => (age / life).clamp(0.0, 1.0);

  void update(double dt) => age += dt;

  void render(Canvas canvas);
}

/// The sword sweep arc played over 0.22 seconds.
class SlashEffect extends GameEffect {
  SlashEffect({
    required this.position,
    required this.facing,
    required this.arc,
    required this.reach,
    this.color = const Color(0xFFF5F1EA),
  }) : super(life: 0.22);

  final Vector2 position;
  final double facing;
  final double arc;
  final double reach;
  final Color color;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final double sweep = arc;
    final double start = facing - sweep / 2 + sweep * t * 0.9;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * (1 - t * 0.4)
      ..strokeCap = StrokeCap.round
      ..color = color.withAlpha(((1 - t) * 190).round());
    canvas.drawArc(
      Rect.fromCircle(center: position.toOffset(), radius: reach * (0.65 + t * 0.35)),
      start,
      sweep * 0.55,
      false,
      paint,
    );
    paint
      ..strokeWidth = 3
      ..color = color.withAlpha(((1 - t) * 110).round());
    canvas.drawArc(
      Rect.fromCircle(center: position.toOffset(), radius: reach * (0.5 + t * 0.4)),
      start,
      sweep * 0.5,
      false,
      paint,
    );
  }
}

/// Bright warm flash drawn over a body that just got hit.
class HitSpark extends GameEffect {
  HitSpark({
    required this.position,
    required this.radius,
    this.color = const Color(0xFFF5F1EA),
    this.count = 6,
  }) : super(life: 0.28);

  final Vector2 position;
  final double radius;
  final Color color;
  final int count;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final Paint paint = Paint()
      ..color = color.withAlpha(((1 - t) * 220).round())
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < count; i++) {
      final double angle = i * (math.pi * 2 / count) + t * 0.6;
      final double inner = radius * (0.4 + t * 0.5);
      final double outer = radius * (0.9 + t * 0.9);
      canvas.drawLine(
        Offset(
          position.x + math.cos(angle) * inner,
          position.y + math.sin(angle) * inner,
        ),
        Offset(
          position.x + math.cos(angle) * outer,
          position.y + math.sin(angle) * outer,
        ),
        paint,
      );
    }
  }
}

/// Floating combat text ("+30", "POISON", "-24").
class FloatingText extends GameEffect {
  FloatingText({
    required this.text,
    required this.position,
    required this.color,
    this.size = 14,
    this.rise = 46,
  }) : super(life: 1.0);

  final String text;
  final Vector2 position;
  final Color color;
  final double size;
  final double rise;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withAlpha(((1 - t) * 255).round()),
          fontSize: size,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        position.x - painter.width / 2,
        position.y - 24 - rise * t,
      ),
    );
  }
}

/// Expanding ring used for merges, shockwaves, phase shifts and spawns.
class RingPulse extends GameEffect {
  RingPulse({
    required this.position,
    required this.startRadius,
    required this.endRadius,
    this.color = const Color(0xFFD97706),
    this.strokeWidth = 4,
    double life = 0.5,
  }) : super(life: life);

  final Vector2 position;
  final double startRadius;
  final double endRadius;
  final Color color;
  final double strokeWidth;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final double radius = startRadius + (endRadius - startRadius) * t;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * (1 - t * 0.6)
      ..color = color.withAlpha(((1 - t) * 200).round());
    canvas.drawCircle(position.toOffset(), radius, paint);
  }
}

/// Telegraph ring that fills up before a hazard fires.
class TelegraphRing extends GameEffect {
  TelegraphRing({
    required this.position,
    required this.radius,
    this.color = const Color(0xFFB45309),
    double life = 1.0,
  }) : super(life: life);

  final Vector2 position;
  final double radius;
  final Color color;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final Paint paint = Paint()..style = PaintingStyle.stroke;
    paint
      ..strokeWidth = 3
      ..color = color.withAlpha(180);
    canvas.drawCircle(position.toOffset(), radius, paint);
    paint
      ..strokeWidth = 8
      ..color = color.withAlpha(90);
    canvas.drawArc(
      Rect.fromCircle(center: position.toOffset(), radius: radius * 0.7),
      -math.pi / 2,
      math.pi * 2 * t,
      false,
      paint,
    );
  }
}

/// Body burst played when a creature dies.
class DeathBurst extends GameEffect {
  DeathBurst({
    required this.position,
    required this.color,
    this.radius = 26,
  }) : super(life: 0.6);

  final Vector2 position;
  final Color color;
  final double radius;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final Paint paint = Paint()..color = color.withAlpha(((1 - t) * 130).round());
    for (int i = 0; i < 9; i++) {
      final double angle = i * 0.698 + t * 1.4;
      final double distance = radius * (0.4 + t * 1.6);
      canvas.drawCircle(
        Offset(
          position.x + math.cos(angle) * distance,
          position.y + math.sin(angle) * distance,
        ),
        (radius * 0.22) * (1 - t),
        paint,
      );
    }
    canvas.drawCircle(
      position.toOffset(),
      radius * (1 - t * 0.3),
      Paint()..color = color.withAlpha(((1 - t) * 60).round()),
    );
  }
}

/// A travelling sword-storm burst (Storm Blade on-hit detonation).
class StormBurst extends GameEffect {
  StormBurst({required this.position, required this.radius})
      : super(life: 0.35);

  final Vector2 position;
  final double radius;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * (1 - t);
    paint.color = const Color(0xFF7E22CE).withAlpha(((1 - t) * 200).round());
    canvas.drawCircle(position.toOffset(), radius * t, paint);
    paint.color = const Color(0xFFF5F1EA).withAlpha(((1 - t) * 150).round());
    for (int i = 0; i < 5; i++) {
      final double angle = i * 1.256 + t * 3;
      canvas.drawLine(
        Offset(
          position.x + math.cos(angle) * radius * 0.3,
          position.y + math.sin(angle) * radius * 0.3,
        ),
        Offset(
          position.x + math.cos(angle) * radius * t,
          position.y + math.sin(angle) * radius * t,
        ),
        paint,
      );
    }
  }
}

/// Sector (cone) effect used by breath attacks and tail swipes.
class ConeSlash extends GameEffect {
  ConeSlash({
    required this.position,
    required this.facing,
    required this.arc,
    required this.reach,
    required this.color,
    double life = 0.3,
  }) : super(life: life);

  final Vector2 position;
  final double facing;
  final double arc;
  final double reach;
  final Color color;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withAlpha(((1 - t) * 120).round());
    final Path cone = Path()
      ..moveTo(position.x, position.y)
      ..arcTo(
        Rect.fromCircle(center: position.toOffset(), radius: reach),
        facing - arc / 2,
        arc,
        false,
      )
      ..close();
    canvas.drawPath(cone, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withAlpha(((1 - t) * 200).round());
    canvas.drawArc(
      Rect.fromCircle(center: position.toOffset(), radius: reach * (0.7 + t * 0.3)),
      facing - arc / 2,
      arc,
      false,
      paint,
    );
  }
}

/// Lingering corpse decal so the arena remembers the fallen.
class CorpseDecal extends GameEffect {
  CorpseDecal({
    required this.position,
    required this.radius,
    required this.color,
  }) : super(life: 14);

  final Vector2 position;
  final double radius;
  final Color color;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final double alpha = (1 - t * 0.75).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: position.toOffset(),
        width: radius * 2.4,
        height: radius * 1.4,
      ),
      Paint()..color = color.withAlpha((alpha * 90).round()),
    );
  }
}
