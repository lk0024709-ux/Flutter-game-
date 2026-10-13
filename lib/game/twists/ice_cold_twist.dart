import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../arena.dart';
import '../fighter.dart';
import '../map_twist.dart';

/// Frost Hollow twist.
///
/// Six slippery ice patches steal your footing (traction drops to 25%) and the
/// bitter cold drains 2 HP/s from anyone standing outside one of the three heat
/// zones.
class IceColdTwist extends MapTwist {
  IceColdTwist(super.game) {
    _buildArena();
  }

  static const String _owner = 'ice';
  static const double coldDamagePerSecond = 2.0;

  final List<ArenaHazard> _heatZones = <ArenaHazard>[];
  final List<ArenaHazard> _icePatches = <ArenaHazard>[];
  final math.Random _rng = math.Random(4471);
  double _snowTimer = 0;
  final List<_Snowflake> _snow = <_Snowflake>[];

  void _buildArena() {
    final Size size = game.worldSize;
    for (int i = 0; i < 6; i++) {
      final Vector2 position = game.arena.randomPointInside(_rng, 120, margin: 260);
      final ArenaHazard patch = ArenaHazard(
        kind: HazardKind.icePatch,
        position: position,
        radius: 90 + _rng.nextDouble() * 45,
        owner: _owner,
        label: 'Slippery ice',
      );
      _icePatches.add(patch);
      game.arena.addHazard(patch);
    }
    for (int i = 0; i < 3; i++) {
      final ArenaHazard heat = ArenaHazard(
        kind: HazardKind.heatZone,
        position: Vector2(
          size.width * (0.25 + i * 0.25),
          size.height * (i.isEven ? 0.3 : 0.7),
        ),
        radius: 150,
        owner: _owner,
        label: 'Heat zone',
      );
      _heatZones.add(heat);
      game.arena.addHazard(heat);
    }
  }

  @override
  String get name => 'Slippery Ice';

  @override
  String get icon => '🧊';

  @override
  String get description =>
      'Ice patches steal your footing while the cold bites for -2 HP/s outside the heat zones.';

  @override
  String get hudLabel {
    final int inside = game.fighters
        .where((Fighter f) => f.alive && isInsideHeatZone(f.position))
        .length;
    return 'COLD -2/s • ${inside}WARM';
  }

  bool isInsideHeatZone(Vector2 point) {
    for (final ArenaHazard zone in _heatZones) {
      if (point.distanceTo(zone.position) <= zone.radius) {
        return true;
      }
    }
    return false;
  }

  bool isOnIce(Vector2 point) {
    for (final ArenaHazard patch in _icePatches) {
      if (point.distanceTo(patch.position) <= patch.radius) {
        return true;
      }
    }
    return false;
  }

  @override
  void update(double dt) {
    // Cold damage + slippery footing.
    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive) {
        continue;
      }
      if (isOnIce(fighter.position)) {
        fighter.traction = 0.25;
      }
      if (!isInsideHeatZone(fighter.position)) {
        game.environmentDamage(fighter, coldDamagePerSecond * dt, label: 'Cold');
      }
    }

    // Snow particles.
    _snowTimer += dt;
    final Size size = game.worldSize;
    final int target = 120;
    while (_snow.length < target) {
      _snow.add(_spawnFlake(size));
    }
    for (final _Snowflake flake in _snow) {
      flake.position.add(Vector2(flake.drift.x * dt, flake.drift.y * dt));
      if (flake.position.y > size.height + 10) {
        flake.position.y = -10;
        flake.position.x = _rng.nextDouble() * size.width;
      }
      if (flake.position.x < -10) {
        flake.position.x = size.width + 10;
      }
    }
  }

  _Snowflake _spawnFlake(Size size) {
    return _Snowflake(
      position: Vector2(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
      radius: 1 + _rng.nextDouble() * 2.4,
      drift: Vector2(-8 + _rng.nextDouble() * 16, 30 + _rng.nextDouble() * 55),
      alpha: 0.35 + _rng.nextDouble() * 0.4,
    );
  }

  /// Heat zones are drawn by the arena; the twist only adds the snow and a cold
  /// vignette pulse so the hazard reads clearly at a glance.
  @override
  void renderFront(Canvas canvas) {
    final Paint paint = Paint();
    for (final _Snowflake flake in _snow) {
      paint.color = const Color(0xFFFFFFFF).withAlpha((flake.alpha * 255).round());
      canvas.drawCircle(flake.position.toOffset(), flake.radius, paint);
    }
    for (final ArenaHazard patch in _icePatches) {
      paint
        ..color = const Color(0x33E8F4F8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(patch.position.toOffset(), patch.radius, paint);
      paint
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(patch.position.toOffset(), patch.radius, paint);
    }
    paint.style = PaintingStyle.fill;
    for (final ArenaHazard zone in _heatZones) {
      final Paint glow = Paint()
        ..shader = RadialGradient(
          colors: <Color>[const Color(0x40D97706), const Color(0x00D97706)],
        ).createShader(Rect.fromCircle(
          center: zone.position.toOffset(),
          radius: zone.radius,
        ));
      canvas.drawCircle(zone.position.toOffset(), zone.radius, glow);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x88D97706);
      canvas.drawCircle(zone.position.toOffset(), zone.radius, paint);
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  void dispose() {
    game.arena.removeHazardsByOwner(_owner);
  }

  @override
  void onFighterSpawned(Fighter fighter) {}
}

class _Snowflake {
  _Snowflake({
    required this.position,
    required this.radius,
    required this.drift,
    required this.alpha,
  });

  final Vector2 position;
  final double radius;
  final Vector2 drift;
  final double alpha;
}
