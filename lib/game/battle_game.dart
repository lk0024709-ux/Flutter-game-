import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/game_models.dart';

class BattleConfig {
  const BattleConfig.campaign(this.level)
      : chimera = null,
        isElite = false,
        assert(level != null);

  const BattleConfig.elite(this.chimera)
      : level = null,
        isElite = true,
        assert(chimera != null);

  final GameLevel? level;
  final ChimeraType? chimera;
  final bool isElite;

  String get title => isElite ? chimera!.title : arenaMaps[level!.rank.index].title;
  int get mapIndex => isElite ? 2 + (chimera!.index % 5) : level!.rank.index;
}

class BattleHud {
  const BattleHud({
    required this.hp,
    required this.maxHp,
    required this.damageTaken,
    required this.seconds,
    required this.enemyCount,
    required this.enemyTotal,
    required this.zoneLabel,
    required this.twistLabel,
    required this.revivals,
    required this.isElite,
    required this.bossHp,
    required this.bossMaxHp,
    required this.bossTitle,
    required this.phase,
    required this.poisoned,
    required this.coward,
    required this.powerupDamage,
  });

  final double hp;
  final double maxHp;
  final int damageTaken;
  final int seconds;
  final int enemyCount;
  final int enemyTotal;
  final String zoneLabel;
  final String twistLabel;
  final int revivals;
  final bool isElite;
  final double bossHp;
  final double bossMaxHp;
  final String bossTitle;
  final int phase;
  final bool poisoned;
  final bool coward;
  final bool powerupDamage;
}

class BattleGame extends FlameGame {
  BattleGame({
    required this.config,
    required this.weapon,
    required this.armor,
    required this.booster,
    required this.onHud,
    required this.onFinish,
  }) {
    _initializeBattle();
  }

  final BattleConfig config;
  final WeaponTier weapon;
  final ArmorRank armor;
  final Booster? booster;
  final ValueChanged<BattleHud> onHud;
  final ValueChanged<BattleOutcome> onFinish;

  static const double _worldSize = 2400;
  static const double _eliteWorldSize = 1600;
  static const double _tau = math.pi * 2;
  final math.Random _random = math.Random();
  final List<Fighter> enemies = [];
  final List<Projectile> _projectiles = [];
  final List<SupplyCache> _caches = [];
  final List<Offset> _groundMarks = [];
  final List<Offset> _lavaPatches = [];
  final List<Offset> _icePatches = [];
  final List<Offset> _shrinePositions = [];
  final List<Offset> _sanctuaryPositions = [];

  late Fighter player;
  bool isPaused = false;
  bool _finished = false;
  bool _initialized = false;
  Offset _movement = Offset.zero;
  Offset _camera = Offset.zero;
  bool _attackQueued = false;
  double _elapsed = 0;
  double _hudTimer = 0;
  double _cacheTimer = 8;
  double _powerupDamageTimer = 0;
  double _playerAttackCooldown = 0;
  double _playerInvulnerability = 0;
  double _sanctuaryCooldown = 0;
  double _shrineRelocateTimer = 0;
  double _sanctuarySpawnTimer = 25;
  double _sanctuaryLife = 0;
  bool _wasPlayerInSanctuary = false;
  double _lightningTimer = 6;
  double _lightningTelegraph = 0;
  bool _lightningStrikePending = false;
  bool _bossAttackPending = false;
  double _mirrorTimer = 20;
  double _timeSinceCombat = 0;
  double _cowardTimer = 0;
  double _bossAbilityTimer = 2.3;
  double _bossTelegraph = 0;
  double _bossEnrageFlash = 0;
  int _bossAbilityIndex = 0;
  int _bossPhase = 1;
  double _damageTaken = 0;
  int _revivals = 0;
  int _enemyTotal = 0;
  Offset _lightningTarget = Offset.zero;
  Offset _bossChargeDirection = Offset.zero;
  Color _groundColor = const Color(0xFFCBB88D);
  Color _mapAccent = const Color(0xFF9A7440);
  String _twistName = 'Sandfog';

  double get _mapSize => config.isElite ? _eliteWorldSize : _worldSize;
  Offset get _worldCenter => Offset(_mapSize / 2, _mapSize / 2);
  int get _durationSeconds => _elapsed.floor();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initialized = true;
  }

  void _initializeBattle() {
    final mapIndex = config.mapIndex;
    final arena = arenaMaps[mapIndex];
    _groundColor = config.isElite ? _chimeraArenaColor(config.chimera!) : arena.ground;
    _mapAccent = config.isElite ? config.chimera!.color : arena.accent;
    _twistName = config.isElite ? 'CHIMERA TRIAL' : arena.twist.split(' ').first.toUpperCase();
    final center = _worldCenter;
    final modifiers = config.level == null ? <LevelModifier>[] : modifiersFor(config.level!);
    final ironman = modifiers.contains(LevelModifier.ironman);
    final noShield = modifiers.contains(LevelModifier.noShield);
    final armorFactor = modifiers.contains(LevelModifier.ironSkinless) ? 0.5 : 1.0;
    final playerHp = ironman ? 1 : (config.isElite ? 240 : 120) + armor.hpBonus;
    final armorDefense = noShield ? 0.0 : armor.defense * armorFactor + (booster == Booster.ironSkin && !config.isElite ? 0.2 : 0.0);
    final damageBoost = booster == Booster.damage && !config.isElite ? 1.25 : 1.0;
    final playerDamage = weapon.damage * (config.isElite ? 1.5 : 1.0) * damageBoost;
    final playerSpeed = 220 * (1 + armor.speedBonus);
    player = Fighter(
      name: 'Warrior',
      position: center + const Offset(-130, 15),
      faction: 0,
      isPlayer: true,
      type: null,
      hp: playerHp.toDouble(),
      maxHp: playerHp.toDouble(),
      speed: playerSpeed,
      damage: playerDamage,
      range: weapon.reach,
      attackInterval: weapon.cooldown,
      radius: 18,
      color: const Color(0xFFE2B66C),
      defense: armorDefense,
    );
    if (config.isElite) {
      _revivals = 2;
    } else {
      _revivals = (booster == Booster.revive ? 1 : 0) + (armor == ArmorRank.epic ? 1 : 0);
    }
    _seedMapDecorations();
    _seedShrines();
    if (config.isElite) {
      _spawnEliteBoss(config.chimera!);
    } else {
      _spawnCampaignFoes(config.level!);
    }
    _enemyTotal = enemies.length;
    _camera = player.position;
  }

  Color _chimeraArenaColor(ChimeraType chimera) {
    return Color.lerp(const Color(0xFF403E39), chimera.color, 0.34) ?? const Color(0xFF403E39);
  }

  void _seedMapDecorations() {
    _groundMarks.clear();
    _lavaPatches.clear();
    _icePatches.clear();
    for (var i = 0; i < 130; i++) {
      _groundMarks.add(Offset(_random.nextDouble() * _mapSize, _random.nextDouble() * _mapSize));
    }
    for (var i = 0; i < 8; i++) {
      _lavaPatches.add(Offset(240 + _random.nextDouble() * (_mapSize - 480), 240 + _random.nextDouble() * (_mapSize - 480)));
      _icePatches.add(Offset(200 + _random.nextDouble() * (_mapSize - 400), 200 + _random.nextDouble() * (_mapSize - 400)));
    }
  }

  void _seedShrines() {
    _shrinePositions
      ..clear()
      ..addAll([
        _worldCenter + const Offset(-390, -110),
        _worldCenter + const Offset(360, -270),
        _worldCenter + const Offset(80, 410),
      ]);
    _sanctuaryPositions.clear();
  }

  void _spawnCampaignFoes(GameLevel level) {
    final types = creaturesFor(level);
    final modifiers = modifiersFor(level);
    final count = level.npcCount + (modifiers.contains(LevelModifier.npcLegion) ? 5 : 0);
    final bossHp = _rankBossHp(level);
    for (var i = 0; i < count; i++) {
      final type = types[i % types.length];
      final angle = _random.nextDouble() * _tau;
      final distance = 240 + _random.nextDouble() * 620;
      final point = _bounded(_worldCenter + Offset.fromDirection(angle, distance));
      final isBoss = level.isRankBoss && i == 0;
      final multiplier = level.difficultyMultiplier * (1 + level.rank.index * 0.09);
      final toughness = (modifiers.contains(LevelModifier.npcTough) ? 1.25 : 1.0) *
          (modifiers.contains(LevelModifier.npcElite) ? 1.25 : 1.0);
      final fierceness = modifiers.contains(LevelModifier.npcFierce) ? 1.25 : 1.0;
      final speedScale = modifiers.contains(LevelModifier.npcSwift) ? 1.2 : 1.0;
      final hp = isBoss ? bossHp.toDouble() : type.baseHp * (1 + 0.25 * ((level.levelInRank - 1) ~/ 10));
      final enemy = Fighter(
        name: isBoss ? rankBossName(level) : type.title,
        position: point,
        faction: i + 1,
        isPlayer: false,
        type: type,
        hp: hp * (isBoss ? 1 : multiplier * toughness),
        maxHp: hp * (isBoss ? 1 : multiplier * toughness),
        speed: type.baseSpeed * (1 + level.rank.index * 0.035) * speedScale,
        damage: type.baseDamage * (1 + level.rank.index * 0.08) * fierceness,
        range: type.baseRange,
        attackInterval: type.attackInterval,
        radius: isBoss ? type.bodyRadius * 1.65 : type.bodyRadius,
        color: isBoss ? _mapAccent : _factionColor(type, i),
        isBoss: isBoss,
        neutralUntilHit: isBoss && level.rank == Rank.grandMasters,
        defense: isBoss ? 0.13 : 0,
      )..specialCooldown = 2.5 + _random.nextDouble() * 2.5;
      enemies.add(enemy);
    }
  }

  int _rankBossHp(GameLevel level) {
    return switch (level.rank) {
      Rank.bronze => 400,
      Rank.silver => 500,
      Rank.gold => 700,
      Rank.platinum => 1000,
      Rank.diamond => 500,
      Rank.masters => 900,
      Rank.grandMasters => 1500,
    };
  }

  void _spawnEliteBoss(ChimeraType chimera) {
    final archetype = switch (chimera) {
      ChimeraType.gryphonPrime => CreatureType.griffin,
      ChimeraType.basilisk => CreatureType.drake,
      ChimeraType.ravager => CreatureType.ironboar,
      ChimeraType.wyvern => CreatureType.skyhawk,
      ChimeraType.deathroll => CreatureType.venomtail,
      ChimeraType.rannsChimera => CreatureType.griffin,
      ChimeraType.omegaChimera => CreatureType.drake,
    };
    enemies.add(Fighter(
      name: chimera.title,
      position: _worldCenter + const Offset(300, 0),
      faction: 1,
      isPlayer: false,
      type: archetype,
      hp: chimera.hp.toDouble(),
      maxHp: chimera.hp.toDouble(),
      speed: 118 + chimera.difficulty * 15,
      damage: 28 + chimera.difficulty * 5,
      range: 110,
      attackInterval: 1.6,
      radius: 43 + chimera.index * 2.5,
      color: chimera.color,
      isBoss: true,
      isEliteBoss: true,
      defense: chimera.index > 1 ? 0.16 : 0.08,
    ));
  }

  Color _factionColor(CreatureType type, int factionIndex) {
    final hue = (type.index * 67 + factionIndex * 43 + _random.nextInt(25)) % 360.0;
    return HSLColor.fromAHSL(1, hue, 0.48, 0.46).toColor();
  }

  void setMovement(Offset value) {
    _movement = value.distance > 1 ? _normalize(value) : Offset.zero;
  }

  void requestAttack() {
    _attackQueued = true;
  }

  void setPaused(bool paused) {
    isPaused = paused;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_initialized || isPaused || _finished) return;
    final step = dt.clamp(0.0, 0.05).toDouble();
    _elapsed += step;
    _updateTimers(step);
    _updatePlayer(step);
    if (config.isElite) {
      _updateEliteBoss(step);
    } else {
      _updateEnemies(step);
      _updateMapHazards(step);
      _updateShrines(step);
      _updateZone(step);
      _updateSanctuaries(step);
    }
    _updateCaches(step);
    if (_lightningStrikePending) _resolveLightningStrike();
    _updateProjectiles(step);
    _separateFighters();
    _updateStatuses(step);
    _checkFinish();
    _updateCamera(step);
    _updateHud(step);
  }

  void _updateTimers(double dt) {
    _playerAttackCooldown = math.max(0, _playerAttackCooldown - dt).toDouble();
    _playerInvulnerability = math.max(0, _playerInvulnerability - dt).toDouble();
    _sanctuaryCooldown = math.max(0, _sanctuaryCooldown - dt).toDouble();
    _shrineRelocateTimer += dt;
    _sanctuarySpawnTimer += dt;
    _lightningTimer -= dt;
    if (_lightningTelegraph > 0) {
      _lightningTelegraph -= dt;
      if (_lightningTelegraph <= 0) {
        _lightningTelegraph = 0;
        _lightningStrikePending = true;
      }
    }
    _mirrorTimer -= dt;
    _cacheTimer -= dt;
    _powerupDamageTimer = math.max(0, _powerupDamageTimer - dt).toDouble();
    _timeSinceCombat += dt;
    _cowardTimer = math.max(0, _cowardTimer - dt).toDouble();
    _bossAbilityTimer -= dt;
    if (_bossTelegraph > 0) {
      _bossTelegraph -= dt;
      if (_bossTelegraph <= 0) {
        _bossTelegraph = 0;
        _bossAttackPending = true;
      }
    }
    _bossEnrageFlash = math.max(0, _bossEnrageFlash - dt).toDouble();
    if (_timeSinceCombat >= 30 && _cowardTimer <= 0) {
      _cowardTimer = 15;
      _timeSinceCombat = 0;
    }
  }

  void _updatePlayer(double dt) {
    var speed = player.speed;
    if (_isDustFogActive()) speed *= 0.85;
    if (_isPlayerInSanctuary()) speed *= 0.9;
    if (player.slowTimer > 0) speed *= 0.7;
    final move = _movement;
    if (move.distance > 0.04) {
      player.facing = math.atan2(move.dy, move.dx);
      player.position = _bounded(player.position + move * (speed * dt));
    } else if (!_isPlayerInSanctuary()) {
      final target = _nearestEnemyTo(player);
      if (target != null) player.facing = (target.position - player.position).direction;
    }
    if (_attackQueued && _playerAttackCooldown <= 0 && !_isPlayerInSanctuary()) {
      _performPlayerAttack();
      _attackQueued = false;
    }
    final noHeal = config.level != null && modifiersFor(config.level!).contains(LevelModifier.noHeal);
    if (!noHeal && armor == ArmorRank.advanced && player.hp < player.maxHp) {
      player.hp = math.min(player.maxHp, player.hp + 5 * dt).toDouble();
    }
  }

  void _performPlayerAttack() {
    final heavyBlade = config.level != null && modifiersFor(config.level!).contains(LevelModifier.slowForge);
    _playerAttackCooldown = weapon.cooldown * (heavyBlade ? 1.3 : 1);
    player.attackAnimation = 0.22;
    final arc = weapon == WeaponTier.axe ? math.pi * 1.1 : math.pi * 0.85;
    final targets = enemies.where((enemy) {
      if (!enemy.alive) return false;
      final delta = enemy.position - player.position;
      return delta.distance <= player.range + enemy.radius && _angleDelta(delta.direction, player.facing).abs() <= arc / 2;
    }).toList()
      ..sort((a, b) => (a.position - player.position).distance.compareTo((b.position - player.position).distance));
    final limit = weapon == WeaponTier.trident || weapon == WeaponTier.storm || weapon == WeaponTier.mythic ? 2 : 1;
    final hits = targets.take(limit).toList();
    for (final target in hits) {
      final double damage = player.damage * (_cowardTimer > 0 ? 0.8 : 1) * (_powerupDamageTimer > 0 ? 1.25 : 1);
      _applyDamage(target, damage, source: player);
      if (weapon == WeaponTier.storm || weapon == WeaponTier.mythic) {
        for (final nearby in enemies) {
          if (!nearby.alive || identical(nearby, target)) continue;
          if ((nearby.position - target.position).distance <= 60) _applyDamage(nearby, 15, source: player);
        }
      }
      if (weapon == WeaponTier.mythic && _random.nextDouble() < 0.2) {
        _applyDamage(target, damage, source: player);
      }
    }
  }

  void _updateEnemies(double dt) {
    final active = enemies.where((enemy) => enemy.alive).toList();
    for (final enemy in active) {
      enemy.cooldown = math.max(0, enemy.cooldown - dt).toDouble();
      enemy.aiTimer -= dt;
      enemy.specialCooldown -= dt;
      enemy.telegraph = math.max(0, enemy.telegraph - dt).toDouble();
      enemy.dashRemaining = math.max(0, enemy.dashRemaining - dt).toDouble();
      enemy.target ??= _nearestEnemyTo(enemy);
      if (enemy.aiTimer <= 0 || enemy.target == null || !enemy.target!.alive) {
        enemy.target = _nearestEnemyTo(enemy);
        enemy.aiTimer = 0.25 + _random.nextDouble() * 0.25;
      }
      final target = enemy.target;
      if (target == null) continue;
      final delta = target.position - enemy.position;
      final distance = delta.distance;
      if (distance > 0.1) enemy.facing = delta.direction;
      if (enemy.type == CreatureType.griffin && enemy.specialCooldown <= 0) {
        enemy.dashRemaining = 0.5;
        enemy.specialCooldown = 4;
      }
      if (enemy.type == CreatureType.ironboar && enemy.specialCooldown <= 0 && enemy.telegraph <= 0 && enemy.dashRemaining <= 0) {
        enemy.telegraph = 0.6;
        enemy.specialCooldown = 5.6;
        enemy.chargeTarget = target.position;
      }
      if (enemy.type == CreatureType.skyhawk && enemy.specialCooldown <= 0 && enemy.dashRemaining <= 0) {
        enemy.dashRemaining = 0.4;
        enemy.specialCooldown = 3;
        enemy.chargeTarget = target.position;
      }
      if (enemy.type == CreatureType.ironboar && enemy.telegraph > 0.05) {
        enemy.position = _bounded(enemy.position + _normalize(target.position - enemy.position) * (enemy.speed * 0.12 * dt));
        continue;
      }
      if (enemy.type == CreatureType.ironboar && enemy.specialCooldown > 4.6 && enemy.dashRemaining <= 0) {
        // The boar's short wind-up leads into a committed rush on its next pass.
        if (enemy.telegraph <= 0) enemy.dashRemaining = 1;
      }
      final isDrake = enemy.type == CreatureType.drake;
      final isSkyhawk = enemy.type == CreatureType.skyhawk;
      final desiredRange = isDrake ? 175.0 : isSkyhawk ? 145.0 : 48.0;
      Offset direction = _normalize(delta);
      if (isDrake && distance < 135) direction = -direction;
      if (isSkyhawk && distance > 90 && distance < 205) {
        final side = Offset(-direction.dy, direction.dx) * (enemy.strafeSign);
        direction = _normalize(direction * 0.18 + side * 0.95);
      } else if (!isDrake && distance < desiredRange * 0.72) {
        direction = -direction * 0.42 + Offset(-direction.dy, direction.dx) * enemy.strafeSign;
        direction = _normalize(direction);
      }
      var speed = enemy.speed;
      if (_elapsed > 180) speed *= 1.1;
      if (_isDustFogActive()) speed *= 0.85;
      if (enemy.dashRemaining > 0) speed *= enemy.type == CreatureType.ironboar ? 2.5 : enemy.type == CreatureType.skyhawk ? 3 : 2;
      if (distance > desiredRange || enemy.dashRemaining > 0) {
        enemy.position = _bounded(enemy.position + direction * speed * dt);
      }
      if (isDrake && distance <= enemy.range && distance > 70 && enemy.cooldown <= 0) {
        enemy.cooldown = enemy.attackInterval;
        enemy.attackAnimation = 0.22;
        _spawnProjectile(enemy, target, 12, 400, color: const Color(0xFFE77B43));
      } else if (distance <= enemy.range + target.radius && enemy.cooldown <= 0) {
        enemy.cooldown = enemy.attackInterval;
        enemy.attackAnimation = 0.22;
        var damage = enemy.damage * (_elapsed > 180 ? 1.25 : 1);
        if (enemy.type == CreatureType.ironboar && enemy.dashRemaining > 0) damage = 30 * (_elapsed > 180 ? 1.25 : 1);
        if (enemy.type == CreatureType.skyhawk && enemy.dashRemaining > 0) damage = 18;
        _applyDamage(target, damage, source: enemy, poison: enemy.type == CreatureType.venomtail);
      }
      if (isSkyhawk && enemy.dashRemaining > 0 && distance <= enemy.radius + target.radius + 8) {
        _applyDamage(target, 18, source: enemy);
        enemy.dashRemaining = 0;
      }
    }
  }

  void _updateEliteBoss(double dt) {
    final boss = enemies.firstWhere((enemy) => enemy.alive, orElse: () => enemies.first);
    if (!boss.alive) return;
    boss.hitFlash = math.max(0, boss.hitFlash - dt).toDouble();
    boss.attackAnimation = math.max(0, boss.attackAnimation - dt).toDouble();
    boss.cooldown = math.max(0, boss.cooldown - dt).toDouble();
    boss.dashRemaining = math.max(0, boss.dashRemaining - dt).toDouble();
    final healthRatio = boss.hp / boss.maxHp;
    final phase = healthRatio > 0.66 ? 1 : healthRatio > 0.33 ? 2 : 3;
    if (phase != _bossPhase) {
      _bossPhase = phase;
      _bossEnrageFlash = 0.2;
      boss.phaseShift = 0.35;
      if (phase == 2 && !boss.summonedMinions) {
        boss.summonedMinions = true;
        for (var i = 0; i < 2; i++) {
          _spawnEliteMinion(boss, i);
        }
      }
    }
    final delta = player.position - boss.position;
    final distance = delta.distance;
    if (distance > 1) boss.facing = delta.direction;
    final baseSpeed = boss.speed * (phase == 3 ? 1.2 : 1) * (player.hp / player.maxHp < 0.3 ? 1.15 : 1);
    if (_bossTelegraph <= 0 && boss.dashRemaining <= 0) {
      final preferred = 110 + boss.radius;
      if (distance > preferred) {
        boss.position = _bounded(boss.position + _normalize(delta) * baseSpeed * dt);
      } else if (distance < 75) {
        boss.position = _bounded(boss.position - _normalize(delta) * baseSpeed * 0.35 * dt);
      }
    }
    if (_bossAbilityTimer <= 0 && _bossTelegraph <= 0) {
      final interval = phase == 1 ? 2.5 : phase == 2 ? 1.8 : 1.2;
      _bossAbilityTimer = interval;
      _bossTelegraph = phase == 1 ? 1.0 : phase == 2 ? 0.7 : 0.5;
      _bossChargeDirection = _normalize(delta);
      _bossAbilityIndex++;
      boss.attackAnimation = 0.25;
    }
    if (_bossAttackPending) {
      _bossAttackPending = false;
      _executeEliteAttack(boss, phase, distance);
    }
    if (boss.dashRemaining > 0) {
      boss.position = _bounded(boss.position + _bossChargeDirection * baseSpeed * 3 * dt);
      if ((boss.position - player.position).distance <= boss.radius + player.radius + 14) {
        _applyDamage(player, 60 * (phase == 3 ? 1.3 : 1), source: boss);
        boss.dashRemaining = 0;
      }
    }
    if (boss.phaseShift > 0) {
      boss.phaseShift = math.max(0, boss.phaseShift - dt).toDouble();
    }
    if (boss.regeneration && healthRatio < 0.5 && boss.hp < boss.maxHp) {
      boss.hp = math.min(boss.maxHp, boss.hp + 15 * dt).toDouble();
    }
    for (final minion in enemies.where((enemy) => !enemy.isEliteBoss && enemy.alive)) {
      minion.cooldown = math.max(0, minion.cooldown - dt).toDouble();
      final direction = player.position - minion.position;
      if (direction.distance > minion.range) minion.position = _bounded(minion.position + _normalize(direction) * minion.speed * dt);
      if (direction.distance <= minion.range + player.radius && minion.cooldown <= 0) {
        minion.cooldown = 1.4;
        _applyDamage(player, minion.damage, source: minion);
      }
    }
  }

  void _executeEliteAttack(Fighter boss, int phase, double distance) {
    final abilityCount = phase == 1 ? 2 : phase == 2 ? 3 : 10;
    final abilityIndex = (_bossAbilityIndex - 1) % abilityCount;
    final multiplier = phase == 3 ? 1.3 : player.hp / player.maxHp < 0.3 ? 1.25 : 1.0;
    if (abilityIndex == 0 || distance < 130) {
      final radius = abilityIndex == 0 ? 250.0 : 165.0;
      if ((player.position - boss.position).distance <= radius) _applyDamage(player, 40 * multiplier, source: boss);
    } else if (abilityIndex == 1) {
      boss.dashRemaining = 0.65;
      _bossChargeDirection = _normalize(player.position - boss.position);
    } else if (abilityIndex == 2) {
      _spawnProjectile(boss, player, 25 * multiplier, 330, color: const Color(0xFF9FAE73), poison: true);
    } else if (abilityIndex == 3) {
      for (var i = 0; i < 3; i++) {
        _spawnProjectile(boss, player, 20 * multiplier, 260, color: const Color(0xFFE28C4A));
      }
    } else if (abilityIndex == 4) {
      if ((player.position - boss.position).distance < 230) {
        _applyDamage(player, 25 * multiplier, source: boss);
        player.slowTimer = 3;
      }
    } else if (abilityIndex == 5) {
      _lightningTarget = player.position + _movement * 60;
      _lightningTelegraph = 1.0;
    } else if (abilityIndex == 6) {
      player.slowTimer = 2.5;
      if (distance < 270) _applyDamage(player, 20 * multiplier, source: boss);
    } else {
      _spawnProjectile(boss, player, 30 * multiplier, 310, color: const Color(0xFFD8C3A0));
    }
    _timeSinceCombat = 0;
  }

  void _spawnEliteMinion(Fighter boss, int index) {
    final angle = index * math.pi;
    enemies.add(Fighter(
      name: 'Shardling',
      position: boss.position + Offset.fromDirection(angle, boss.radius + 45),
      faction: 2 + index,
      isPlayer: false,
      type: index == 0 ? CreatureType.skyhawk : CreatureType.venomtail,
      hp: 150,
      maxHp: 150,
      speed: 155,
      damage: 15,
      range: 55,
      attackInterval: 1.2,
      radius: 16,
      color: Color.lerp(boss.color, const Color(0xFFE0C68D), 0.35) ?? boss.color,
    ));
  }

  void _updateCaches(double dt) {
    if (_cacheTimer <= 0 && _caches.length < 3) {
      _caches.add(SupplyCache(
        position: _bounded(player.position + Offset.fromDirection(_random.nextDouble() * _tau, 130 + _random.nextDouble() * 190)),
      ));
      final interval = config.isElite ? 24 / 1.3 : booster == Booster.magnet ? 12 : 24;
      _cacheTimer = interval.toDouble();
    }
    for (final cache in List<SupplyCache>.from(_caches)) {
      cache.life -= dt;
      if ((cache.position - player.position).distance <= player.radius + 20) {
        if (_random.nextDouble() < 0.62) {
          player.hp = math.min(player.maxHp, player.hp + 32).toDouble();
        } else {
          _powerupDamageTimer = 8;
        }
        _caches.remove(cache);
      } else if (cache.life <= 0) {
        _caches.remove(cache);
      }
    }
  }

  void _updateProjectiles(double dt) {
    for (final projectile in List<Projectile>.from(_projectiles)) {
      projectile.life -= dt;
      if (!projectile.target.alive || projectile.life <= 0) {
        _projectiles.remove(projectile);
        continue;
      }
      final direction = projectile.target.position - projectile.position;
      final desired = _normalize(direction);
      projectile.velocity = _normalize(projectile.velocity * 0.86 + desired * 0.14) * projectile.speed;
      projectile.position += projectile.velocity * dt;
      if (direction.distance <= projectile.target.radius + 9) {
        _applyDamage(projectile.target, projectile.damage, source: projectile.owner, poison: projectile.poison);
        _projectiles.remove(projectile);
      }
    }
  }

  void _spawnProjectile(Fighter owner, Fighter target, double damage, double speed, {required Color color, bool poison = false}) {
    final direction = _normalize(target.position - owner.position);
    _projectiles.add(Projectile(
      owner: owner,
      target: target,
      position: owner.position + direction * (owner.radius + 8),
      velocity: direction * speed,
      speed: speed,
      damage: damage,
      color: color,
      poison: poison,
    ));
  }

  void _updateMapHazards(double dt) {
    final level = config.level;
    if (level == null) return;
    final rank = level.rank;
    final modifiers = modifiersFor(level);
    final lavaActive = rank == Rank.gold || rank == Rank.grandMasters || modifiers.contains(LevelModifier.risingLava);
    if (lavaActive) {
      for (final fighter in [player, ...enemies.where((enemy) => enemy.alive)]) {
        if (_lavaPatches.any((point) => (fighter.position - point).distance < 45)) {
          _applyDamage(fighter, 5 * dt, source: null);
        }
      }
    }
    final lightningActive = rank == Rank.masters || rank == Rank.grandMasters || modifiers.contains(LevelModifier.fastStorm);
    if (lightningActive) {
      if (_lightningTelegraph <= 0 && _lightningTimer <= 0) {
        _lightningTarget = _bounded(player.position + Offset((_random.nextDouble() - 0.5) * 150, (_random.nextDouble() - 0.5) * 150));
        _lightningTelegraph = 1.5;
        _lightningTimer = 6;
      }
    }
    if (rank == Rank.masters || rank == Rank.grandMasters) {
      final angle = (_elapsed ~/ 10) * math.pi / 2;
      final wind = Offset.fromDirection(angle, 20 * dt);
      player.position = _bounded(player.position + wind);
      for (final enemy in enemies.where((item) => item.alive)) {
        enemy.position = _bounded(enemy.position + wind);
      }
    }
    final mirrorMap = rank == Rank.diamond || rank == Rank.grandMasters || modifiers.contains(LevelModifier.mirrorMatch);
    if (mirrorMap && _mirrorTimer <= 0) {
      _mirrorTimer = 20;
      final candidates = enemies.where((enemy) => enemy.alive && !enemy.isBoss && !enemy.isMirror).toList();
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.hp.compareTo(a.hp));
        final original = candidates.first;
        final clone = Fighter(
          name: 'Mirror ${original.name}',
          position: _bounded(player.position + Offset.fromDirection(_random.nextDouble() * _tau, 190)),
          faction: 1000 + enemies.length,
          isPlayer: false,
          type: original.type,
          hp: original.maxHp * 0.5,
          maxHp: original.maxHp * 0.5,
          speed: original.speed,
          damage: original.damage,
          range: original.range,
          attackInterval: original.attackInterval,
          radius: original.radius,
          color: Color.lerp(original.color, const Color(0xFFD7C3A7), 0.38) ?? original.color,
          isMirror: true,
        );
        enemies.add(clone);
        _enemyTotal++;
      }
    }
  }

  void _resolveLightningStrike() {
    _lightningStrikePending = false;
    for (final fighter in [player, ...enemies.where((enemy) => enemy.alive)]) {
      if ((fighter.position - _lightningTarget).distance <= 105) {
        _applyDamage(fighter, 35, source: null);
        fighter.position = _bounded(fighter.position + _normalize(fighter.position - _lightningTarget) * 28);
      }
    }
  }

  void _updateShrines(double dt) {
    if (config.level != null && modifiersFor(config.level!).contains(LevelModifier.noHeal)) return;
    if (_shrineRelocateTimer >= 40) {
      _shrineRelocateTimer = 0;
      for (var i = 0; i < _shrinePositions.length; i++) {
        _shrinePositions[i] = _bounded(_worldCenter + Offset(
          (_random.nextDouble() - 0.5) * 1050,
          (_random.nextDouble() - 0.5) * 1050,
        ));
      }
    }
    for (final fighter in [player, ...enemies.where((enemy) => enemy.alive)]) {
      if (!fighter.alive || fighter.hp >= fighter.maxHp) continue;
      for (final shrine in _shrinePositions) {
        if ((fighter.position - shrine).distance <= 64) {
          fighter.hp = math.min(fighter.maxHp, fighter.hp + 5 * dt).toDouble();
          break;
        }
      }
    }
  }

  void _updateZone(double dt) {
    if (config.isElite) return;
    final radius = _currentZoneRadius;
    final center = _worldCenter;
    for (final fighter in [player, ...enemies.where((enemy) => enemy.alive)]) {
      if (!fighter.alive) continue;
      if ((fighter.position - center).distance > radius) {
        _applyDamage(fighter, _currentZoneDamage * dt, source: null);
      }
    }
  }

  void _updateSanctuaries(double dt) {
    final insidePocket = _sanctuaryPositions.any((pos) => (player.position - pos).distance <= 80);
    if (insidePocket) {
      _wasPlayerInSanctuary = true;
    } else if (_wasPlayerInSanctuary) {
      _wasPlayerInSanctuary = false;
      _sanctuaryCooldown = 8;
    }
    if (_sanctuarySpawnTimer >= 25) {
      _sanctuarySpawnTimer = 0;
      _sanctuaryLife = 12;
      _sanctuaryPositions
        ..clear()
        ..addAll([
          _worldCenter + Offset((_random.nextDouble() - 0.5) * 500, (_random.nextDouble() - 0.5) * 500),
          _worldCenter + Offset((_random.nextDouble() - 0.5) * 700, (_random.nextDouble() - 0.5) * 700),
        ]);
    }
    if (_sanctuaryLife > 0) _sanctuaryLife -= dt;
    if (_sanctuaryLife <= 0) _sanctuaryPositions.clear();
  }

  void _updateStatuses(double dt) {
    for (final fighter in [player, ...enemies.where((enemy) => enemy.alive)]) {
      if (fighter.poisonStacks > 0) {
        fighter.poisonTick += dt;
        fighter.poisonDuration -= dt;
        if (fighter.poisonTick >= 1) {
          fighter.poisonTick -= 1;
          _applyDamage(fighter, fighter.poisonStacks * 2, source: null, allowPoison: false);
        }
        if (fighter.poisonDuration <= 0) fighter.poisonStacks = 0;
      }
      fighter.slowTimer = math.max(0, fighter.slowTimer - dt).toDouble();
      fighter.hitFlash = math.max(0, fighter.hitFlash - dt).toDouble();
      fighter.attackAnimation = math.max(0, fighter.attackAnimation - dt).toDouble();
    }
  }

  void _applyDamage(Fighter target, double rawDamage, {Fighter? source, bool poison = false, bool allowPoison = true}) {
    if (_finished || !target.alive || rawDamage <= 0) return;
    if (target.isPlayer && source != null && _playerInvulnerability > 0) return;
    final sanctuary = _sanctuaryPositions.any((pos) => (target.position - pos).distance <= 80);
    if (sanctuary && (!target.isPlayer || _sanctuaryCooldown <= 0)) return;
    final defense = target.defense;
    final attackerScale = source?.isMirror == true ? 2.0 : 1.0;
    final mirrorGuard = target.isMirror ? 0.5 : 1.0;
    final applied = math.max(0, rawDamage * attackerScale * (1 - defense) * mirrorGuard).toDouble();
    if (applied <= 0) return;
    target.hp = math.max(0, target.hp - applied).toDouble();
    target.neutralUntilHit = false;
    target.hitFlash = 0.16;
    if (source != null && config.level != null && modifiersFor(config.level!).contains(LevelModifier.lowGravity)) {
      target.position = _bounded(target.position + _normalize(target.position - source.position) * 42);
    }
    if (target.isPlayer) {
      _damageTaken += applied;
      _playerInvulnerability = 0.22;
      _timeSinceCombat = 0;
      if (armor == ArmorRank.legend && source != null && !source.isPlayer) {
        source.hp = math.max(0, source.hp - applied * 0.1).toDouble();
        if (source.hp <= 0) source.alive = false;
      }
    } else if (source?.isPlayer == true) {
      _timeSinceCombat = 0;
    }
    if (poison && allowPoison) {
      target.poisonStacks = math.min(5, target.poisonStacks + 1).toInt();
      target.poisonDuration = 4;
      target.poisonTick = 0;
    }
    if (target.hp <= 0) {
      if (target.isPlayer && _revivals > 0) {
        _revivals--;
        target.hp = target.maxHp * 0.45;
        target.position = _worldCenter + const Offset(-85, 25);
        _playerInvulnerability = 2;
        target.alive = true;
      } else {
        target.alive = false;
      }
    }
  }

  void _separateFighters() {
    final fighters = [player, ...enemies.where((enemy) => enemy.alive)];
    for (var i = 0; i < fighters.length; i++) {
      for (var j = i + 1; j < fighters.length; j++) {
        final first = fighters[i];
        final second = fighters[j];
        final delta = second.position - first.position;
        final distance = delta.distance;
        final minDistance = first.radius + second.radius;
        if (distance > 0 && distance < minDistance) {
          final push = _normalize(delta) * ((minDistance - distance) * 0.22);
          first.position = _bounded(first.position - push);
          second.position = _bounded(second.position + push);
        }
      }
    }
  }

  void _checkFinish() {
    if (_finished) return;
    final playerDead = !player.alive || player.hp <= 0;
    final enemiesAlive = enemies.any((enemy) => enemy.alive);
    final speedrunFailed = config.level != null &&
        modifiersFor(config.level!).contains(LevelModifier.speedrun) &&
        _elapsed >= 60 &&
        enemiesAlive;
    if (playerDead || !enemiesAlive || speedrunFailed) {
      _finished = true;
      onFinish(BattleOutcome(
        won: !playerDead && !enemiesAlive && !speedrunFailed,
        durationSeconds: _durationSeconds,
        remainingHp: player.hp,
        maxHp: player.maxHp,
        damageTaken: _damageTaken.ceil(),
      ));
    }
  }

  void _updateCamera(double dt) {
    final viewportMin = math.min(size.x, size.y);
    final zoom = viewportMin <= 0 ? 1.0 : (viewportMin / 620).clamp(0.55, 2.6).toDouble();
    final halfW = size.x / (2 * zoom);
    final halfH = size.y / (2 * zoom);
    final desired = Offset(
      player.position.dx.clamp(halfW, _mapSize - halfW).toDouble(),
      player.position.dy.clamp(halfH, _mapSize - halfH).toDouble(),
    );
    final delta = desired - _camera;
    final maxStep = 900 * dt;
    _camera = delta.distance > maxStep && maxStep > 0 ? _camera + _normalize(delta) * maxStep : desired;
  }

  void _updateHud(double dt) {
    _hudTimer += dt;
    if (_hudTimer < 0.12) return;
    _hudTimer = 0;
    final alive = enemies.where((enemy) => enemy.alive).length;
    final bosses = enemies.where((enemy) => enemy.isBoss).toList();
    final Fighter? boss = bosses.isEmpty ? null : bosses.first;
    final ratio = config.isElite ? (boss?.hp ?? 0) / (boss?.maxHp ?? 1) : 0;
    final phase = config.isElite ? (ratio > 0.66 ? 1 : ratio > 0.33 ? 2 : 3) : _zonePhase;
    onHud(BattleHud(
      hp: player.hp,
      maxHp: player.maxHp,
      damageTaken: _damageTaken.ceil(),
      seconds: _durationSeconds,
      enemyCount: alive,
      enemyTotal: _enemyTotal,
      zoneLabel: config.isElite ? 'PHASE $phase' : _zoneHudLabel,
      twistLabel: config.isElite ? config.chimera!.ability : _twistName,
      revivals: _revivals,
      isElite: config.isElite,
      bossHp: boss?.hp ?? 0,
      bossMaxHp: boss?.maxHp ?? 0,
      bossTitle: boss?.name ?? '',
      phase: phase,
      poisoned: player.poisonStacks > 0,
      coward: _cowardTimer > 0,
      powerupDamage: _powerupDamageTimer > 0,
    ));
  }

  double get _zoneClock {
    if (config.isElite) return 0;
    final level = config.level!;
    final fastStorm = modifiersFor(level).contains(LevelModifier.fastStorm);
    return _elapsed / arenaMaps[level.rank.index].shrinkScale * (fastStorm ? 1.3 : 1);
  }

  double get _currentZoneDamage {
    final time = _zoneClock;
    if (time < 20) return 0;
    if (time < 45) return 3;
    if (time < 75) return 6;
    if (time < 105) return 10;
    if (time < 150) return 18;
    return 30;
  }

  int get _zonePhase {
    final time = _zoneClock;
    if (time < 20) return 1;
    if (time < 45) return 2;
    if (time < 75) return 3;
    if (time < 105) return 4;
    if (time < 150) return 5;
    return 6;
  }

  double get _currentZoneRadius {
    final time = _zoneClock;
    if (time < 20) return 1200;
    if (time < 25) return _lerp(1200, 900, (time - 20) / 5);
    if (time < 45) return 900;
    if (time < 50) return _lerp(900, 600, (time - 45) / 5);
    if (time < 75) return 600;
    if (time < 80) return _lerp(600, 350, (time - 75) / 5);
    if (time < 105) return 350;
    if (time < 110) return _lerp(350, 150, (time - 105) / 5);
    if (time < 150) return 150;
    if (time < 155) return _lerp(150, 60, (time - 150) / 5);
    return 60;
  }

  String get _zoneHudLabel {
    final radius = _currentZoneRadius.round();
    final next = _zonePhase < 6 ? [900, 600, 350, 150, 60][_zonePhase - 1] : null;
    const phaseStartTimes = [20, 45, 75, 105, 150];
    final nextAt = phaseStartTimes[(_zonePhase - 1).clamp(0, 4)];
    if (next == null) return 'ZONE $radius · SUDDEN DEATH';
    return 'ZONE $radius → $next · ${math.max(0, nextAt - _zoneClock).ceil()}s';
  }

  static double _lerp(double start, double end, double amount) =>
      (start + (end - start) * amount.clamp(0, 1)).toDouble();

  bool _isDustFogActive() => !config.isElite && config.level!.rank == Rank.bronze && _elapsed % 12 < 5 && _elapsed > 0;

  bool _isPlayerInSanctuary() => _sanctuaryPositions.any((pos) => (player.position - pos).distance <= 80) && _sanctuaryCooldown <= 0;

  Fighter? _nearestEnemyTo(Fighter source) {
    Fighter? nearest;
    var best = double.infinity;
    for (final candidate in [player, ...enemies]) {
      if (!candidate.alive || candidate.neutralUntilHit || candidate.faction == source.faction || identical(candidate, source)) continue;
      final distance = (candidate.position - source.position).distance;
      if (distance < best) {
        best = distance;
        nearest = candidate;
      }
    }
    return nearest;
  }

  Offset _bounded(Offset position) {
    const padding = 35.0;
    return Offset(position.dx.clamp(padding, _mapSize - padding).toDouble(), position.dy.clamp(padding, _mapSize - padding).toDouble());
  }

  static Offset _normalize(Offset offset) {
    final length = offset.distance;
    if (length <= 0.0001) return Offset.zero;
    return Offset(offset.dx / length, offset.dy / length);
  }

  static double _angleDelta(double first, double second) {
    var delta = (first - second + math.pi) % (math.pi * 2) - math.pi;
    if (delta < -math.pi) delta += math.pi * 2;
    return delta;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final viewportWidth = size.x;
    final viewportHeight = size.y;
    canvas.drawColor(_groundColor, BlendMode.srcOver);
    if (viewportWidth <= 0 || viewportHeight <= 0) return;
    final zoom = (math.min(viewportWidth, viewportHeight) / 620).clamp(0.55, 2.6).toDouble();
    canvas.save();
    canvas.translate(viewportWidth / 2, viewportHeight / 2);
    canvas.scale(zoom);
    canvas.translate(-_camera.dx, -_camera.dy);
    _drawArena(canvas);
    _drawMapDetails(canvas);
    if (!config.isElite) _drawZone(canvas);
    _drawShrines(canvas);
    _drawSanctuaries(canvas);
    if (_lightningTelegraph > 0) _drawLightningMarker(canvas);
    for (final cache in _caches) {
      _drawCache(canvas, cache);
    }
    for (final projectile in _projectiles) {
      _drawProjectile(canvas, projectile);
    }
    for (final enemy in enemies.where((enemy) => enemy.alive)) {
      _drawFighter(canvas, enemy);
    }
    _drawFighter(canvas, player);
    if (config.level != null && modifiersFor(config.level!).contains(LevelModifier.darkness)) {
      final darkness = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Rect.fromLTWH(0, 0, _mapSize, _mapSize))
        ..addOval(Rect.fromCircle(center: player.position, radius: 440));
      canvas.drawPath(darkness, Paint()..color = const Color(0xFF171512).withValues(alpha: 0.54));
    }
    if (_isDustFogActive()) {
      canvas.drawRect(Rect.fromLTWH(0, 0, _mapSize, _mapSize), Paint()..color = const Color(0xFFB8AF9E).withValues(alpha: 0.13));
    }
    canvas.restore();
  }

  void _drawArena(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, _mapSize, _mapSize), Paint()..color = _groundColor);
    for (var i = 0; i < _groundMarks.length; i++) {
      final point = _groundMarks[i];
      final radius = i % 4 == 0 ? 4.0 : 2.2;
      canvas.drawCircle(point, radius, Paint()..color = _mapAccent.withValues(alpha: i % 3 == 0 ? 0.10 : 0.06));
    }
    final border = Paint()
      ..color = _mapAccent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(8, 8, _mapSize - 16, _mapSize - 16), const Radius.circular(50)), border);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(22, 22, _mapSize - 44, _mapSize - 44), const Radius.circular(43)),
      Paint()..color = _mapAccent.withValues(alpha: 0.08),
    );
  }

  void _drawMapDetails(Canvas canvas) {
    final rank = config.level?.rank;
    for (var i = 0; i < _lavaPatches.length; i++) {
      if (rank == Rank.gold || rank == Rank.grandMasters) {
        final point = _lavaPatches[i];
        canvas.drawOval(Rect.fromCenter(center: point, width: 115 + (i % 3) * 18, height: 56 + (i % 2) * 11), Paint()..color = const Color(0xFFCA5836).withValues(alpha: 0.24));
        canvas.drawOval(Rect.fromCenter(center: point, width: 74, height: 27), Paint()..color = const Color(0xFFE7A05D).withValues(alpha: 0.48));
      }
    }
    for (var i = 0; i < _icePatches.length; i++) {
      if (rank == Rank.silver || rank == Rank.grandMasters) {
        final point = _icePatches[i];
        canvas.drawOval(Rect.fromCenter(center: point, width: 130, height: 75), Paint()..color = const Color(0xFFDFF2F0).withValues(alpha: 0.52));
        canvas.drawOval(Rect.fromCenter(center: point, width: 75, height: 34), Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.20));
      }
    }
    if (rank == Rank.platinum || rank == Rank.grandMasters) {
      for (var i = 0; i < 4; i++) {
        final x = 300 + i * 490 + math.sin(_elapsed * 0.35 + i) * 32;
        final y = 410 + (i % 2) * 620;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 46, height: 175), const Radius.circular(13)),
          Paint()..color = const Color(0xFF526D58).withValues(alpha: 0.47),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 13, height: 175), const Radius.circular(8)),
          Paint()..color = const Color(0xFFD2B565).withValues(alpha: 0.37),
        );
      }
    }
    if (config.isElite || rank == Rank.diamond || rank == Rank.grandMasters) {
      for (var i = 0; i < 12; i++) {
        final point = Offset(180 + (i * 177) % (_mapSize - 360), 120 + (i * 241) % (_mapSize - 240));
        final height = 14.0 + (i % 3) * 7;
        final path = Path()
          ..moveTo(point.dx, point.dy - height)
          ..lineTo(point.dx + height * 0.45, point.dy)
          ..lineTo(point.dx, point.dy + height)
          ..lineTo(point.dx - height * 0.45, point.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = _mapAccent.withValues(alpha: 0.4));
      }
    }
  }

  void _drawZone(Canvas canvas) {
    final center = _worldCenter;
    final radius = _currentZoneRadius;
    final phase = _zonePhase;
    final shade = phase <= 2 ? const Color(0xFF52606B).withValues(alpha: 0.12) : phase <= 4 ? const Color(0xFFD39A43).withValues(alpha: 0.15) : const Color(0xFF9C4A36).withValues(alpha: 0.22);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, _mapSize, _mapSize))
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(path, Paint()..color = shade);
    final pulse = (math.sin(_elapsed * 2) + 1) * 0.5;
    _drawDashedCircle(canvas, center, radius, Paint()
      ..color = _mapAccent.withValues(alpha: 0.55 + pulse * 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    canvas.drawCircle(center, radius, Paint()..color = _mapAccent.withValues(alpha: 0.025));
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const segments = 58;
    for (var i = 0; i < segments; i += 2) {
      final start = _tau * i / segments;
      final sweep = _tau / segments;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
    }
  }

  void _drawShrines(Canvas canvas) {
    for (final position in _shrinePositions) {
      canvas.drawCircle(position, 74, Paint()..color = const Color(0xFF719368).withValues(alpha: 0.09));
      canvas.drawCircle(position, 49, Paint()
        ..color = const Color(0xFF6F8A62).withValues(alpha: 0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      canvas.drawCircle(position, 33, Paint()..color = const Color(0xFFEDE8D8).withValues(alpha: 0.95));
      final plusPaint = Paint()
        ..color = const Color(0xFF567348)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(position + const Offset(-10, 0), position + const Offset(10, 0), plusPaint);
      canvas.drawLine(position + const Offset(0, -10), position + const Offset(0, 10), plusPaint);
    }
  }

  void _drawSanctuaries(Canvas canvas) {
    for (final position in _sanctuaryPositions) {
      canvas.drawCircle(position, 80, Paint()..color = const Color(0xFFF3E9CE).withValues(alpha: 0.20));
      _drawDashedCircle(canvas, position, 80, Paint()
        ..color = const Color(0xFFE7D9B5).withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
      canvas.drawCircle(position, 47, Paint()..color = const Color(0xFFE9DFC8).withValues(alpha: 0.18));
    }
  }

  void _drawLightningMarker(Canvas canvas) {
    final pulse = 0.45 + 0.3 * math.sin(_elapsed * 18).abs();
    canvas.drawCircle(_lightningTarget, 90, Paint()..color = const Color(0xFFD4C8A6).withValues(alpha: pulse * 0.22));
    canvas.drawCircle(_lightningTarget, 45, Paint()
      ..color = const Color(0xFFEBD79E).withValues(alpha: pulse * 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  void _drawCache(Canvas canvas, SupplyCache cache) {
    final bob = math.sin(_elapsed * 3 + cache.position.dx) * 3;
    final center = cache.position + Offset(0, bob);
    canvas.drawCircle(center, 25, Paint()..color = const Color(0xFFDFAD62).withValues(alpha: 0.14));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 27, height: 21), const Radius.circular(5)),
      Paint()..color = const Color(0xFF815335),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center + const Offset(0, -5), width: 29, height: 9), const Radius.circular(4)),
      Paint()..color = const Color(0xFFD7A65B),
    );
    canvas.drawRect(Rect.fromCenter(center: center, width: 4, height: 19), Paint()..color = const Color(0xFFEBD19A));
  }

  void _drawProjectile(Canvas canvas, Projectile projectile) {
    canvas.drawCircle(projectile.position, 12, Paint()..color = projectile.color.withValues(alpha: 0.15));
    canvas.drawCircle(projectile.position, 6, Paint()..color = projectile.color);
    canvas.drawCircle(projectile.position, 2.5, Paint()..color = const Color(0xFFFFE0A8));
  }

  void _drawFighter(Canvas canvas, Fighter fighter) {
    canvas.save();
    canvas.translate(fighter.position.dx, fighter.position.dy);
    canvas.rotate(fighter.facing);
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.16);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, fighter.radius * 0.8), width: fighter.radius * 2.4, height: fighter.radius * 0.9), shadow);
    final flash = fighter.hitFlash > 0 ? Color.lerp(fighter.color, const Color(0xFFFFEBD0), 0.68) ?? fighter.color : fighter.color;
    final bodyPaint = Paint()..color = flash;
    if (fighter.isPlayer) {
      final cape = Path()
        ..moveTo(-fighter.radius * 0.55, -fighter.radius * 0.2)
        ..lineTo(-fighter.radius * 1.35, fighter.radius * 1.2)
        ..lineTo(fighter.radius * 0.4, fighter.radius * 1.05)
        ..lineTo(fighter.radius * 0.55, -fighter.radius * 0.2)
        ..close();
      canvas.drawPath(cape, Paint()..color = const Color(0xFF773F2A));
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: fighter.radius * 1.85, height: fighter.radius * 2.05), bodyPaint);
      canvas.drawCircle(Offset(fighter.radius * 0.08, -fighter.radius * 0.38), fighter.radius * 0.54, Paint()..color = const Color(0xFFE8C797));
      canvas.drawLine(Offset(fighter.radius * 0.32, 0), Offset(fighter.radius * 2.0, 0), Paint()
        ..color = const Color(0xFFF0E6D5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round);
      canvas.drawLine(Offset(fighter.radius * 0.32, 0), Offset(fighter.radius * 0.55, fighter.radius * 0.45), Paint()
        ..color = const Color(0xFF654931)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round);
      if (_playerInvulnerability > 0) {
        canvas.drawCircle(Offset.zero, fighter.radius + 8, Paint()
          ..color = const Color(0xFFFFE3B5).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    } else {
      _drawCreatureParts(canvas, fighter, bodyPaint);
    }
    canvas.restore();
    if (fighter.attackAnimation > 0) {
      final arc = fighter.isPlayer && weapon == WeaponTier.axe ? math.pi * 1.1 : math.pi * 0.85;
      final opacity = (fighter.attackAnimation / 0.22).clamp(0.0, 1.0).toDouble() * 0.6;
      canvas.save();
      canvas.translate(fighter.position.dx, fighter.position.dy);
      canvas.rotate(fighter.facing);
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: fighter.range), -arc / 2, arc, false, Paint()
        ..color = (fighter.isPlayer ? const Color(0xFFFFD18E) : fighter.color).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = fighter.isPlayer ? 5 : 3);
      canvas.restore();
    }
    if (fighter.isBoss && fighter.alive) _drawBossHealth(canvas, fighter);
    else if (fighter.hp < fighter.maxHp * 0.98) _drawHealthBar(canvas, fighter);
  }

  void _drawCreatureParts(Canvas canvas, Fighter fighter, Paint bodyPaint) {
    final radius = fighter.radius;
    final type = fighter.type ?? CreatureType.griffin;
    if (type == CreatureType.griffin || type == CreatureType.skyhawk) {
      final wingPaint = Paint()..color = Color.lerp(fighter.color, const Color(0xFFE3D3B6), 0.28) ?? fighter.color;
      final wing = Path()
        ..moveTo(-radius * 0.2, 0)
        ..lineTo(-radius * 1.55, -radius * 0.95)
        ..lineTo(-radius * 0.92, radius * 0.12)
        ..lineTo(-radius * 1.3, radius * 0.8)
        ..lineTo(-radius * 0.15, radius * 0.48)
        ..close();
      canvas.drawPath(wing, wingPaint);
      canvas.save();
      canvas.scale(1, -1);
      canvas.drawPath(wing, wingPaint);
      canvas.restore();
    }
    if (type == CreatureType.drake || type == CreatureType.ironboar) {
      final hornPaint = Paint()..color = const Color(0xFFE4D7B9);
      final left = Path()
        ..moveTo(radius * 0.2, -radius * 0.55)
        ..lineTo(radius * 0.82, -radius * 1.12)
        ..lineTo(radius * 0.62, -radius * 0.2)
        ..close();
      canvas.drawPath(left, hornPaint);
      final lower = Path()
        ..moveTo(radius * 0.2, radius * 0.5)
        ..lineTo(radius * 0.82, radius * 1.02)
        ..lineTo(radius * 0.62, radius * 0.17)
        ..close();
      canvas.drawPath(lower, hornPaint);
    }
    if (type == CreatureType.venomtail) {
      final tail = Path()
        ..moveTo(-radius * 0.25, radius * 0.25)
        ..quadraticBezierTo(-radius * 1.35, radius * 1.2, -radius * 1.6, radius * 0.25)
        ..quadraticBezierTo(-radius * 1.05, radius * 0.62, -radius * 0.55, -radius * 0.05);
      canvas.drawPath(tail, Paint()
        ..color = Color.lerp(fighter.color, const Color(0xFF26321A), 0.18) ?? fighter.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3, radius * 0.26).toDouble()
        ..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(-radius * 1.58, radius * 0.24), radius * 0.16, Paint()..color = const Color(0xFFD6B15F));
    }
    final bodyRect = type == CreatureType.ironboar
        ? Rect.fromCenter(center: Offset.zero, width: radius * 2.15, height: radius * 1.6)
        : Rect.fromCenter(center: Offset.zero, width: radius * 1.9, height: radius * 1.75);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(radius * 0.7)), bodyPaint);
    canvas.drawCircle(Offset(radius * 0.43, -radius * 0.16), math.max(2.6, radius * 0.11).toDouble(), Paint()..color = const Color(0xFFFFE8C2));
    canvas.drawCircle(Offset(radius * 0.48, -radius * 0.16), math.max(1.5, radius * 0.055).toDouble(), Paint()..color = const Color(0xFF211E19));
    if (type == CreatureType.ironboar) {
      canvas.drawLine(Offset(radius * 0.68, radius * 0.4), Offset(radius * 1.08, radius * 0.2), Paint()
        ..color = const Color(0xFFE6D2AA)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round);
    }
    if (fighter.isEliteBoss) {
      canvas.drawCircle(Offset.zero, radius + 4 + (_bossEnrageFlash > 0 ? 8 : 0), Paint()
        ..color = fighter.color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      if (_bossTelegraph > 0) {
        canvas.drawCircle(Offset.zero, radius + 18 + 8 * math.sin(_elapsed * 16).abs(), Paint()
          ..color = const Color(0xFFE2C38B).withValues(alpha: 0.48)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
      }
    }
  }

  void _drawHealthBar(Canvas canvas, Fighter fighter) {
    final width = fighter.radius * 2.3;
    final rect = Rect.fromCenter(center: fighter.position - Offset(0, fighter.radius + 12), width: width, height: 4);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = const Color(0xFF201E1A).withValues(alpha: 0.55));
    final fill = Rect.fromLTWH(rect.left, rect.top, rect.width * (fighter.hp / fighter.maxHp).clamp(0, 1).toDouble(), rect.height);
    canvas.drawRRect(RRect.fromRectAndRadius(fill, const Radius.circular(4)), Paint()..color = const Color(0xFFBD493A));
  }

  void _drawBossHealth(Canvas canvas, Fighter boss) {
    final width = boss.isEliteBoss ? 120.0 : 82.0;
    final rect = Rect.fromCenter(center: boss.position - Offset(0, boss.radius + 17), width: width, height: 7);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = const Color(0xFF201E1A).withValues(alpha: 0.8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rect.left, rect.top, rect.width * (boss.hp / boss.maxHp).clamp(0, 1).toDouble(), rect.height), const Radius.circular(8)),
      Paint()..color = const Color(0xFFD5A45B),
    );
    if (boss.isEliteBoss) {
      final segmentWidth = width / 3;
      for (var i = 1; i <= 2; i++) {
        canvas.drawLine(Offset(rect.left + segmentWidth * i, rect.top - 1), Offset(rect.left + segmentWidth * i, rect.bottom + 1), Paint()
          ..color = const Color(0xFF29241E)
          ..strokeWidth = 2);
      }
    }
  }
}

class Fighter {
  Fighter({
    required this.name,
    required this.position,
    required this.faction,
    required this.isPlayer,
    required this.type,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.range,
    required this.attackInterval,
    required this.radius,
    required this.color,
    this.isBoss = false,
    this.isEliteBoss = false,
    this.isMirror = false,
    this.neutralUntilHit = false,
    this.defense = 0,
  });

  final String name;
  final int faction;
  final bool isPlayer;
  final CreatureType? type;
  final double maxHp;
  final double speed;
  final double damage;
  final double range;
  final double attackInterval;
  final double radius;
  final Color color;
  final bool isBoss;
  final bool isEliteBoss;
  final bool isMirror;
  bool neutralUntilHit;
  final double defense;

  Offset position;
  double hp;
  double facing = 0;
  double cooldown = 0;
  double aiTimer = 0;
  double attackAnimation = 0;
  double hitFlash = 0;
  double specialCooldown = 0;
  double dashRemaining = 0;
  double telegraph = 0;
  double poisonDuration = 0;
  double poisonTick = 0;
  double slowTimer = 0;
  double phaseShift = 0;
  double strafeSign = 1;
  int poisonStacks = 0;
  bool alive = true;
  bool summonedMinions = false;
  bool regeneration = true;
  Offset chargeTarget = Offset.zero;
  Fighter? target;
}

class SupplyCache {
  SupplyCache({required this.position});

  final Offset position;
  double life = 24;
}

class Projectile {
  Projectile({
    required this.owner,
    required this.target,
    required this.position,
    required this.velocity,
    required this.speed,
    required this.damage,
    required this.color,
    this.poison = false,
  });

  final Fighter owner;
  final Fighter target;
  final double speed;
  final double damage;
  final Color color;
  final bool poison;
  Offset position;
  Offset velocity;
  double life = 3;
}
