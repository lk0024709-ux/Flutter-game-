import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

/// One step of the storm-ring schedule.
class StormPhase {
  const StormPhase({
    required this.index,
    required this.radius,
    required this.startTime,
    required this.endTime,
    required this.damagePerSecond,
    required this.label,
    this.randomCenter = false,
  });

  final int index;
  final double radius;
  final double startTime;
  final double endTime;
  final double damagePerSecond;
  final String label;

  /// Phases 4 and 5 move the ring to a random spot inside the old zone.
  final bool randomCenter;

  double get duration => endTime - startTime;
}

/// The battle-royale storm ring.
///
/// Six phases shrink the safe circle from 1200 to 60 units; everybody caught
/// outside takes damage. `shrinkMultiplier` implements the per-map tuning table.
class StormRing {
  StormRing({
    required this.worldSize,
    this.shrinkMultiplier = 1.0,
    this.enabled = true,
  }) {
    center.setFrom(worldCenter);
  }

  static const List<StormPhase> phases = <StormPhase>[
    StormPhase(
      index: 0,
      radius: 1200,
      startTime: 0,
      endTime: 20,
      damagePerSecond: 0,
      label: 'Grace',
    ),
    StormPhase(
      index: 1,
      radius: 900,
      startTime: 20,
      endTime: 45,
      damagePerSecond: 3,
      label: 'Closing',
      randomCenter: false,
    ),
    StormPhase(
      index: 2,
      radius: 600,
      startTime: 45,
      endTime: 75,
      damagePerSecond: 6,
      label: 'Tightening',
    ),
    StormPhase(
      index: 3,
      radius: 350,
      startTime: 75,
      endTime: 105,
      damagePerSecond: 10,
      label: 'Final Circle',
      randomCenter: true,
    ),
    StormPhase(
      index: 4,
      radius: 150,
      startTime: 105,
      endTime: 150,
      damagePerSecond: 18,
      label: 'Collapse',
      randomCenter: true,
    ),
    StormPhase(
      index: 5,
      radius: 60,
      startTime: 150,
      endTime: double.infinity,
      damagePerSecond: 30,
      label: 'Sudden Death',
    ),
  ];

  final Vector2 worldSize;
  final Vector2 center = Vector2.zero();
  final double shrinkMultiplier;
  final bool enabled;

  Vector2 get worldCenter => Vector2(worldSize.x / 2, worldSize.y / 2);

  double radius = phases.first.radius;
  double targetRadius = phases.first.radius;
  int phaseIndex = 0;
  double phaseTimer = 0;
  double damagePerSecond = 0;
  bool suddenDeath = false;

  /// Smooth transitions take this long regardless of the phase length.
  static const double transitionSeconds = 5.0;

  StormPhase get phase => phases[phaseIndex.clamp(0, phases.length - 1)];

  double get secondsToNextPhase {
    final StormPhase current = phase;
    if (current.endTime == double.infinity) {
      return 0;
    }
    final double left = (current.endTime - phaseTimer) / shrinkMultiplier;
    return left < 0 ? 0 : left;
  }

  double get shrinkProgress {
    final StormPhase current = phase;
    if (current.duration == double.infinity) {
      return 1;
    }
    return (phaseTimer * shrinkMultiplier / current.duration).clamp(0.0, 1.0);
  }

  /// Jumps straight to the final phase (used by the `speedrun` modifier).
  void forceSuddenDeath() {
    phaseIndex = phases.length - 1;
    phaseTimer = phases.last.startTime;
    targetRadius = phases.last.radius;
    damagePerSecond = phases.last.damagePerSecond;
    suddenDeath = true;
  }

  void update(double dt, math.Random rng) {
    if (!enabled) {
      return;
    }
    phaseTimer += dt * shrinkMultiplier;
    final StormPhase current = phase;

    if (phaseTimer >= current.endTime && current.endTime != double.infinity) {
      _advance(rng);
    }

    damagePerSecond = current.damagePerSecond;

    // Smoothly ease the radius toward the phase target.
    if ((radius - targetRadius).abs() > 0.5) {
      final double step = (phases[math.min(phaseIndex, phases.length - 1)].radius -
                  targetRadius)
              .abs() /
          transitionSeconds;
      final double move = math.max(step, 20) * dt;
      if (radius > targetRadius) {
        radius = math.max(targetRadius, radius - move);
      } else {
        radius = math.min(targetRadius, radius + move);
      }
    } else {
      radius = targetRadius;
    }
  }

  void _advance(math.Random rng) {
    phaseIndex = (phaseIndex + 1).clamp(0, phases.length - 1);
    final StormPhase next = phase;
    targetRadius = next.radius;
    if (next.randomCenter) {
      // Shift the centre to a random point that is still inside the old ring.
      final double maxOffset = math.max(0.0, radius - next.radius - 60);
      final double angle = rng.nextDouble() * math.pi * 2;
      final double distance = rng.nextDouble() * maxOffset;
      center.setFrom(
        Vector2(math.cos(angle), math.sin(angle))..scale(distance)..add(center),
      );
      center.x = center.x.clamp(next.radius, worldSize.x - next.radius);
      center.y = center.y.clamp(next.radius, worldSize.y - next.radius);
    }
    if (next.index == phases.length - 1) {
      suddenDeath = true;
    }
  }

  bool contains(Vector2 point, {double margin = 0}) =>
      point.distanceTo(center) <= radius + margin;

  /// Draws the translucent outside overlay plus the pulsing dashed border.
  void render(Canvas canvas, double elapsed) {
    if (!enabled) {
      return;
    }
    final Rect world = Rect.fromLTWH(0, 0, worldSize.x, worldSize.y);
    final Color tint;
    if (phaseIndex <= 1) {
      tint = const Color(0xFF64748B).withAlpha((0.12 * 255).round());
    } else if (phaseIndex <= 3) {
      tint = const Color(0xFFD97706).withAlpha((0.15 * 255).round());
    } else {
      tint = const Color(0xFF7C2D12).withAlpha((0.22 * 255).round());
    }

    final Path outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(world),
      Path()..addOval(Rect.fromCircle(center: center.toOffset(), radius: radius)),
    );
    canvas.drawPath(outside, Paint()..color = tint);

    // Dashed border with a slow, subtle pulse.
    final double pulse = 0.5 + 0.5 * math.sin(elapsed * 1.6);
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFFFF7ED).withAlpha((110 + pulse * 90).round());
    const int dashes = 72;
    final double circumference = 2 * math.pi * radius;
    final double dashLength = circumference / dashes * 0.55;
    for (int i = 0; i < dashes; i++) {
      final double start = i * (circumference / dashes) * (1 / radius) + elapsed * 0.05;
      canvas.drawArc(
        Rect.fromCircle(center: center.toOffset(), radius: radius),
        start,
        dashLength / radius,
        false,
        border,
      );
    }
  }
}
