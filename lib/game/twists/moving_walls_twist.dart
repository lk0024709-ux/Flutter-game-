import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../arena.dart';
import '../battle_game.dart';
import '../fighter.dart';
import '../map_twist.dart';

/// Jade Temple twist.
///
/// Four stone walls slide along rails across the temple and two treasure
/// shrines hand out a free power-up after 2 seconds of standing still on them.
class MovingWallsTwist extends MapTwist {
  MovingWallsTwist(super.game) {
    _build();
  }

  static const String _owner = 'walls';
  static const double standSeconds = 2.0;

  final List<ArenaWall> _walls = <ArenaWall>[];
  final List<_TreasureShrine> _shrines = <_TreasureShrine>[];
  final math.Random _rng = math.Random(6717);

  void _build() {
    final Size size = game.worldSize;
    final List<double> ys = <double>[0.3, 0.45, 0.6, 0.75];
    for (int i = 0; i < ys.length; i++) {
      final Vector2 origin = Vector2(0, size.height * ys[i]);
      final ArenaWall wall = ArenaWall(
        origin: origin,
        position: origin.clone(),
        size: Vector2(260, 34),
        axis: Vector2(1, 0),
        speed: 120 + i * 22,
        travel: size.width + 260,
        owner: _owner,
      );
      _walls.add(wall);
      game.arena.addWall(wall);
    }
    for (int i = 0; i < 2; i++) {
      _shrines.add(
        _TreasureShrine(
          // Deterministic jitter keeps every run of the map slightly different
          // without breaking the seeded layout.
          position: Vector2(
            size.width * (i == 0 ? 0.28 : 0.72) + (_rng.nextDouble() - 0.5) * 90,
            size.height * (i == 0 ? 0.2 : 0.8) + (_rng.nextDouble() - 0.5) * 90,
          ),
        ),
      );
    }
  }

  @override
  String get name => 'Moving Walls';

  @override
  String get icon => '🧱';

  @override
  String get description =>
      'Four stone walls slide across the temple while treasure shrines grant free power-ups.';

  @override
  String get hudLabel {
    for (final _TreasureShrine shrine in _shrines) {
      if (shrine.timer > 0) {
        return 'SHRINE ${(shrine.timer / standSeconds * 100).round()}%';
      }
    }
    return 'WALLS 4x';
  }

  @override
  void update(double dt) {
    for (final ArenaWall wall in _walls) {
      wall.update(dt);
    }
    for (final _TreasureShrine shrine in _shrines) {
      shrine.update(dt, game);
    }
  }

  @override
  void renderBehind(Canvas canvas) {
    final Paint paint = Paint();
    for (final _TreasureShrine shrine in _shrines) {
      final Rect rect = Rect.fromCircle(center: shrine.position.toOffset(), radius: 60);
      paint
        ..shader = RadialGradient(
          colors: shrine.ready
              ? <Color>[const Color(0x66D97706), const Color(0x00D97706)]
              : <Color>[const Color(0x33C9A227), const Color(0x00C9A227)],
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(shrine.position.toOffset(), 60, paint);
      paint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x99C9A227);
      canvas.drawCircle(shrine.position.toOffset(), 60, paint);
      if (shrine.timer > 0) {
        paint
          ..color = const Color(0xCCD97706)
          ..strokeWidth = 4;
        canvas.drawArc(
          Rect.fromCircle(center: shrine.position.toOffset(), radius: 44),
          -math.pi / 2,
          math.pi * 2 * (shrine.timer / standSeconds).clamp(0.0, 1.0),
          false,
          paint,
        );
      }
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  void renderFront(Canvas canvas) {
    final Paint paint = Paint()
      ..color = const Color(0xFF3F4A3F)
      ..style = PaintingStyle.fill;
    final Paint trim = Paint()
      ..color = const Color(0xFF8FA88F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final ArenaWall wall in _walls) {
      final Rect rect = Rect.fromLTWH(
        wall.position.x - wall.size.x / 2,
        wall.position.y - wall.size.y / 2,
        wall.size.x,
        wall.size.y,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(8)),
        trim,
      );
    }
  }

  @override
  void dispose() {
    game.arena.removeWallsByOwner(_owner);
  }

  @override
  void onFighterSpawned(Fighter fighter) {}
}

/// Reward pedestal that grants a random power-up after 2s of standing on it.
class _TreasureShrine {
  _TreasureShrine({required this.position});

  final Vector2 position;
  double timer = 0;
  double cooldown = 0;
  Fighter? _occupant;

  bool get ready => cooldown <= 0;

  void update(double dt, BattleGame game) {
    if (cooldown > 0) {
      cooldown -= dt;
      timer = 0;
      return;
    }
    Fighter? stander;
    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive) {
        continue;
      }
      if (fighter.position.distanceTo(position) <= 60 + fighter.radius * 0.5) {
        stander = fighter;
        break;
      }
    }
    if (stander == null) {
      timer = 0;
      _occupant = null;
      return;
    }
    if (_occupant != stander) {
      _occupant = stander;
      timer = 0;
    }
    timer += dt;
    if (timer >= MovingWallsTwist.standSeconds) {
      timer = 0;
      cooldown = 25;
      _occupant = null;
      game.spawnPowerUp(position.clone(), announce: true);
    }
  }
}
