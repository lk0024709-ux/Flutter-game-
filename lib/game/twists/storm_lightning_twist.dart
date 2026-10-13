import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../arena.dart';
import '../fighter.dart';
import '../map_twist.dart';

/// Storm Citadel twist.
///
/// Lightning smashes down every 6 seconds after a 1.5s telegraph (35 damage in
/// an AoE) and a rotating wind shoves all fighters 20 units/second.
class StormLightningTwist extends MapTwist {
  StormLightningTwist(super.game);

  static const String _owner = 'lightning';
  static const double strikeInterval = 6.0;
  static const double telegraphSeconds = 1.5;
  static const double windForce = 20.0;
  static const double windRotateSeconds = 10.0;

  final math.Random _rng = math.Random(5197);

  double _strikeTimer = strikeInterval - 2;
  double _windTimer = 0;
  double _windAngle = 0;
  double _boltFlash = 0;
  Vector2? _lastStrike;

  Vector2 get windVector => Vector2(math.cos(_windAngle), math.sin(_windAngle))..scale(windForce);

  /// Arrow glyph for the HUD.
  String get windArrow {
    final double angle = (_windAngle + math.pi * 2) % (math.pi * 2);
    const List<String> arrows = <String>['➡️', '↘️', '⬇️', '↙️', '⬅️', '↖️', '⬆️', '↗️'];
    final int index = ((angle / (math.pi / 4)).round()) % arrows.length;
    return arrows[index];
  }

  @override
  String get name => 'Storm & Wind';

  @override
  String get icon => '🌩️';

  @override
  String get description =>
      'Lightning smashes down every 6s after a 1.5s telegraph while the wind shoves everyone sideways.';

  @override
  String get hudLabel => 'BOLT ${_strikeTimer.clamp(0, strikeInterval).ceil()}s • $windArrow 20';

  @override
  void update(double dt) {
    if (_boltFlash > 0) {
      _boltFlash -= dt;
    }

    _windTimer += dt;
    if (_windTimer >= windRotateSeconds) {
      _windTimer = 0;
      _windAngle += math.pi / 4 * (1 + _rng.nextInt(3));
    }

    final Vector2 wind = windVector;
    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive) {
        continue;
      }
      fighter.drift.setFrom(wind);
    }

    _strikeTimer -= dt;
    if (_strikeTimer <= 0) {
      _strikeTimer = strikeInterval;
      _summonStrike();
    }
  }

  void _summonStrike() {
    final List<Fighter> alive =
        game.fighters.where((Fighter f) => f.alive).toList(growable: false);
    if (alive.isEmpty) {
      return;
    }
    // Lightning prefers the player, but never exclusively.
    Fighter target = alive[_rng.nextInt(alive.length)];
    if (_rng.nextDouble() < 0.5 && game.player.alive) {
      target = game.player;
    }
    // Predictive leading so standing still is not a valid strategy.
    final Vector2 predicted = target.position.clone()
      ..add(target.velocity.clone()..scale(0.6));
    _lastStrike = predicted;
    _boltFlash = 0.45;
    game.arena.addHazard(
      ArenaHazard(
        kind: HazardKind.lightning,
        position: predicted,
        radius: 72,
        telegraphSeconds: telegraphSeconds,
        oneShotDamage: 35,
        knockback: 120,
        life: telegraphSeconds + 0.5,
        owner: _owner,
        label: 'Lightning',
      ),
    );
  }

  @override
  void renderBehind(Canvas canvas) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (final ArenaHazard hazard in game.arena.hazards) {
      if (hazard.owner != _owner) {
        continue;
      }
      final double t = (hazard.age / telegraphSeconds).clamp(0.0, 1.0);
      paint
        ..color = const Color(0xFF64748B).withAlpha((40 + t * 90).round())
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hazard.position.toOffset(), hazard.radius * (0.5 + t * 0.5), paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF334155).withAlpha(200);
      canvas.drawCircle(hazard.position.toOffset(), hazard.radius, paint);
      paint.style = PaintingStyle.fill;
    }

    if (_boltFlash > 0 && _lastStrike != null) {
      final double strength = (_boltFlash / 0.45).clamp(0.0, 1.0);
      paint
        ..color = const Color(0xFFE2E8F0).withAlpha((strength * 200).round())
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;
      final Vector2 base = _lastStrike!;
      final Path bolt = Path()..moveTo(base.x, base.y - 400);
      double y = base.y - 400;
      while (y < base.y) {
        y += 55;
        bolt.lineTo(base.x + (_rng.nextDouble() - 0.5) * 46, y);
      }
      canvas.drawPath(bolt, paint);
      paint.style = PaintingStyle.fill;
    }
  }

  @override
  void renderFront(Canvas canvas) {
    // Faint wind streaks that communicate the push direction.
    final Vector2 wind = windVector;
    final Paint paint = Paint()..strokeWidth = 2;
    final Size size = game.worldSize;
    for (int i = 0; i < 22; i++) {
      final double seed = i * 937.0;
      final double x = (seed * 1.7) % size.width;
      final double y = (seed * 3.1) % size.height;
      final double wobble = math.sin((game.elapsed + i) * 1.4) * 22;
      paint.color = const Color(0xFF94A3B8)
          .withAlpha((60 + 30 * math.sin(game.elapsed * 2 + i)).round());
      canvas.drawLine(
        Offset(x + wobble, y),
        Offset(x + wobble + wind.x * 2.2, y + wind.y * 2.2),
        paint,
      );
    }
  }

  @override
  void dispose() {
    game.arena.removeHazardsByOwner(_owner);
  }

  @override
  void onFighterSpawned(Fighter fighter) {}
}
