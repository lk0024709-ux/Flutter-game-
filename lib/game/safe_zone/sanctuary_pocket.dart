import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

/// A sanctuary pocket: a cream circle of pure safety.
///
/// Nothing inside can deal or take damage, which makes it the perfect place to
/// reset a losing fight - if you can reach it before it expires.
class SanctuaryPocket {
  SanctuaryPocket({required this.position});

  static const double radius = 80;
  static const double lifetime = 12.0;

  final Vector2 position;
  double age = 0;

  bool get active => age < lifetime;

  double get remaining => (lifetime - age).clamp(0.0, lifetime);

  double get progress => (age / lifetime).clamp(0.0, 1.0);

  void update(double dt) {
    age += dt;
  }

  void render(Canvas canvas, double elapsed) {
    final Offset centre = position.toOffset();
    final double breathe = 0.9 + 0.1 * math.sin(elapsed * 2.2);
    final Paint paint = Paint()..style = PaintingStyle.fill;

    paint
      ..color = const Color(0xFFF5F1EA).withAlpha(active ? 70 : 30);
    canvas.drawCircle(centre, radius * breathe, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFF5F1EA).withAlpha(active ? 220 : 90);

    // Rotating dashed border.
    const int dashes = 20;
    for (int i = 0; i < dashes; i++) {
      final double start = i * (math.pi * 2 / dashes) + elapsed * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius * breathe),
        start,
        math.pi * 2 / dashes * 0.5,
        false,
        paint,
      );
    }

    // Countdown ring drains clockwise as the pocket expires.
    paint
      ..strokeWidth = 5
      ..color = const Color(0xFFB45309).withAlpha(200);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius * 0.6),
      -math.pi / 2,
      math.pi * 2 * (1 - progress),
      false,
      paint,
    );

    paint.style = PaintingStyle.fill;
  }
}
