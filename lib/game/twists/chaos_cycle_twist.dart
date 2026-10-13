import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../creature.dart';
import '../fighter.dart';
import '../map_twist.dart';
import '../npc.dart';
import 'dust_storm_twist.dart';
import 'ice_cold_twist.dart';
import 'lava_geyser_twist.dart';
import 'mirror_clone_twist.dart';
import 'moving_walls_twist.dart';
import 'storm_lightning_twist.dart';

/// Throne of Rann twist - the chaos cycle.
///
/// Every 30 seconds the arena swaps to a different ranked-map twist, cycling
/// through all six previous ones. Rann's Avatar (500 HP) is also present from
/// the start; it stays neutral until somebody has the nerve to hit it.
class ChaosCycleTwist extends MapTwist {
  ChaosCycleTwist(super.game) {
    _activate(0, initial: true);
    _spawnAvatar();
  }

  static const double cycleSeconds = 30.0;

  double _timer = 0;
  int _activeIndex = 0;
  MapTwist _active = NoTwist(game);
  double _shockTimer = 6;
  final math.Random _rng = math.Random(3131);
  Npc? _avatar;

  final List<String> _names = <String>[
    'SANDFOG',
    'FROZEN COLD',
    'LAVA & GEYSERS',
    'MOVING WALLS',
    'MIRROR CLONES',
    'STORM & WIND',
  ];
  final List<String> _icons = <String>['🌫️', '🧊', '🌋', '🧱', '🪞', '🌩️'];

  MapTwist _build(int index) {
    switch (index) {
      case 0:
        return DustStormTwist(game);
      case 1:
        return IceColdTwist(game);
      case 2:
        return LavaGeyserTwist(game);
      case 3:
        return MovingWallsTwist(game);
      case 4:
        return MirrorCloneTwist(game);
      default:
        return StormLightningTwist(game);
    }
  }

  void _activate(int index, {bool initial = false}) {
    if (!initial) {
      _active.dispose();
    }
    _activeIndex = index % _names.length;
    _active = _build(_activeIndex);
    if (!initial) {
      game.addFloatingText(
        'TWIST: ${_names[_activeIndex]}',
        game.player.position,
        const Color(0xFFC9A227),
        size: 16,
      );
    }
  }

  void _spawnAvatar() {
    if (game.hasRankBoss) {
      return;
    }
    final Vector2 position = Vector2(game.worldSize.width * 0.5, game.worldSize.height * 0.18);
    _avatar = game.spawnNpc(
      type: CreatureType.griffin,
      position: position,
      difficulty: 1.15,
      elite: true,
      boss: true,
      neutral: true,
      hpOverride: 500,
      nameOverride: "Rann's Avatar",
      permanent: true,
    );
  }

  @override
  String get name => 'Chaos Cycle';

  @override
  String get icon => '🌌';

  @override
  String get description =>
      'All previous twists rotate every 30s - fog, ice, lava, walls, clones and lightning, forever.';

  @override
  String get hudLabel {
    final int seconds = (cycleSeconds - _timer).clamp(0, cycleSeconds).ceil();
    return '${_icons[_activeIndex]} ${_names[_activeIndex]} • ${seconds}s';
  }

  @override
  double get speedMultiplier => _active.speedMultiplier;

  @override
  double get visionMultiplier => _active.visionMultiplier;

  @override
  Color get overlayColor => _active.overlayColor;

  @override
  void update(double dt) {
    _active.update(dt);

    _timer += dt;
    if (_timer >= cycleSeconds) {
      _timer = 0;
      _activate(_activeIndex + 1);
    }

    // The avatar uses "all abilities": a shockwave plus summoned adds.
    final Npc? avatar = _avatar;
    if (avatar != null && avatar.alive && !avatar.neutral) {
      _shockTimer -= dt;
      if (_shockTimer <= 0) {
        _shockTimer = 6;
        game.damageArea(
          center: avatar.position.clone(),
          radius: 210,
          damage: 24,
          source: avatar,
          label: 'Avatar shockwave',
        );
        game.pushArea(
          center: avatar.position.clone(),
          radius: 210,
          force: 300,
        );
        if (game.npcs.where((Npc n) => n.alive).length < 24) {
          for (int i = 0; i < 2; i++) {
            game.spawnNpc(
              type: CreatureType.values[_rng.nextInt(CreatureType.values.length)],
              position: avatar.position.clone()
                ..add(Vector2(_rng.nextDouble() * 160 - 80, 120 + _rng.nextDouble() * 60)),
              difficulty: 0.9,
            );
          }
        }
      }
    }
  }

  @override
  void renderBehind(Canvas canvas) {
    _active.renderBehind(canvas);
    // Cosmic golden dust motes.
    final Paint paint = Paint();
    final Size size = game.worldSize;
    for (int i = 0; i < 60; i++) {
      final double seed = i * 613.0;
      final double x = (seed * 2.3 + game.elapsed * 6) % size.width;
      final double y = (seed * 5.7) % size.height;
      final double alpha = 0.10 + 0.18 * (0.5 + 0.5 * math.sin(game.elapsed * 1.6 + i));
      paint.color = const Color(0xFFC9A227).withAlpha((alpha * 255).round());
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * 0.7, paint);
    }
  }

  @override
  void renderFront(Canvas canvas) {
    _active.renderFront(canvas);
  }

  @override
  void onFighterSpawned(Fighter fighter) {
    _active.onFighterSpawned(fighter);
  }

  @override
  void dispose() {
    _active.dispose();
  }
}
