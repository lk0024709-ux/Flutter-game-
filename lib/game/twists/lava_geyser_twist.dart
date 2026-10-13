import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../arena.dart';
import '../fighter.dart';
import '../levels/level_modifier.dart';
import '../map_twist.dart';

/// Ember Forge twist.
///
/// Six lava pools burn for 5 HP/s and four fire geysers erupt every 8 seconds
/// (1s telegraph, 20 damage + knockback). With the `risingLava` modifier the
/// pools slowly expand, swallowing the arena.
class LavaGeyserTwist extends MapTwist {
  LavaGeyserTwist(super.game) {
    _buildPool();
  }

  static const String _poolOwner = 'lava';
  static const String _geyserOwner = 'geyser';
  static const double geyserInterval = 8.0;
  static const double lavaDamagePerSecond = 5.0;

  final List<ArenaHazard> _pools = <ArenaHazard>[];
  final List<Vector2> _geyserSpots = <Vector2>[];
  final math.Random _rng = math.Random(2299);

  double _geyserTimer = geyserInterval - 3;
  double _riseTimer = 0;
  bool _rising = false;

  void _buildPool() {
    for (int i = 0; i < 6; i++) {
      final Vector2 position = game.arena.randomPointInside(_rng, 130, margin: 300);
      final ArenaHazard pool = ArenaHazard(
        kind: HazardKind.lava,
        position: position,
        radius: 70 + _rng.nextDouble() * 45,
        damagePerSecond: lavaDamagePerSecond,
        owner: _poolOwner,
        label: 'Lava pool',
      );
      _pools.add(pool);
      game.arena.addHazard(pool);
    }
    for (int i = 0; i < 4; i++) {
      _geyserSpots.add(game.arena.randomPointInside(_rng, 90, margin: 260));
    }
    _rising = game.modifierActive(LevelModifier.risingLava);
  }

  @override
  String get name => 'Lava & Geysers';

  @override
  String get icon => '🌋';

  @override
  String get description =>
      'Lava pools burn for 5 HP/s and fire geysers erupt every 8s for 20 damage plus knockback.';

  @override
  String get hudLabel => 'GEYSER ${(_geyserTimer).clamp(0, geyserInterval).ceil()}s';

  @override
  void update(double dt) {
    _geyserTimer -= dt;
    if (_geyserTimer <= 0) {
      _geyserTimer = geyserInterval;
      _erupt();
    }

    if (_rising) {
      _riseTimer += dt;
      if (_riseTimer >= 5) {
        _riseTimer = 0;
        for (final ArenaHazard pool in _pools) {
          pool.radius = (pool.radius + 12).clamp(0, 190);
        }
      }
    }
  }

  void _erupt() {
    // Two of the four geysers erupt each cycle, chosen at random.
    final List<Vector2> spots = List<Vector2>.from(_geyserSpots)..shuffle(_rng);
    for (int i = 0; i < 2 && i < spots.length; i++) {
      game.arena.addHazard(
        ArenaHazard(
          kind: HazardKind.geyser,
          position: spots[i].clone(),
          radius: 95,
          telegraphSeconds: 1.0,
          oneShotDamage: 20,
          knockback: 280,
          life: 1.0 + 0.9,
          owner: _geyserOwner,
          label: 'Fire geyser',
        ),
      );
    }
  }

  @override
  void renderBehind(Canvas canvas) {
    final Paint paint = Paint();
    for (final ArenaHazard pool in _pools) {
      final Rect rect = Rect.fromCircle(center: pool.position.toOffset(), radius: pool.radius);
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFB4430F).withAlpha(210);
      canvas.drawCircle(pool.position.toOffset(), pool.radius, paint);
      paint
        ..shader = RadialGradient(
          colors: <Color>[const Color(0xCCEA580C), const Color(0x00EA580C)],
        ).createShader(rect);
      canvas.drawCircle(pool.position.toOffset(), pool.radius * 1.15, paint);
      paint.shader = null;
    }
    paint.style = PaintingStyle.fill;
  }

  @override
  void dispose() {
    game.arena.removeHazardsByOwner(_poolOwner);
    game.arena.removeHazardsByOwner(_geyserOwner);
  }

  @override
  void onFighterSpawned(Fighter fighter) {}
}
