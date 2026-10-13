import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../arena.dart';
import '../creature.dart';
import '../fighter.dart';
import '../map_twist.dart';
import '../npc.dart';

/// Crystal Cavern twist.
///
/// Every 20 seconds a mirror clone of a random fighter is born (it takes 50%
/// damage but deals 100%). Breaking all three cloning crystals disables the
/// mirror for 15 seconds.
class MirrorCloneTwist extends MapTwist {
  MirrorCloneTwist(super.game) {
    _buildCrystals();
  }

  static const String _crystalOwner = 'crystal';
  static const double cloneInterval = 20.0;
  static const double disabledSeconds = 15.0;

  final List<ArenaHazard> _crystals = <ArenaHazard>[];
  final math.Random _rng = math.Random(8823);

  double _cloneTimer = cloneInterval - 6;
  double _disabledTimer = 0;
  double _flashTimer = 0;
  Vector2? _pendingSpawn;

  bool get _crystalsAlive =>
      _crystals.where((ArenaHazard crystal) => !crystal.destroyed).isNotEmpty;

  void _buildCrystals() {
    for (int i = 0; i < 3; i++) {
      final ArenaHazard crystal = ArenaHazard(
        kind: HazardKind.crystal,
        position: game.arena.randomPointInside(_rng, 80, margin: 380),
        radius: 30,
        hp: 60,
        owner: _crystalOwner,
        label: 'Cloning crystal',
      );
      _crystals.add(crystal);
      game.arena.addHazard(crystal);
    }
  }

  @override
  String get name => 'Mirror Clones';

  @override
  String get icon => '🪞';

  @override
  String get description =>
      'Mirror clones spawn every 20s (50% damage taken, 100% dealt); shatter the crystals to stop them.';

  @override
  String get hudLabel {
    if (_disabledTimer > 0) {
      return 'MIRROR OFF ${_disabledTimer.ceil()}s';
    }
    final int alive = _crystals.where((ArenaHazard c) => !c.destroyed).length;
    return 'CLONE ${_cloneTimer.clamp(0, cloneInterval).ceil()}s • 💠$alive';
  }

  @override
  void update(double dt) {
    if (_flashTimer > 0) {
      _flashTimer -= dt;
    }

    final bool wasAlive = _crystalsAlive;
    if (!wasAlive && _disabledTimer <= 0) {
      // All crystals are down - the mirror sleeps for a while.
      _disabledTimer = disabledSeconds;
      game.addFloatingText(
        'MIRROR SHATTERED',
        game.player.position,
        const Color(0xFF7E22CE),
        size: 16,
      );
    }

    if (_disabledTimer > 0) {
      _disabledTimer -= dt;
      if (_disabledTimer <= 0) {
        _respawnCrystals();
      }
      return;
    }

    _cloneTimer -= dt;
    if (_cloneTimer <= 0) {
      _cloneTimer = cloneInterval;
      _spawnMirror();
    }
  }

  void _respawnCrystals() {
    _crystals.clear();
    game.arena.removeHazardsByOwner(_crystalOwner);
    _buildCrystals();
    game.addFloatingText(
      'CLONING RESTORED',
      game.player.position,
      const Color(0xFF7E22CE),
      size: 15,
    );
  }

  void _spawnMirror() {
    final List<Fighter> candidates = game.npcs
        .where((Npc npc) => npc.alive && !npc.isMirrorClone && !npc.isBoss)
        .toList();
    CreatureType type = CreatureType.values[_rng.nextInt(CreatureType.values.length)];
    Vector2 position = game.arena.randomPointInside(_rng, 80, margin: 260);
    if (candidates.isNotEmpty) {
      final Npc source = candidates[_rng.nextInt(candidates.length)];
      type = source.type;
      position = source.position.clone()..add(Vector2(60, 60));
    }
    _pendingSpawn = position;
    _flashTimer = 0.6;
    final Npc clone = game.spawnNpc(
      type: type,
      position: position,
      difficulty: 0.9,
      mirrorClone: true,
    );
    clone.incomingDamageMultiplier = 0.5;
    game.addFloatingText(
      'MIRROR CLONE',
      position,
      const Color(0xFF9C7BD0),
      size: 15,
    );
  }

  @override
  void renderBehind(Canvas canvas) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (final ArenaHazard crystal in _crystals) {
      if (crystal.destroyed) {
        continue;
      }
      final Rect rect = Rect.fromCircle(center: crystal.position.toOffset(), radius: 34);
      paint
        ..shader = RadialGradient(
          colors: <Color>[const Color(0x669C7BD0), const Color(0x009C7BD0)],
        ).createShader(rect);
      canvas.drawCircle(crystal.position.toOffset(), 34, paint);
      paint.shader = null;

      // Procedural crystal: a diamond shard with two facets.
      final Path shard = Path()
        ..moveTo(crystal.position.x, crystal.position.y - 26)
        ..lineTo(crystal.position.x + 16, crystal.position.y)
        ..lineTo(crystal.position.x, crystal.position.y + 26)
        ..lineTo(crystal.position.x - 16, crystal.position.y)
        ..close();
      paint.color = const Color(0xFF8B74C9);
      canvas.drawPath(shard, paint);
      paint.color = const Color(0xFFB9A8E8);
      canvas.drawPath(
        Path()
          ..moveTo(crystal.position.x, crystal.position.y - 26)
          ..lineTo(crystal.position.x + 16, crystal.position.y)
          ..lineTo(crystal.position.x, crystal.position.y)
          ..close(),
        paint,
      );
      // Health pips.
      final double hpPercent = (crystal.hp / 60).clamp(0.0, 1.0);
      paint.color = const Color(0xFF7E22CE);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(crystal.position.x - 20, crystal.position.y + 30, 40 * hpPercent, 4),
          const Radius.circular(2),
        ),
        paint,
      );
    }

    if (_flashTimer > 0 && _pendingSpawn != null) {
      paint.color = const Color(0xFF9C7BD0).withAlpha((_flashTimer / 0.6 * 140).round());
      canvas.drawCircle(_pendingSpawn!.toOffset(), 60, paint);
    }
  }

  @override
  void dispose() {
    game.arena.removeHazardsByOwner(_crystalOwner);
  }

  @override
  void onFighterSpawned(Fighter fighter) {}
}
