import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../fighter.dart';
import '../map_twist.dart';

/// The Dust Pit twist - a rolling sandfog.
///
/// Every 12 seconds the fog rolls in for 5 seconds: fighters lose 15% move
/// speed and vision drops hard, which makes the free-for-all brutally chaotic.
class DustStormTwist extends MapTwist {
  DustStormTwist(super.game);

  static const double cycleSeconds = 12;
  static const double activeSeconds = 5;

  double _timer = 0;
  final List<_DustParticle> _particles = <_DustParticle>[];
  final math.Random _rng = math.Random(9137);

  bool get isActive => _timer >= (cycleSeconds - activeSeconds);

  double get _remaining {
    if (isActive) {
      return (cycleSeconds - _timer).clamp(0, activeSeconds);
    }
    return (cycleSeconds - activeSeconds - _timer).clamp(0, cycleSeconds);
  }

  @override
  String get name => 'Sandfog';

  @override
  String get icon => '🌫️';

  @override
  String get description =>
      'Every 12s a sandfog rolls in for 5s: -15% move speed and heavily reduced vision.';

  @override
  String get hudLabel {
    final int seconds = _remaining.ceil();
    return isActive ? 'SANDFOG ${seconds}s' : 'CALM ${seconds}s';
  }

  @override
  double get speedMultiplier => isActive ? 0.85 : 1.0;

  @override
  double get visionMultiplier => isActive ? 0.55 : 1.0;

  @override
  Color get overlayColor =>
      isActive ? const Color(0x2ED9C7A3) : const Color(0x00D9C7A3);

  @override
  void update(double dt) {
    _timer += dt;
    if (_timer >= cycleSeconds) {
      _timer -= cycleSeconds;
    }

    // Dust motes always drift through the pit; they thicken during the fog.
    final int target = isActive ? 90 : 26;
    while (_particles.length < target) {
      _particles.add(_spawnParticle());
    }
    final Size size = game.worldSize;
    for (final _DustParticle particle in _particles) {
      particle.position.add(
        Vector2(
          (particle.drift.x + (isActive ? 90 : 26)) * dt,
          particle.drift.y * dt,
        ),
      );
      if (particle.position.x > size.width + 40) {
        particle.position.x = -40;
        particle.position.y = _rng.nextDouble() * size.height;
      }
      if (particle.position.y < -40) {
        particle.position.y = size.height + 40;
      }
      if (particle.position.y > size.height + 40) {
        particle.position.y = -40;
      }
    }
    if (_particles.length > target) {
      _particles.removeRange(target, _particles.length);
    }
  }

  _DustParticle _spawnParticle() {
    final Size size = game.worldSize;
    return _DustParticle(
      position: Vector2(
        _rng.nextDouble() * size.width,
        _rng.nextDouble() * size.height,
      ),
      radius: 1.5 + _rng.nextDouble() * 3.5,
      drift: Vector2(0, -6 + _rng.nextDouble() * 18),
      alpha: 0.10 + _rng.nextDouble() * 0.22,
    );
  }

  @override
  void renderFront(Canvas canvas) {
    final Size size = game.worldSize;
    final Paint paint = Paint();
    for (final _DustParticle particle in _particles) {
      paint.color = Color(0xFFE3D2AC).withAlpha((particle.alpha * 255).round());
      canvas.drawCircle(particle.position.toOffset(), particle.radius, paint);
    }
    if (isActive) {
      // A soft horizontal haze that sells the "reduced vision" rule.
      final Paint haze = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0x00D9C7A3),
            const Color(0x40D9C7A3),
            const Color(0x40D9C7A3),
            const Color(0x00D9C7A3),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), haze);
    }
  }

  @override
  void onFighterSpawned(Fighter fighter) {}
}

class _DustParticle {
  _DustParticle({
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
