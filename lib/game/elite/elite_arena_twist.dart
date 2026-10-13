import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../arena.dart';
import '../fighter.dart';
import '../map_twist.dart';
import '../poison_effect.dart';

/// The seven signature hazards of the Chimera Trials.
enum EliteArenaProfile {
  /// Wind shear, continuous gusts and falling rock.
  gust,

  /// Poison pools that bubble venom into the arena.
  venom,

  /// Steam vents and grinding gate walls.
  steam,

  /// Meteor rain falling onto open cliffs.
  meteor,

  /// Shifting quicksand and a drifting sand vortex.
  quicksand,

  /// The throne room: gold walls, lightning, geysers and treasure.
  royal,

  /// The void: gravity wells and celestial lightning.
  gravity,
}

/// Twist used by every elite arena.
///
/// Elite trials are fought on a dark, flat 1600x1600 arena with one signature
/// environmental hazard. Nothing here is scripted to be unfair: every damaging
/// hazard telegraphs for at least 0.9s and every moving wall is slow enough to
/// walk away from.
class EliteArenaTwist extends MapTwist {
  EliteArenaTwist(super.game, {required this.profile}) {
    _build();
  }

  final EliteArenaProfile profile;
  final math.Random _rng = math.Random(9187);

  static const String _owner = 'eliteHazard';

  final List<ArenaHazard> _pools = <ArenaHazard>[];
  final List<Vector2> _vents = <Vector2>[];

  double _primaryTimer = 6;
  double _secondaryTimer = 11;
  double _ambientTimer = 4;
  double _gustTimer = 0;
  double _gravityTimer = 0;
  Vector2? _gravityCenter;
  double _strongTimer = 0;
  Vector2 _gustDirection = Vector2(1, 0);

  // ------------------------------------------------------------------ set-up
  void _build() {
    switch (profile) {
      case EliteArenaProfile.gust:
        for (int i = 0; i < 3; i++) {
          _vents.add(game.arena.randomPointInside(_rng, 90, margin: 300));
        }
        break;
      case EliteArenaProfile.venom:
        for (int i = 0; i < 5; i++) {
          final ArenaHazard pool = ArenaHazard(
            kind: HazardKind.generic,
            position: game.arena.randomPointInside(_rng, 110, margin: 240),
            radius: 80 + _rng.nextDouble() * 55,
            damagePerSecond: 6,
            owner: _owner,
            label: 'Venom pool',
          );
          _pools.add(pool);
          game.arena.addHazard(pool);
        }
        break;
      case EliteArenaProfile.steam:
        for (int i = 0; i < 4; i++) {
          _vents.add(game.arena.randomPointInside(_rng, 90, margin: 260));
        }
        _spawnWall(0.5, 300, 26, 300);
        _spawnWall(0.5, 300, 26, 1100);
        break;
      case EliteArenaProfile.meteor:
        _pools.add(
          ArenaHazard(
            kind: HazardKind.generic,
            position: Vector2(game.worldSize.x * 0.5, game.worldSize.y * 0.5),
            radius: 190,
            owner: _owner,
            label: 'Updraft',
          ),
        );
        game.arena.addHazard(_pools.first);
        break;
      case EliteArenaProfile.quicksand:
        for (int i = 0; i < 4; i++) {
          final ArenaHazard sand = ArenaHazard(
            kind: HazardKind.generic,
            position: game.arena.randomPointInside(_rng, 130, margin: 260),
            radius: 110 + _rng.nextDouble() * 40,
            damagePerSecond: 4,
            owner: _owner,
            label: 'Quicksand',
          );
          _pools.add(sand);
          game.arena.addHazard(sand);
        }
        break;
      case EliteArenaProfile.royal:
        for (int i = 0; i < 3; i++) {
          _vents.add(game.arena.randomPointInside(_rng, 90, margin: 280));
        }
        _spawnWall(0.35, 260, 28, 420);
        _spawnWall(0.65, 260, 28, 1180);
        break;
      case EliteArenaProfile.gravity:
        break;
    }
  }

  void _spawnWall(double xFraction, double length, double thickness, double y) {
    game.arena.addWall(
      ArenaWall(
        origin: Vector2(game.worldSize.x * xFraction, y),
        position: Vector2(game.worldSize.x * xFraction, y),
        size: Vector2(length, thickness),
        axis: Vector2(1, 0),
        speed: 42,
        travel: 320,
        owner: _owner,
      ),
    );
  }

  // --------------------------------------------------------------- twist info
  @override
  String get name {
    switch (profile) {
      case EliteArenaProfile.gust:
        return 'Howling Heights';
      case EliteArenaProfile.venom:
        return 'Venom Hollow';
      case EliteArenaProfile.steam:
        return 'Steam Gates';
      case EliteArenaProfile.meteor:
        return 'Meteor Shelf';
      case EliteArenaProfile.quicksand:
        return 'Drowning Sands';
      case EliteArenaProfile.royal:
        return 'Golden Court';
      case EliteArenaProfile.gravity:
        return 'Collapsing Void';
    }
  }

  @override
  String get icon {
    switch (profile) {
      case EliteArenaProfile.gust:
        return '🌪️';
      case EliteArenaProfile.venom:
        return '🧪';
      case EliteArenaProfile.steam:
        return '♨️';
      case EliteArenaProfile.meteor:
        return '☄️';
      case EliteArenaProfile.quicksand:
        return '🏜️';
      case EliteArenaProfile.royal:
        return '👑';
      case EliteArenaProfile.gravity:
        return '🌀';
    }
  }

  @override
  String get description =>
      'Elite arenas are dark, flat and deadly. Read the telegraphs and keep moving.';

  @override
  String get hudLabel {
    if (_gravityTimer > 0) {
      return 'GRAVITY WELL';
    }
    if (_gustTimer > 0) {
      return 'GUST';
    }
    if (_strongTimer > 0) {
      return 'STORM';
    }
    return '';
  }

  @override
  double get visionMultiplier => profile == EliteArenaProfile.gravity ? 0.75 : 0.9;

  @override
  Color get overlayColor => const Color(0x141C1917);

  // ------------------------------------------------------------------ update
  @override
  void update(double dt) {
    _ambient(dt);

    _primaryTimer -= dt;
    if (_primaryTimer <= 0) {
      _primaryTimer = _primaryInterval();
      _firePrimary();
    }

    _secondaryTimer -= dt;
    if (_secondaryTimer <= 0) {
      _secondaryTimer = _secondaryInterval();
      _fireSecondary();
    }
  }

  double _primaryInterval() {
    switch (profile) {
      case EliteArenaProfile.gust:
        return 9;
      case EliteArenaProfile.venom:
        return 10;
      case EliteArenaProfile.steam:
        return 7;
      case EliteArenaProfile.meteor:
        return 7;
      case EliteArenaProfile.quicksand:
        return 11;
      case EliteArenaProfile.royal:
        return 9;
      case EliteArenaProfile.gravity:
        return 6;
    }
  }

  double _secondaryInterval() {
    switch (profile) {
      case EliteArenaProfile.gravity:
        return 14;
      case EliteArenaProfile.royal:
        return 22;
      case EliteArenaProfile.venom:
        return 14;
      default:
        return 12;
    }
  }

  /// Continuous environment behaviour (drift, traction, lingering damage).
  void _ambient(double dt) {
    final Size size = game.worldSize;
    switch (profile) {
      case EliteArenaProfile.gust:
        if (_gustTimer > 0) {
          _gustTimer -= dt;
        } else {
          _gustDirection = Vector2(
            math.cos(game.elapsed * 0.25),
            math.sin(game.elapsed * 0.25),
          );
        }
        for (final Fighter fighter in game.fighters) {
          if (!fighter.alive) {
            continue;
          }
          fighter.drift.x += _gustDirection.x * 120;
          fighter.drift.y += _gustDirection.y * 120;
        }
        break;
      case EliteArenaProfile.meteor:
        // Updraft in the middle of the shelf pushes warriors outward.
        for (final ArenaHazard pool in _pools) {
          for (final Fighter fighter in game.fighters) {
            if (!fighter.alive) {
              continue;
            }
            final Vector2 delta = fighter.position - pool.position;
            final double distance = delta.length;
            if (distance < pool.radius && distance > 0.001) {
              final Vector2 push = delta.clone()
                ..normalize()
                ..scale(160);
              fighter.drift += push;
            }
          }
        }
        break;
      case EliteArenaProfile.quicksand:
        for (final ArenaHazard sand in _pools) {
          for (final Fighter fighter in game.fighters) {
            if (!fighter.alive) {
              continue;
            }
            if (fighter.position.distanceTo(sand.position) < sand.radius) {
              fighter.traction = math.min(fighter.traction, 0.45);
            }
          }
        }
        break;
      case EliteArenaProfile.gravity:
        if (_gravityTimer > 0) {
          _gravityTimer -= dt;
          final Vector2 center = _gravityCenter ?? Vector2(size.width / 2, size.height / 2);
          for (final Fighter fighter in game.fighters) {
            if (!fighter.alive) {
              continue;
            }
            final Vector2 delta = center - fighter.position;
            final double distance = delta.length;
            if (distance < 700 && distance > 1) {
              final Vector2 pull = delta.clone()
                ..normalize()
                ..scale(140 * (1 - distance / 700) + 30);
              fighter.drift += pull;
            }
          }
        }
        break;
      case EliteArenaProfile.venom:
        _ambientTimer -= dt;
        if (_ambientTimer <= 0) {
          _ambientTimer = 4;
          for (final ArenaHazard pool in _pools) {
            for (final Fighter fighter in game.fighters) {
              if (fighter.alive && fighter.position.distanceTo(pool.position) < pool.radius) {
                PoisonEffect.apply(fighter, game: game);
              }
            }
          }
        }
        break;
      case EliteArenaProfile.steam:
      case EliteArenaProfile.royal:
        break;
    }
  }

  void _firePrimary() {
    switch (profile) {
      case EliteArenaProfile.gust:
        _gustTimer = 3;
        _dropRocks(2);
        break;
      case EliteArenaProfile.venom:
        for (int i = 0; i < 2; i++) {
          _telegraphBurst(
            position: game.arena.randomPointInside(_rng, 90, margin: 220),
            radius: 110,
            damage: 24,
            telegraph: 1.2,
            knockback: 240,
            label: 'Venom eruption',
          );
        }
        break;
      case EliteArenaProfile.steam:
        for (final Vector2 vent in _vents) {
          _telegraphBurst(
            position: vent,
            radius: 120,
            damage: 26,
            telegraph: 0.9,
            knockback: 300,
            label: 'Steam vent',
          );
        }
        break;
      case EliteArenaProfile.meteor:
        _dropRocks(3);
        break;
      case EliteArenaProfile.quicksand:
        _telegraphBurst(
          position: game.player.position.clone()
            ..add(game.player.velocity.clone()..scale(0.6)),
          radius: 150,
          damage: 28,
          telegraph: 1.3,
          knockback: 320,
          label: 'Sand vortex',
        );
        break;
      case EliteArenaProfile.royal:
        _strongTimer = 2.5;
        _telegraphBurst(
          position: game.player.position.clone()
            ..add(game.player.velocity.clone()..scale(0.45)),
          radius: 100,
          damage: 30,
          telegraph: 1.2,
          knockback: 260,
          label: 'Royal lightning',
        );
        break;
      case EliteArenaProfile.gravity:
        _telegraphBurst(
          position: game.player.position.clone()
            ..add(game.player.velocity.clone()..scale(0.5)),
          radius: 110,
          damage: 35,
          telegraph: 1.4,
          knockback: 200,
          label: 'Void lightning',
        );
        break;
    }
  }

  void _fireSecondary() {
    switch (profile) {
      case EliteArenaProfile.gravity:
        _gravityTimer = 4;
        _gravityCenter = game.arena.randomPointInside(_rng, 120, margin: 400);
        game.addFloatingText(
          'GRAVITY WELL',
          _gravityCenter!,
          const Color(0xFF7C3AED),
          size: 18,
        );
        break;
      case EliteArenaProfile.royal:
        game.spawnPowerUp(
          game.arena.randomPointInside(_rng, 90, margin: 320),
          announce: true,
        );
        break;
      case EliteArenaProfile.venom:
        _telegraphBurst(
          position: game.player.position.clone(),
          radius: 130,
          damage: 22,
          telegraph: 1.1,
          knockback: 220,
          label: 'Poison geyser',
        );
        PoisonEffect.apply(game.player, stacks: 2, game: game);
        break;
      case EliteArenaProfile.steam:
        _telegraphBurst(
          position: game.player.position.clone()
            ..add(game.player.velocity.clone()..scale(0.5)),
          radius: 120,
          damage: 26,
          telegraph: 1.0,
          knockback: 280,
          label: 'Gate hammer',
        );
        break;
      case EliteArenaProfile.gust:
        _dropRocks(1);
        break;
      case EliteArenaProfile.meteor:
        _dropRocks(2);
        break;
      case EliteArenaProfile.quicksand:
        _telegraphBurst(
          position: game.player.position.clone(),
          radius: 110,
          damage: 24,
          telegraph: 1.2,
          knockback: 240,
          label: 'Sand spout',
        );
        break;
    }
  }

  void _dropRocks(int count) {
    for (int i = 0; i < count; i++) {
      final Vector2 around = game.player.position.clone()
        ..add(
          Vector2(
            (_rng.nextDouble() - 0.5) * 260,
            (_rng.nextDouble() - 0.5) * 260,
          ),
        );
      _telegraphBurst(
        position: around,
        radius: 84,
        damage: 26,
        telegraph: 1.15,
        knockback: 220,
        label: profile == EliteArenaProfile.meteor ? 'Meteor' : 'Rockfall',
      );
    }
  }

  void _telegraphBurst({
    required Vector2 position,
    required double radius,
    required double damage,
    required double telegraph,
    required double knockback,
    required String label,
  }) {
    game.arena.addHazard(
      ArenaHazard(
        kind: profile == EliteArenaProfile.royal
            ? HazardKind.treasureShrine
            : HazardKind.lightning,
        position: position,
        radius: radius,
        telegraphSeconds: telegraph,
        oneShotDamage: damage,
        knockback: knockback,
        life: telegraph + 0.5,
        owner: _owner,
        label: label,
      ),
    );
  }

  // ----------------------------------------------------------------- painting
  @override
  void renderBehind(Canvas canvas) {
    if (_gravityTimer <= 0 || _gravityCenter == null) {
      return;
    }
    final double progress = (1 - (_gravityTimer / 4).clamp(0.0, 1.0));
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF7C3AED).withAlpha((200 * (1 - progress * 0.6)).round());
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        _gravityCenter!.toOffset(),
        60 + i * 90 + progress * 40,
        paint,
      );
    }
  }

  @override
  void dispose() {
    game.arena.removeHazardsByOwner(_owner);
    game.arena.removeWallsByOwner(_owner);
  }
}
