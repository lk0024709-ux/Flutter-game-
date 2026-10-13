import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'fighter.dart';
import 'game_map.dart';

/// Types of interactive arena geometry.
enum HazardKind {
  lava,
  geyser,
  lightning,
  icePatch,
  heatZone,
  crystal,
  treasureShrine,
  generic,
}

/// Types of decorative scenery (blocking ones double as obstacles).
enum DecorKind {
  shrub,
  bone,
  rock,
  pine,
  pond,
  column,
  crystalSpike,
  platform,
  constellation,
  marblePillar,
  goldVein,
}

/// A circular arena feature that can damage, slow or absorb fighters.
class ArenaHazard {
  ArenaHazard({
    required this.kind,
    required this.position,
    required this.radius,
    this.damagePerSecond = 0,
    this.telegraphSeconds = 0,
    this.oneShotDamage = 0,
    this.knockback = 0,
    this.life = double.infinity,
    this.label = '',
    double hp = 0,
    this.owner = 'map',
  })  : hp = hp,
        _initialHp = hp;

  final HazardKind kind;
  final Vector2 position;
  double radius;

  /// Continuous damage while a fighter stands inside.
  final double damagePerSecond;

  /// Seconds of warning before a one-shot hazard fires.
  final double telegraphSeconds;

  /// Damage applied once when the telegraph completes.
  final double oneShotDamage;

  /// Knockback impulse applied with the one-shot damage.
  final double knockback;

  /// Lifetime in seconds (infinite for lava pools and ice).
  final double life;

  final String label;

  /// Destroyable hazards (crystals) start above zero.
  double hp;

  final String owner;

  double age = 0;
  bool triggered = false;
  bool destroyed = false;

  /// True when this hazard can be destroyed by sword hits (crystals).
  bool get hasHealth => _initialHp > 0;
  final double _initialHp;

  bool get expired => age >= life || destroyed;

  bool get isTelegraphing => age < telegraphSeconds;

  double get telegraphProgress =>
      telegraphSeconds <= 0 ? 1.0 : (age / telegraphSeconds).clamp(0.0, 1.0);
}

/// A sliding wall on a rail (Jade Temple).
class ArenaWall {
  ArenaWall({
    required this.origin,
    required this.position,
    required this.size,
    required this.axis,
    required this.speed,
    required this.travel,
    required this.owner,
  });

  final Vector2 origin;
  final Vector2 position;
  final Vector2 size;
  final Vector2 axis;
  final double speed;
  final double travel;
  final String owner;

  double progress = 0;
  double direction = 1;

  void update(double dt) {
    progress += speed * direction * dt;
    if (progress > travel) {
      progress = travel;
      direction = -1;
    } else if (progress < 0) {
      progress = 0;
      direction = 1;
    }
    position
      ..setFrom(origin)
      ..add(axis.clone()..scale(progress));
  }

  Rect get rect => Rect.fromCenter(
        center: position.toOffset(),
        width: size.x,
        height: size.y,
      );

  /// Pushes a circular fighter out of the wall.
  void resolve(Fighter fighter) {
    final Rect r = rect;
    final double left = r.left - fighter.radius;
    final double right = r.right + fighter.radius;
    final double top = r.top - fighter.radius;
    final double bottom = r.bottom + fighter.radius;
    final double px = fighter.position.x;
    final double py = fighter.position.y;
    if (px > left && px < right && py > top && py < bottom) {
      // Choose the cheapest axis to escape along.
      final double dxLeft = (px - left).abs();
      final double dxRight = (right - px).abs();
      final double dyTop = (py - top).abs();
      final double dyBottom = (bottom - py).abs();
      final double min = math.min(math.min(dxLeft, dxRight), math.min(dyTop, dyBottom));
      if (min == dxLeft) {
        fighter.position.x = left;
      } else if (min == dxRight) {
        fighter.position.x = right;
      } else if (min == dyTop) {
        fighter.position.y = top;
      } else {
        fighter.position.y = bottom;
      }
      fighter.velocity.scale(0.4);
    }
  }
}

/// Static scenery piece. Blocking pieces push fighters out.
class ArenaObstacle {
  ArenaObstacle({
    required this.kind,
    required this.position,
    required this.radius,
    required this.blocking,
    this.rotation = 0,
    this.scale = 1,
  });

  final DecorKind kind;
  final Vector2 position;
  final double radius;
  final bool blocking;
  final double rotation;
  final double scale;
}

/// Procedurally generated battlefield: floor, scenery, hazards and walls.
class Arena {
  Arena({required this.map, required int seed})
      : worldSize = Vector2.all(map.worldSize),
        _rng = math.Random(seed) {
    _generate();
  }

  final GameMapDef map;
  final Vector2 worldSize;
  final math.Random _rng;

  final List<ArenaObstacle> obstacles = <ArenaObstacle>[];
  final List<ArenaHazard> hazards = <ArenaHazard>[];
  final List<ArenaWall> walls = <ArenaWall>[];

  // ------------------------------------------------------------------ layout

  void _generate() {
    final double w = worldSize.x;
    final double h = worldSize.y;
    switch (map.decorStyle) {
      case MapDecorStyle.dust:
        _scatter(DecorKind.shrub, 22, 0.24, 0.9, blocking: false);
        _scatter(DecorKind.bone, 16, 0.4, 0.4, blocking: false);
        for (int i = 1; i < 6; i++) {
          obstacles.add(ArenaObstacle(
            kind: DecorKind.goldVein,
            position: Vector2(w * (i / 6.0), h * 0.5),
            radius: 2,
            blocking: false,
            rotation: 0.12,
          ));
        }
        break;
      case MapDecorStyle.snow:
        _scatter(DecorKind.pine, 20, 0.3, 1.0, blocking: true);
        _scatter(DecorKind.pond, 8, 0.5, 0.6, blocking: false);
        _scatter(DecorKind.rock, 12, 0.4, 0.5, blocking: true);
        break;
      case MapDecorStyle.volcanic:
        _scatter(DecorKind.rock, 26, 0.7, 1.2, blocking: true);
        _scatter(DecorKind.bone, 8, 0.35, 0.35, blocking: false);
        break;
      case MapDecorStyle.jade:
        _scatter(DecorKind.column, 14, 0.3, 0.75, blocking: true);
        _scatter(DecorKind.goldVein, 18, 0.5, 0.5, blocking: false);
        break;
      case MapDecorStyle.crystal:
        _scatter(DecorKind.crystalSpike, 26, 1.1, 1.4, blocking: true);
        _scatter(DecorKind.rock, 12, 0.4, 0.5, blocking: false);
        break;
      case MapDecorStyle.storm:
        _scatter(DecorKind.platform, 14, 1.2, 1.7, blocking: false);
        _scatter(DecorKind.rock, 10, 0.4, 0.5, blocking: true);
        break;
      case MapDecorStyle.cosmic:
        _scatter(DecorKind.marblePillar, 12, 0.3, 0.9, blocking: true);
        _scatter(DecorKind.constellation, 16, 2.0, 2.6, blocking: false);
        break;
    }
  }

  void _scatter(
    DecorKind kind,
    int count,
    double minScale,
    double maxScale, {
    required bool blocking,
  }) {
    for (int i = 0; i < count; i++) {
      final double x = 140 + _rng.nextDouble() * (worldSize.x - 280);
      final double y = 140 + _rng.nextDouble() * (worldSize.y - 280);
      // Keep the exact centre clear so the player spawn is fair.
      if (Vector2(x, y).distanceTo(Vector2(worldSize.x / 2, worldSize.y / 2)) < 200) {
        continue;
      }
      final double scale = minScale + _rng.nextDouble() * (maxScale - minScale);
      obstacles.add(ArenaObstacle(
        kind: kind,
        position: Vector2(x, y),
        radius: (blocking ? 22 : 14) * scale,
        blocking: blocking,
        rotation: _rng.nextDouble() * math.pi * 2,
        scale: scale,
      ));
    }
  }

  /// A random point inside the playable area.
  Vector2 randomPointInside(math.Random rng, double radius, {double margin = 140}) {
    final double m = margin + radius;
    final double x = m + rng.nextDouble() * (worldSize.x - m * 2).clamp(1, worldSize.x);
    final double y = m + rng.nextDouble() * (worldSize.y - m * 2).clamp(1, worldSize.y);
    return Vector2(x, y);
  }

  void addHazard(ArenaHazard hazard) => hazards.add(hazard);

  void addWall(ArenaWall wall) => walls.add(wall);

  void removeHazardsByOwner(String owner) {
    hazards.removeWhere((ArenaHazard h) => h.owner == owner);
  }

  void removeWallsByOwner(String owner) {
    walls.removeWhere((ArenaWall w) => w.owner == owner);
  }

  ArenaHazard? nearestDamagedHazard(Vector2 point, double radius) {
    ArenaHazard? best;
    double bestDistance = double.infinity;
    for (final ArenaHazard hazard in hazards) {
      if (!hazard.hasHealth || hazard.destroyed) {
        continue;
      }
      final double distance = hazard.position.distanceTo(point);
      if (distance <= radius + hazard.radius && distance < bestDistance) {
        best = hazard;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Damages a destructible hazard; returns true when it shattered.
  bool damageHazard(ArenaHazard hazard, double amount, BattleGame game) {
    if (!hazard.hasHealth || hazard.destroyed) {
      return false;
    }
    hazard.hp -= amount;
    if (hazard.hp <= 0) {
      hazard.destroyed = true;
      game.onHazardDestroyed(hazard);
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------------ update

  void update(double dt, BattleGame game) {
    for (final ArenaWall wall in walls) {
      wall.update(dt);
    }

    for (final ArenaHazard hazard in hazards) {
      hazard.age += dt;

      if (hazard.hasHealth && hazard.hp <= 0) {
        hazard.destroyed = true;
        continue;
      }

      if (hazard.oneShotDamage > 0 && !hazard.triggered && hazard.age >= hazard.telegraphSeconds) {
        hazard.triggered = true;
        game.damageArea(
          center: hazard.position.clone(),
          radius: hazard.radius,
          damage: hazard.oneShotDamage,
          label: hazard.label,
        );
        if (hazard.knockback > 0) {
          game.pushArea(
            center: hazard.position.clone(),
            radius: hazard.radius,
            force: hazard.knockback,
          );
        }
      }

      if (hazard.damagePerSecond > 0 && hazard.age >= hazard.telegraphSeconds) {
        game.damageArea(
          center: hazard.position.clone(),
          radius: hazard.radius,
          damage: hazard.damagePerSecond * dt,
          label: hazard.label,
          continuous: true,
        );
      }
    }
    hazards.removeWhere((ArenaHazard h) => h.expired);
  }

  // --------------------------------------------------------------- collision

  /// Clamps a fighter inside the world and resolves obstacle/wall collisions.
  void resolve(Fighter fighter) {
    const double padding = 26;
    fighter.position.x = fighter.position.x.clamp(padding, worldSize.x - padding);
    fighter.position.y = fighter.position.y.clamp(padding, worldSize.y - padding);

    for (final ArenaObstacle obstacle in obstacles) {
      if (!obstacle.blocking) {
        continue;
      }
      final Vector2 delta = fighter.position - obstacle.position;
      final double minDistance = obstacle.radius * 1.35 + fighter.radius;
      final double distance = delta.length;
      if (distance < minDistance && distance > 0.0001) {
        final Vector2 push = delta.clone()..scale(minDistance / distance);
        fighter.position
          ..setFrom(obstacle.position)
          ..add(push);
        fighter.velocity.scale(0.5);
      }
    }

    for (final ArenaWall wall in walls) {
      wall.resolve(fighter);
    }
  }

  // ---------------------------------------------------------------- painting

  void renderFloor(Canvas canvas, BattleGame game) {
    final Rect bounds = Rect.fromLTWH(0, 0, worldSize.x, worldSize.y);
    canvas.drawRect(bounds, Paint()..color = Color(map.floorColor));

    // Soft accent patches give the floor an organic, hand-painted feel.
    final Paint patch = Paint()..color = Color(map.floorAccent).withAlpha(150);
    final math.Random rng = math.Random(map.id.hashCode & 0xFFFF);
    for (int i = 0; i < 26; i++) {
      final double x = rng.nextDouble() * worldSize.x;
      final double y = rng.nextDouble() * worldSize.y;
      final double radius = 60 + rng.nextDouble() * 170;
      canvas.drawCircle(Offset(x, y), radius, patch);
    }

    // Grid seams - skipped for organic floors.
    if (map.decorStyle != MapDecorStyle.dust && map.decorStyle != MapDecorStyle.cosmic) {
      final Paint grid = Paint()
        ..color = Color(map.decorColor).withAlpha(28)
        ..strokeWidth = 2;
      const double step = 300;
      for (double x = step; x < worldSize.x; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, worldSize.y), grid);
      }
      for (double y = step; y < worldSize.y; y += step) {
        canvas.drawLine(Offset(0, y), Offset(worldSize.x, y), grid);
      }
    }

    // Arena frame.
    canvas.drawRect(
      bounds.deflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = Color(map.decorColor).withAlpha(90),
    );
  }

  void renderHazards(Canvas canvas, BattleGame game) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (final ArenaHazard hazard in hazards) {
      switch (hazard.kind) {
        case HazardKind.lava:
          paint.color = const Color(0xFFB4430F).withAlpha(200);
          canvas.drawCircle(hazard.position.toOffset(), hazard.radius, paint);
          break;
        case HazardKind.geyser:
          final double t = hazard.telegraphProgress;
          paint.color = const Color(0xFFEA580C).withAlpha((40 + t * 120).round());
          canvas.drawCircle(hazard.position.toOffset(), hazard.radius * (0.4 + t * 0.6), paint);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFB45309).withAlpha(220);
          canvas.drawCircle(hazard.position.toOffset(), hazard.radius, paint);
          paint.style = PaintingStyle.fill;
          if (hazard.triggered) {
            paint.color = const Color(0xFFEA580C).withAlpha(170);
            canvas.drawCircle(hazard.position.toOffset(), hazard.radius * 0.7, paint);
          }
          break;
        case HazardKind.lightning:
          final double t = hazard.telegraphProgress;
          paint.color = const Color(0xFF64748B).withAlpha((50 + t * 110).round());
          canvas.drawCircle(hazard.position.toOffset(), hazard.radius * (0.5 + t * 0.5), paint);
          break;
        case HazardKind.icePatch:
          paint.color = const Color(0x55DCEBF5);
          canvas.drawCircle(hazard.position.toOffset(), hazard.radius, paint);
          break;
        case HazardKind.heatZone:
          final Paint glow = Paint()
            ..shader = RadialGradient(
              colors: <Color>[const Color(0x44D97706), const Color(0x00D97706)],
            ).createShader(Rect.fromCircle(center: hazard.position.toOffset(), radius: hazard.radius));
          canvas.drawCircle(hazard.position.toOffset(), hazard.radius, glow);
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0x88D97706);
          canvas.drawCircle(hazard.position.toOffset(), hazard.radius, paint);
          paint.style = PaintingStyle.fill;
          break;
        case HazardKind.crystal:
        case HazardKind.treasureShrine:
        case HazardKind.generic:
          break;
      }
    }
  }

  void renderDecor(Canvas canvas, BattleGame game) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (final ArenaObstacle obstacle in obstacles) {
      _drawObstacle(canvas, obstacle, paint);
    }
  }

  void _drawObstacle(Canvas canvas, ArenaObstacle obstacle, Paint paint) {
    final double x = obstacle.position.x;
    final double y = obstacle.position.y;
    final double s = obstacle.scale;
    final Color tint = Color(map.decorColor);

    switch (obstacle.kind) {
      case DecorKind.shrub:
        paint
          ..color = tint.withAlpha(180)
          ..strokeWidth = 2.4 * s
          ..style = PaintingStyle.stroke;
        for (int i = 0; i < 5; i++) {
          final double angle = obstacle.rotation + i * 1.32;
          canvas.drawLine(
            Offset(x, y),
            Offset(x + math.cos(angle) * 22 * s, y + math.sin(angle) * 22 * s - 8 * s),
            paint,
          );
        }
        paint.style = PaintingStyle.fill;
        break;
      case DecorKind.bone:
        paint
          ..color = const Color(0xFFEFE9DA).withAlpha(210)
          ..strokeWidth = 5 * s;
        canvas.drawLine(Offset(x - 16 * s, y), Offset(x + 16 * s, y), paint);
        canvas.drawCircle(Offset(x - 17 * s, y), 5 * s, paint);
        canvas.drawCircle(Offset(x + 17 * s, y), 5 * s, paint);
        break;
      case DecorKind.rock:
        final Path rock = Path()
          ..moveTo(x - 20 * s, y + 12 * s)
          ..lineTo(x - 10 * s, y - 14 * s)
          ..lineTo(x + 8 * s, y - 18 * s)
          ..lineTo(x + 21 * s, y + 4 * s)
          ..lineTo(x + 10 * s, y + 15 * s)
          ..close();
        paint.color = tint.withAlpha(235);
        canvas.drawPath(rock, paint);
        paint.color = const Color(0x33000000);
        canvas.drawPath(
          Path()
            ..moveTo(x - 20 * s, y + 12 * s)
            ..lineTo(x + 10 * s, y + 15 * s)
            ..lineTo(x + 21 * s, y + 4 * s)
            ..close(),
          paint,
        );
        break;
      case DecorKind.pine:
        paint.color = const Color(0xFF2F4F3A);
        for (int i = 0; i < 3; i++) {
          final double top = y - 40 * s + i * 12 * s;
          canvas.drawPath(
            Path()
              ..moveTo(x, top - 18 * s)
              ..lineTo(x + 18 * s, top + 12 * s)
              ..lineTo(x - 18 * s, top + 12 * s)
              ..close(),
            paint,
          );
        }
        paint.color = const Color(0xFF4A3728);
        canvas.drawRect(
          Rect.fromLTWH(x - 4 * s, y + 6 * s, 8 * s, 14 * s),
          paint,
        );
        break;
      case DecorKind.pond:
        paint.color = const Color(0xFFAFCBDD).withAlpha(200);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 90 * s, height: 60 * s),
          paint,
        );
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x66FFFFFF);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 78 * s, height: 48 * s),
          paint,
        );
        paint.style = PaintingStyle.fill;
        break;
      case DecorKind.column:
        paint.color = const Color(0xFF8FA88F);
        canvas.drawRect(Rect.fromLTWH(x - 16 * s, y - 44 * s, 32 * s, 60 * s), paint);
        paint.color = const Color(0xFFB7CDB7);
        canvas.drawRect(Rect.fromLTWH(x - 22 * s, y - 52 * s, 44 * s, 12 * s), paint);
        canvas.drawRect(Rect.fromLTWH(x - 22 * s, y + 10 * s, 44 * s, 12 * s), paint);
        break;
      case DecorKind.crystalSpike:
        final Path spike = Path()
          ..moveTo(x, y - 40 * s)
          ..lineTo(x + 18 * s, y)
          ..lineTo(x, y + 22 * s)
          ..lineTo(x - 18 * s, y)
          ..close();
        paint.color = const Color(0xFF8B74C9);
        canvas.drawPath(spike, paint);
        paint.color = const Color(0xFFB9A8E8).withAlpha(220);
        canvas.drawPath(
          Path()
            ..moveTo(x, y - 40 * s)
            ..lineTo(x + 18 * s, y)
            ..lineTo(x, y)
            ..close(),
          paint,
        );
        break;
      case DecorKind.platform:
        final Rect rect =
            Rect.fromCenter(center: Offset(x, y), width: 150 * s, height: 90 * s);
        paint.color = const Color(0x33000000);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.translate(6, 10), const Radius.circular(14)),
          paint,
        );
        paint.color = const Color(0xFF6E7681);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), paint);
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x66E2E8F0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(10), const Radius.circular(10)),
          paint,
        );
        paint.style = PaintingStyle.fill;
        break;
      case DecorKind.constellation:
        paint.color = const Color(0xFFC9A227).withAlpha(150);
        for (int i = 0; i < 5; i++) {
          final double angle = obstacle.rotation + i * 1.26;
          canvas.drawCircle(
            Offset(x + math.cos(angle) * 40 * s, y + math.sin(angle) * 40 * s),
            3.2 * s,
            paint,
          );
        }
        paint
          ..strokeWidth = 1.4
          ..color = const Color(0xFFC9A227).withAlpha(70);
        canvas.drawCircle(Offset(x, y), 40 * s, paint..style = PaintingStyle.stroke);
        paint.style = PaintingStyle.fill;
        break;
      case DecorKind.marblePillar:
        paint.color = const Color(0xFF1B1817);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 20 * s, y - 70 * s, 40 * s, 96 * s),
            const Radius.circular(6),
          ),
          paint,
        );
        paint.color = Color(map.decorColor).withAlpha(200);
        canvas.drawRect(Rect.fromLTWH(x - 24 * s, y - 76 * s, 48 * s, 10 * s), paint);
        canvas.drawRect(Rect.fromLTWH(x - 24 * s, y + 20 * s, 48 * s, 10 * s), paint);
        break;
      case DecorKind.goldVein:
        paint
          ..strokeWidth = 3
          ..color = const Color(0xFFC9A227).withAlpha(120);
        canvas.drawLine(
          Offset(x - 60 * obstacle.scale, y - 10),
          Offset(x + 60 * obstacle.scale, y + 12),
          paint,
        );
        break;
    }
  }
}
