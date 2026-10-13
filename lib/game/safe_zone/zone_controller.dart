import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flame/extensions.dart';

import '../arena.dart';
import '../battle_game.dart';
import '../fighter.dart';
import '../game_map.dart';
import '../levels/level_modifier.dart';
import '../player.dart';
import 'healing_shrine.dart';
import 'sanctuary_pocket.dart';
import 'storm_ring.dart';

/// Everything the zone HUD needs, refreshed four times per second.
class ZoneHudInfo {
  const ZoneHudInfo({
    required this.zoneLabel,
    required this.nextLabel,
    required this.phaseLabel,
    required this.playerOutside,
    required this.damagePerSecond,
    required this.bloodlust,
    required this.suddenDeath,
  });

  final String zoneLabel;
  final String nextLabel;
  final String phaseLabel;
  final bool playerOutside;
  final double damagePerSecond;
  final bool bloodlust;
  final bool suddenDeath;

  static const ZoneHudInfo empty = ZoneHudInfo(
    zoneLabel: '—',
    nextLabel: '',
    phaseLabel: '',
    playerOutside: false,
    damagePerSecond: 0,
    bloodlust: false,
    suddenDeath: false,
  );
}

/// Drives everything that keeps a match inside the 90-180 second sweet spot:
/// the storm ring, healing shrines, sanctuary pockets, anti-camping and the
/// late-match bloodlust.
class ZoneController {
  ZoneController({
    required this.arena,
    required this.mapDef,
    required this.rng,
    required this.modifierCheck,
    this.enabled = true,
  }) {
    storm = StormRing(
      worldSize: arena.worldSize,
      shrinkMultiplier: _shrinkTuning,
      enabled: enabled,
    );
    if (enabled) {
      for (int i = 0; i < 3; i++) {
        shrines.add(
          HealingShrine(
            position: arena.randomPointInside(
              math.Random(mapDef.id.hashCode + i * 97),
              HealingShrine.radius,
              margin: 240,
            ),
          ),
        );
      }
    }
  }

  final Arena arena;
  final GameMapDef mapDef;
  final math.Random rng;
  final bool Function(LevelModifier) modifierCheck;
  final bool enabled;

  late final StormRing storm;
  final List<HealingShrine> shrines = <HealingShrine>[];
  final List<SanctuaryPocket> sanctuaries = <SanctuaryPocket>[];

  /// HUD feed (throttled to 4Hz).
  final ValueNotifier<ZoneHudInfo> hud = ValueNotifier<ZoneHudInfo>(ZoneHudInfo.empty);

  final Map<int, bool> _sanctuaryUsers = <int, bool>{};
  final Map<int, double> _sanctuaryCooldown = <int, double>{};
  final Set<int> _campingWarned = <int>{};

  double _damageTick = 0;
  double _sanctuaryTimer = 25;
  double _hudTimer = 0;
  double _campingTimer = 0;
  bool bloodlust = false;
  bool suddenDeathAnnounced = false;

  Vector2 get center => storm.center;
  double get radius => storm.radius;
  double get damagePerSecond => storm.damagePerSecond;
  int get phaseIndex => storm.phaseIndex;

  String get phaseLabel => storm.phase.label;

  /// "350 → 150" style zone label for the HUD.
  String get zoneLabel {
    final StormPhase current = storm.phase;
    final int now = storm.radius.round();
    final StormPhase? next = phaseIndex + 1 < StormRing.phases.length
        ? StormRing.phases[phaseIndex + 1]
        : null;
    if (next == null) {
      return '$now';
    }
    if (current.radius == next.radius) {
      return '$now';
    }
    return '$now → ${next.radius.round()}';
  }

  String get nextLabel => storm.suddenDeath
      ? 'SUDDEN DEATH'
      : 'Next in ${storm.secondsToNextPhase.ceil()}s';

  double get _shrinkTuning {
    double multiplier = mapDef.shrinkMultiplier;
    if (modifierCheck(LevelModifier.fastStorm)) {
      multiplier *= 1.3;
    }
    return multiplier;
  }

  bool containsFighter(Fighter fighter) {
    if (!enabled) {
      return true;
    }
    return storm.contains(fighter.position, margin: -fighter.radius * 0.5);
  }

  bool isOnIce(Fighter fighter) {
    for (final ArenaHazard hazard in arena.hazards) {
      if (hazard.kind == HazardKind.icePatch &&
          fighter.position.distanceTo(hazard.position) <= hazard.radius) {
        return true;
      }
    }
    return false;
  }

  /// True when the fighter is standing inside an active sanctuary pocket.
  bool isProtected(Fighter fighter) {
    if (!enabled) {
      return false;
    }
    if ((_sanctuaryCooldown[fighter.fighterId] ?? 0) > 0) {
      return false;
    }
    for (final SanctuaryPocket pocket in sanctuaries) {
      if (pocket.active && fighter.position.distanceTo(pocket.position) <= SanctuaryPocket.radius) {
        return true;
      }
    }
    return false;
  }

  void update(double dt, BattleGame game) {
    if (enabled) {
      storm.update(dt, rng);
      if (modifierCheck(LevelModifier.speedrun) && game.elapsed >= 60 && !storm.suddenDeath) {
        storm.forceSuddenDeath();
      }
      if (storm.suddenDeath && !suddenDeathAnnounced) {
        suddenDeathAnnounced = true;
        game.addFloatingText(
          'SUDDEN DEATH',
          game.player.position,
          const Color(0xFF7C2D12),
          size: 20,
        );
      }

      for (final HealingShrine shrine in shrines) {
        shrine.update(dt, game, this);
      }

      _updateSanctuaries(dt, game);

      _damageTick += dt;
      if (_damageTick >= 0.5) {
        _damageTick = 0;
        _applyZoneDamage(game);
      }
    }

    _campingTimer += dt;
    if (_campingTimer >= 1.0) {
      _campingTimer = 0;
      _applyAntiCamping(game);
    }

    if (!bloodlust && game.elapsed >= 180) {
      bloodlust = true;
      game.activateBloodlust();
    }

    _hudTimer += dt;
    if (_hudTimer >= 0.25) {
      _hudTimer = 0;
      _refreshHud(game);
    }
  }

  void _applyZoneDamage(BattleGame game) {
    if (damagePerSecond <= 0) {
      return;
    }
    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive || containsFighter(fighter)) {
        continue;
      }
      if (isProtected(fighter)) {
        continue;
      }
      // Zone damage ignores flat defense percentages but respects armor.
      final double raw = damagePerSecond * 0.5 * (1 - fighter.defensePercent * 0.5);
      fighter.takeDamage(raw, label: 'Storm', ignoreDefense: true, environmental: true);
      game.onZoneDamage(fighter, raw);
    }
  }

  void _updateSanctuaries(double dt, BattleGame game) {
    if (!enabled) {
      return;
    }
    _sanctuaryTimer -= dt;
    if (_sanctuaryTimer <= 0) {
      _sanctuaryTimer = 25;
      for (int i = 0; i < 2; i++) {
        final double angle = rng.nextDouble() * math.pi * 2;
        final double distance = rng.nextDouble() * math.max(40.0, radius * 0.7);
        final Vector2 position = Vector2(
          center.x + math.cos(angle) * distance,
          center.y + math.sin(angle) * distance,
        );
        sanctuaries.add(
          SanctuaryPocket(
            position: Vector2(
              position.x.clamp(160, arena.worldSize.x - 160),
              position.y.clamp(160, arena.worldSize.y - 160),
            ),
          ),
        );
      }
    }

    for (final SanctuaryPocket pocket in sanctuaries) {
      pocket.update(dt);
    }
    sanctuaries.removeWhere((SanctuaryPocket pocket) => !pocket.active);

    // Track who is using a sanctuary so the 8s cooldown starts on exit.
    final Set<int> inside = <int>{};
    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive) {
        continue;
      }
      for (final SanctuaryPocket pocket in sanctuaries) {
        if (pocket.active &&
            fighter.position.distanceTo(pocket.position) <= SanctuaryPocket.radius) {
          inside.add(fighter.fighterId);
          break;
        }
      }
    }

    for (final int id in _sanctuaryUsers.keys.toList()) {
      if (!inside.contains(id)) {
        _sanctuaryUsers.remove(id);
        _sanctuaryCooldown[id] = 8.0;
      }
    }
    for (final int id in inside) {
      if ((_sanctuaryCooldown[id] ?? 0) <= 0) {
        _sanctuaryUsers[id] = true;
      }
    }

    for (final int id in _sanctuaryCooldown.keys.toList()) {
      final double left = (_sanctuaryCooldown[id] ?? 0) - dt;
      if (left <= 0) {
        _sanctuaryCooldown.remove(id);
      } else {
        _sanctuaryCooldown[id] = left;
      }
    }
  }

  /// Coward debuff: no damage dealt or taken for 30s costs 20% damage for 15s.
  void _applyAntiCamping(BattleGame game) {
    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive || !fighter.isPlayer) {
        continue;
      }
      if (fighter.combatTimer >= 30 && fighter.cowardTimer <= 0) {
        fighter.cowardTimer = 15;
        // The debuff re-applies every second but the callout only fires once
        // per fighter, so the arena never fills up with repeated text.
        if (_campingWarned.add(fighter.fighterId)) {
          game.addFloatingText(
            'COWARD DEBUFF',
            fighter.position,
            const Color(0xFF78716C),
            size: 16,
          );
        }
      }
    }
  }

  void _refreshHud(BattleGame game) {
    final Player? player = game.playerOrNull;
    final bool outside = player == null ? false : !containsFighter(player);
    hud.value = ZoneHudInfo(
      zoneLabel: zoneLabel,
      nextLabel: nextLabel,
      phaseLabel: phaseLabel,
      playerOutside: outside,
      damagePerSecond: damagePerSecond,
      bloodlust: bloodlust,
      suddenDeath: storm.suddenDeath,
    );
  }

  void render(Canvas canvas, BattleGame game) {
    if (!enabled) {
      return;
    }
    storm.render(canvas, game.elapsed);
    for (final SanctuaryPocket pocket in sanctuaries) {
      pocket.render(canvas, game.elapsed);
    }
    for (final HealingShrine shrine in shrines) {
      shrine.render(canvas, game.playerOrNull);
    }
  }

  /// Draws the "move to the zone" arrow for the player.
  void renderPlayerArrow(Canvas canvas, BattleGame game) {
    if (!enabled) {
      return;
    }
    final Player? player = game.playerOrNull;
    if (player == null || containsFighter(player)) {
      return;
    }
    final Vector2 toCenter = center - player.position;
    final double angle = math.atan2(toCenter.y, toCenter.x);
    final double distance = toCenter.length;
    final double offset = player.radius + 34;
    final Offset tip = Offset(
      player.position.x + math.cos(angle) * offset,
      player.position.y + math.sin(angle) * offset,
    );
    final Path arrow = Path()
      ..moveTo(tip.dx + math.cos(angle) * 18, tip.dy + math.sin(angle) * 18)
      ..lineTo(
        tip.dx + math.cos(angle + 2.5) * 14,
        tip.dy + math.sin(angle + 2.5) * 14,
      )
      ..lineTo(
        tip.dx + math.cos(angle - 2.5) * 14,
        tip.dy + math.sin(angle - 2.5) * 14,
      )
      ..close();
    final double pulse = 0.6 + 0.4 * math.sin(game.elapsed * 4);
    canvas.drawPath(
      arrow,
      Paint()..color = const Color(0xFFD97706).withAlpha((pulse * 255).round()),
    );
    // Distance readout keeps the pressure readable.
    final double scale = (distance / 100).clamp(1.0, 9.0);
    canvas.drawCircle(
      tip,
      8 * scale * 0.4,
      Paint()..color = const Color(0xFFB45309).withAlpha(60),
    );
  }
}
