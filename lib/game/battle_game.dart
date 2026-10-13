import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'arena.dart';
import 'armor.dart';
import 'creature.dart';
import 'effects.dart';
import 'elite/elite_arena.dart';
import 'fighter.dart';
import 'fire_projectile.dart';
import 'forge_state.dart';
import 'game_map.dart';
import 'levels/boss_levels.dart';
import 'levels/game_level.dart';
import 'levels/level_modifier.dart';
import 'map_twist.dart';
import 'npc.dart';
import 'player.dart';
import 'poison_effect.dart';
import 'powerups.dart';
import 'safe_zone/zone_controller.dart';
import 'store_state.dart';
import 'weapon.dart';

/// Lifecycle of a single battle.
enum BattlePhase { running, won, lost }

/// Input bridge between the Flutter control widgets and the simulation.
class BattleInput {
  /// Normalised movement request written by the virtual joystick.
  final Vector2 move = Vector2.zero();

  bool _attackQueued = false;

  void queueAttack() {
    _attackQueued = true;
  }

  bool consumeAttack() {
    final bool value = _attackQueued;
    _attackQueued = false;
    return value;
  }
}

/// Everything the HUD widgets render, published through a [ValueNotifier] so
/// only the small HUD subtree rebuilds each frame (never the game widget).
class BattleHudState {
  const BattleHudState({
    required this.hp,
    required this.maxHp,
    required this.shield,
    required this.revives,
    required this.maxRevives,
    required this.timeSeconds,
    required this.mapName,
    required this.mapEmoji,
    required this.phaseLabel,
    required this.twistLabel,
    required this.twistIcon,
    required this.aliveEnemies,
    required this.aliveFactions,
    required this.kills,
    required this.weaponIcon,
    required this.weaponLabel,
    required this.armorIcon,
    required this.armorLabel,
    required this.powerUps,
    required this.poisonStacks,
    required this.coward,
    required this.chimeraName,
    required this.chimeraHp,
    required this.chimeraMaxHp,
    required this.chimeraPhase,
    required this.chimeraWindup,
    required this.isElite,
  });

  final double hp;
  final double maxHp;
  final double shield;
  final int revives;
  final int maxRevives;
  final double timeSeconds;
  final String mapName;
  final String mapEmoji;
  final String phaseLabel;
  final String twistLabel;
  final String twistIcon;
  final int aliveEnemies;
  final int aliveFactions;
  final int kills;
  final String weaponIcon;
  final String weaponLabel;
  final String armorIcon;
  final String armorLabel;
  final List<String> powerUps;
  final int poisonStacks;
  final bool coward;
  final String chimeraName;
  final double chimeraHp;
  final double chimeraMaxHp;
  final int chimeraPhase;
  final String chimeraWindup;
  final bool isElite;

  double get hpPercent => maxHp <= 0 ? 0 : (hp / maxHp).clamp(0.0, 1.0);

  static const BattleHudState initial = BattleHudState(
    hp: 120,
    maxHp: 120,
    shield: 0,
    revives: 0,
    maxRevives: 0,
    timeSeconds: 0,
    mapName: 'Rannbhoomi',
    mapEmoji: '⚔️',
    phaseLabel: 'Grace',
    twistLabel: '',
    twistIcon: '',
    aliveEnemies: 0,
    aliveFactions: 0,
    kills: 0,
    weaponIcon: '🗡️',
    weaponLabel: 'Dagger',
    armorIcon: '🥉',
    armorLabel: 'Normal',
    powerUps: <String>[],
    poisonStacks: 0,
    coward: false,
    chimeraName: '',
    chimeraHp: 0,
    chimeraMaxHp: 0,
    chimeraPhase: 0,
    chimeraWindup: '',
    isElite: false,
  );
}

/// Configuration for one battle: either a campaign level or an elite trial.
class BattleConfig {
  const BattleConfig.campaign({
    required this.level,
    this.assistMode = false,
  })  : trial = null,
        eliteTrialIndex = -1,
        eliteName = '',
        eliteArenaId = '';

  const BattleConfig.elite({
    required this.eliteTrialIndex,
    required this.eliteName,
    required this.eliteArenaId,
    this.assistMode = false,
  })  : level = null,
        trial = null;

  final GameLevel? level;
  final Object? trial;
  final int eliteTrialIndex;
  final String eliteName;
  final String eliteArenaId;
  final bool assistMode;

  bool get isElite => level == null;
}

/// The battle simulation.
///
/// One Flame game drives a full match: arena geometry, the storm ring, every
/// fighter, projectiles, pickups and effects. Rendering happens through a
/// single batched [_BattleRenderer] component which keeps draw ordering
/// predictable and cheap.
class BattleGame extends FlameGame {
  BattleGame({
    required this.config,
    BattleInput? input,
    math.Random? rng,
  })  : input = input ?? BattleInput(),
        rng = rng ?? math.Random(),
        super();

  final BattleConfig config;
  final BattleInput input;
  final math.Random rng;

  // ------------------------------------------------------------------- world
  late final Arena arena;
  late final ZoneController zones;
  MapTwist? twist;

  /// Every fighter, player included (index 0 is always the player).
  final List<Fighter> allFighters = <Fighter>[];
  final List<Npc> npcs = <Npc>[];
  final List<FireProjectile> projectiles = <FireProjectile>[];
  final List<PowerUp> powerUps = <PowerUp>[];
  final List<CoinChest> chests = <CoinChest>[];
  final List<GameEffect> effects = <GameEffect>[];
  final List<PoisonBubble> poisonBubbles = <PoisonBubble>[];

  Player get player => allFighters.first as Player;

  /// Null-safe player access for effects running after a defeat.
  Player? get playerOrNull =>
      allFighters.isNotEmpty && allFighters.first is Player && (allFighters.first as Player).alive
          ? allFighters.first as Player
          : null;

  double _elapsedSeconds = 0;

  /// Seconds since the battle started.
  double get elapsed => _elapsedSeconds;

  Vector2 get worldSize => arena.worldSize;

  // ------------------------------------------------------------------ status
  BattlePhase phase = BattlePhase.running;
  bool paused = false;
  int kills = 0;
  int battleCoins = 0;
  double zoneDamageTaken = 0;
  int _fighterIdCounter = 1;

  /// Notifies the UI when the battle ends.
  final ValueNotifier<BattlePhase> phaseNotifier =
      ValueNotifier<BattlePhase>(BattlePhase.running);

  /// HUD feed (refreshed 5 times per second).
  final ValueNotifier<BattleHudState> hud =
      ValueNotifier<BattleHudState>(BattleHudState.initial);

  double _hudTimer = 0;
  double _chestTimer = 14;
  bool _setupComplete = false;

  /// True when the level defines a rank boss.
  bool get hasRankBoss => npcs.any((Npc npc) => npc.isBoss);

  bool get isElite => config.isElite;

  List<Fighter> get fighters => allFighters;

  List<LevelModifier> get modifiers => config.level?.modifiers ?? const <LevelModifier>[];

  bool modifierActive(LevelModifier modifier) => modifiers.contains(modifier);

  /// Shrine / regen multiplier (elite warriors recover twice as fast).
  double get healMultiplierForPlayer => isElite ? 2.0 : 1.0;

  /// Combined visibility factor from the map twist and the darkness modifier.
  double get visionFactor {
    double factor = twist?.visionMultiplier ?? 1.0;
    if (modifierActive(LevelModifier.darkness)) {
      factor *= 0.7;
    }
    return factor.clamp(0.25, 1.0);
  }

  /// Global movement multiplier (thin air slows everybody down).
  double get globalSpeedMultiplier =>
      modifierActive(LevelModifier.thinAir) ? 0.9 : 1.0;

  Fighter? get championOrNull {
    for (final Npc npc in npcs) {
      if (npc.isBoss) {
        return npc;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------- setup
  @override
  Future<void> onLoad() async {
    final GameMapDef mapDef = config.level?.map ??
        (isElite ? EliteArenas.forId(config.eliteArenaId) : Maps.dustPit);
    arena = Arena(map: mapDef, seed: mapDef.id.hashCode ^ (isElite ? 7331 : config.level!.number));
    zones = ZoneController(
      arena: arena,
      mapDef: mapDef,
      rng: math.Random(mapDef.id.hashCode),
      modifierCheck: modifierActive,
      enabled: !isElite,
    );
    twist = mapDef.buildTwist(this);

    _spawnPlayer();
    if (isElite) {
      spawnEliteChampion();
    } else {
      _spawnCampaignEnemies();
    }

    // Snap the camera onto the warrior before the first frame.
    _updateCamera(0.016, snap: true);

    world.add(_BattleRenderer(this));
    _setupComplete = true;
    _refreshHud();
  }

  void _spawnPlayer() {
    final StoreState store = StoreState.instance;
    final ForgeState forge = ForgeState.instance;
    final Vector2 spawn = Vector2(worldSize.x / 2, worldSize.y * 0.72);
    final Set<BoosterKind> boosters = isElite
        ? <BoosterKind>{}
        : <BoosterKind>{if (store.activeBooster != null) store.activeBooster!};

    final int freeRevives = isElite ? 2 : 0;
    final int boosterRevive = boosters.contains(BoosterKind.revivePotion) ? 1 : 0;
    final int armorRevive = store.equippedArmor.effect == ArmorEffect.revive ? 1 : 0;

    final Player createdPlayer = Player(
      fighterId: _fighterIdCounter++,
      position: spawn,
      weapon: forge.activeWeapon,
      armor: store.equippedArmor,
      eliteArmor: store.equippedEliteArmor,
      powers: store.unlockedPowers,
      boosters: boosters,
      assistMode: config.assistMode,
      ironmanMode: modifierActive(LevelModifier.ironman),
      modifiers: modifiers,
      isEliteBattle: isElite,
      coinBonusMultiplier: store.coinBonusMultiplier,
      revives: freeRevives + boosterRevive + armorRevive,
      baseMaxHp: isElite ? 240 : 120,
    );
    allFighters.insert(0, createdPlayer);
    _maxRevives = createdPlayer.revives;
  }

  int _maxRevives = 0;

  void _spawnCampaignEnemies() {
    final GameLevel level = config.level!;
    final List<CreatureType> mix = level.creatureMix;
    final double difficulty = level.difficulty;

    // Spec formula: 8 + floor(levelInRank / 5) + rankIndex * 2, plus a gentle
    // player-power ramp so a maxed forge never fights a trivial arena.
    final int powerBonus = (playerPower / 60).floor().clamp(0, 6);
    int count = level.npcCount + powerBonus;
    if (modifierActive(LevelModifier.npcLegion)) {
      count += 5;
    }
    count = count.clamp(4, 40);

    // Modifier-driven beast scaling.
    final double hpMul = modifierActive(LevelModifier.npcTough) ? 1.25 : 1.0;
    final double dmgMul = modifierActive(LevelModifier.npcFierce) ? 1.25 : 1.0;
    final double spdMul = modifierActive(LevelModifier.npcSwift) ? 1.20 : 1.0;

    for (int i = 0; i < count; i++) {
      final double angle = (i / count) * math.pi * 2 + rng.nextDouble() * 0.4;
      final double distance = 520 + rng.nextDouble() * 420;
      final Vector2 position = Vector2(
        (worldSize.x / 2 + math.cos(angle) * distance).clamp(80.0, worldSize.x - 80),
        (worldSize.y / 2 + math.sin(angle) * distance).clamp(80.0, worldSize.y - 80),
      );
      spawnNpc(
        type: mix[i % mix.length],
        position: position,
        difficulty: difficulty,
        elite: modifierActive(LevelModifier.npcElite),
        hpScaleMul: hpMul,
        damageScaleMul: dmgMul,
        speedScaleMul: spdMul,
      );
    }

    // Boss Rush modifier: one extra elite joins the chaos.
    if (modifierActive(LevelModifier.bossRush)) {
      spawnNpc(
        type: mix.first,
        position: Vector2(worldSize.x * 0.5, worldSize.y * 0.32),
        difficulty: difficulty * 1.2,
        elite: true,
        hpScaleMul: hpMul,
        damageScaleMul: dmgMul,
        speedScaleMul: spdMul,
      );
    }

    // Rank boss (level 50 of each rank).
    final BossLevelDef? boss = level.boss;
    if (boss != null) {
      final Vector2 bossPosition = Vector2(worldSize.x / 2, worldSize.y * 0.2);
      final int bosses = boss.profile.isTwin ? 2 : 1;
      for (int b = 0; b < bosses; b++) {
        spawnNpc(
          type: boss.baseCreature,
          position: Vector2(bossPosition.x + (b == 0 ? -140 : 140), bossPosition.y),
          difficulty: difficulty * 1.15,
          elite: true,
          boss: true,
          hpOverride: boss.hp,
          nameOverride: boss.profile.isTwin ? '${boss.name} ${b == 0 ? 'I' : 'II'}' : boss.name,
          bossProfile: boss.profile,
          hpScaleMul: hpMul,
          damageScaleMul: dmgMul,
          speedScaleMul: spdMul,
        );
      }

      // Permanent clones (Crystal Queen).
      for (int c = 0; c < boss.profile.cloneCount; c++) {
        final double angle = (c / math.max<int>(1, boss.profile.cloneCount)) * math.pi * 2;
        spawnNpc(
          type: boss.baseCreature,
          position: Vector2(
            bossPosition.x + math.cos(angle) * 260,
            bossPosition.y + 160 + math.sin(angle) * 120,
          ),
          difficulty: difficulty * 0.9,
          mirrorClone: true,
          hpOverride: boss.profile.cloneHp,
          nameOverride: '${boss.name} Clone',
          hpScaleMul: hpMul,
          damageScaleMul: dmgMul,
          speedScaleMul: spdMul,
        );
      }

      // Handpicked adds.
      for (int i = 0; i < boss.addCount; i++) {
        final double angle = (i / boss.addCount) * math.pi * 2;
        spawnNpc(
          type: boss.adds[i % boss.adds.length],
          position: Vector2(
            bossPosition.x + math.cos(angle) * 220,
            bossPosition.y + math.sin(angle) * 220,
          ),
          difficulty: difficulty,
          elite: boss.addsElite,
          hpScaleMul: hpMul,
          damageScaleMul: dmgMul,
          speedScaleMul: spdMul,
        );
      }
    }
  }

  /// Hook for elite battles: [EliteBattleGame] spawns the chimera here.
  void spawnEliteChampion() {}

  /// Reserves the next unique fighter id (used by custom spawns).
  int nextFighterId() => _fighterIdCounter++;

  /// Adds a hand-built NPC (chimera, avatar, ...) to the simulation.
  void registerNpc(Npc npc) {
    npcs.add(npc);
    allFighters.add(npc);
    twist?.onFighterSpawned(npc);
  }

  /// Warrior power rating used for difficulty scaling.
  double get playerPower {
    final StoreState store = StoreState.instance;
    final WeaponTier weapon = ForgeState.instance.activeWeapon;
    final ArmorRank armor = store.equippedArmor;
    return 10 +
        weapon.damage * 1.5 +
        armor.hpBonus * 0.5 +
        armor.defensePercent * 100 +
        ForgeState.instance.lifetimeMerges * 2;
  }

  // ------------------------------------------------------------------ update
  @override
  void update(double dt) {
    // Ignore pathological frame spikes (app resumed after a long pause).
    final double step = dt.clamp(0.0, 0.05);
    if (_setupComplete && !paused && phase == BattlePhase.running) {
      _tick(step);
    }
    super.update(step);
  }

  void _tick(double dt) {
    _elapsedSeconds += dt;

    // Reset per-frame movement modifiers; twists and hazards re-apply them.
    for (final Fighter fighter in allFighters) {
      if (!fighter.alive) {
        continue;
      }
      fighter.traction = modifierActive(LevelModifier.slippery) ? 0.6 : 1.0;
      fighter.speedMultiplier = globalSpeedMultiplier;
      fighter.drift.setZero();
    }

    twist?.update(dt);
    arena.update(dt, this);
    zones.update(dt, this);

    player.inputDirection.setFrom(input.move);
    if (input.consumeAttack()) {
      player.requestAttack();
    }
    player.updatePlayer(dt, this);
    if (!player.alive && player.revives > 0) {
      player.reviveNow(this);
    }

    for (final Npc npc in npcs) {
      if (!npc.alive) {
        continue;
      }
      if (npc.wasAttacked) {
        npc.wakeIfNeutral(this);
      }
      npc.updateNpc(dt, this);
    }

    for (final Npc npc in npcs) {
      if (!npc.alive && !npc.deathHandled) {
        npc.deathHandled = true;
        npc.onDeath(this);
        registerNpcDeath(npc);
      }
    }

    for (final FireProjectile projectile in projectiles) {
      projectile.update(dt, this);
    }
    projectiles.removeWhere((FireProjectile p) => p.dead);

    for (final PowerUp powerUp in powerUps) {
      powerUp.update(dt, this);
    }
    powerUps.removeWhere((PowerUp p) => p.dead);

    for (final CoinChest chest in chests) {
      chest.update(dt, this);
    }
    chests.removeWhere((CoinChest c) => c.dead);

    for (final GameEffect effect in effects) {
      effect.update(dt);
    }
    effects.removeWhere((GameEffect e) => e.dead);
    for (final PoisonBubble bubble in poisonBubbles) {
      bubble.update(dt);
    }
    poisonBubbles.removeWhere((PoisonBubble b) => b.dead);

    _updateChestSpawns(dt);
    _updateCamera(dt);
    _updateHud(dt);
    _checkEndConditions();
  }

  void _updateChestSpawns(double dt) {
    _chestTimer -= dt;
    if (_chestTimer > 0) {
      return;
    }
    final int multiplier = player.chestSpawnMultiplier;
    _chestTimer = (18 / multiplier).clamp(6.0, 30.0);
    final int count = multiplier;
    for (int i = 0; i < count; i++) {
      final Vector2 spot = arena.randomPointInside(rng, 40, margin: 200);
      chests.add(
        CoinChest(
          position: spot,
          coins: 20 + rng.nextInt(26) + (isElite ? 40 : 0),
        ),
      );
    }
  }

  void _updateCamera(double dt, {bool snap = false}) {
    final Vector2 screen = size;
    if (screen.x <= 0 || screen.y <= 0) {
      return;
    }
    final double zoom = (math.min(screen.x, screen.y) / 620).clamp(0.55, 2.6);
    camera.viewfinder.zoom = zoom;

    final Vector2 target = player.position;
    final Vector2 current = camera.viewfinder.position;
    Vector2 desired = target.clone();

    // Clamp to world bounds so the void never shows.
    final double halfWidth = screen.x / 2 / zoom;
    final double halfHeight = screen.y / 2 / zoom;
    desired.x = worldSize.x <= halfWidth * 2
        ? worldSize.x / 2
        : desired.x.clamp(halfWidth, worldSize.x - halfWidth);
    desired.y = worldSize.y <= halfHeight * 2
        ? worldSize.y / 2
        : desired.y.clamp(halfHeight, worldSize.y - halfHeight);

    if (snap) {
      camera.viewfinder.position = desired;
      return;
    }
    final Vector2 delta = desired - current;
    final double maxStep = 900 * dt;
    if (delta.length <= maxStep) {
      camera.viewfinder.position = desired;
    } else {
      camera.viewfinder.position = current + (delta..normalize()..scale(maxStep));
    }
  }

  void _updateHud(double dt) {
    _hudTimer += dt;
    if (_hudTimer < 0.2) {
      return;
    }
    _hudTimer = 0;
    _refreshHud();
  }

  void _refreshHud() {
    if (allFighters.isEmpty) {
      return;
    }
    final Player warrior = player;
    final Fighter? champion = championOrNull;
    final int factions = npcs.where((Npc npc) => npc.alive).map((Npc npc) => npc.factionId).toSet().length;
    final GameMapDef mapDef = config.level?.map ??
        (isElite ? EliteArenas.forId(config.eliteArenaId) : Maps.dustPit);
    hud.value = BattleHudState(
      hp: warrior.hp,
      maxHp: warrior.maxHp,
      shield: warrior.shield,
      revives: warrior.revives,
      maxRevives: _maxRevives,
      timeSeconds: _elapsedSeconds,
      mapName: mapDef.name,
      mapEmoji: mapDef.emoji,
      phaseLabel: zones.enabled ? zones.phaseLabel : 'Duel',
      twistLabel: twist?.hudLabel ?? '',
      twistIcon: twist?.icon ?? '',
      aliveEnemies: npcs.where((Npc npc) => npc.alive).length,
      aliveFactions: factions,
      kills: kills,
      weaponIcon: warrior.weapon.icon,
      weaponLabel: warrior.weapon.label,
      armorIcon: warrior.armor.icon,
      armorLabel: warrior.armor.setName,
      powerUps: warrior.activePowers
          .map((ActivePowerUp p) => '${p.kind.icon} ${p.remaining.ceil()}s')
          .toList(),
      poisonStacks: warrior.poisonStacks,
      coward: warrior.cowardTimer > 0,
      chimeraName: champion?.displayName ?? '',
      chimeraHp: champion?.hp ?? 0,
      chimeraMaxHp: champion?.maxHp ?? 0,
      chimeraPhase: champion is Npc ? champion.phaseIndex + 1 : 0,
      chimeraWindup: champion is Npc ? _championWindupLabel(champion) : '',
      isElite: isElite,
    );
  }

  String _championWindupLabel(Npc champion) {
    if (champion.telegraphing) {
      return 'WIND-UP';
    }
    if (champion.abilityActive > 0) {
      return 'UNLEASHED';
    }
    return '';
  }

  // -------------------------------------------------------------- conditions
  void _checkEndConditions() {
    if (phase != BattlePhase.running) {
      return;
    }
    if (!player.alive && player.revives <= 0) {
      finishBattle(false);
      return;
    }
    final bool enemiesLeft = npcs.any((Npc npc) => npc.alive);
    if (!enemiesLeft) {
      finishBattle(true);
    }
  }

  void finishBattle(bool won) {
    if (phase != BattlePhase.running) {
      return;
    }
    phase = won ? BattlePhase.won : BattlePhase.lost;
    twist?.dispose();
    // Consume the queued booster now that the battle is over.
    StoreState.instance.consumeActiveBooster();
    _refreshHud();
    phaseNotifier.value = phase;
  }

  // --------------------------------------------------------------- game APIs
  /// Spawns a beast. Returns the created NPC so callers can tweak it.
  Npc spawnNpc({
    required CreatureType type,
    required Vector2 position,
    double difficulty = 1.0,
    bool elite = false,
    bool mirrorClone = false,
    bool neutral = false,
    bool boss = false,
    double? hpOverride,
    String? nameOverride,
    BossProfile? bossProfile,
    bool permanent = false,
    double hpScaleMul = 1.0,
    double damageScaleMul = 1.0,
    double speedScaleMul = 1.0,
  }) {
    final Npc npc = type.spawn(
      position: position,
      fighterId: _fighterIdCounter++,
      factionId: _fighterIdCounter,
      difficulty: difficulty,
      elite: elite,
      mirrorClone: mirrorClone,
      neutral: neutral,
      boss: boss,
      hpOverride: hpOverride,
      nameOverride: nameOverride,
      bossProfile: bossProfile,
      permanent: permanent,
      hpScaleMul: hpScaleMul,
      damageScaleMul: damageScaleMul,
      speedScaleMul: speedScaleMul,
    );
    npcs.add(npc);
    allFighters.add(npc);
    twist?.onFighterSpawned(npc);
    return npc;
  }

  /// Damages every hostile fighter inside a circle.
  void damageArea({
    required Vector2 center,
    required double radius,
    required double damage,
    Fighter? source,
    String label = '',
    bool ignoreDefense = false,
    bool continuous = false,
  }) {
    for (final Fighter fighter in allFighters) {
      if (!fighter.alive) {
        continue;
      }
      if (source != null && identical(fighter, source)) {
        continue;
      }
      if (source != null && fighter.factionId == source.factionId) {
        continue;
      }
      if (fighter.position.distanceTo(center) > radius + fighter.radius * 0.5) {
        continue;
      }
      if (zones.isProtected(fighter)) {
        continue;
      }
      fighter.takeDamage(
        damage,
        source: source,
        label: label,
        ignoreDefense: ignoreDefense,
        environmental: continuous,
      );
      if (fighter is Npc && source is Player) {
        fighter.wakeIfNeutral(this);
      }
    }
  }

  /// Pushes every fighter away from a point (shockwaves, geysers, wind).
  void pushArea({required Vector2 center, required double radius, required double force}) {
    final double scaled = modifierActive(LevelModifier.lowGravity) ? force * 1.5 : force;
    for (final Fighter fighter in allFighters) {
      if (!fighter.alive) {
        continue;
      }
      final Vector2 delta = fighter.position - center;
      final double distance = delta.length;
      if (distance > radius || distance < 0.001) {
        continue;
      }
      final double falloff = 1 - (distance / radius);
      fighter.applyKnockback(delta, scaled * falloff);
    }
  }

  /// Environment damage (cold, heat, hive poison) - respects the sanctuary.
  void environmentDamage(Fighter fighter, double amount, {String label = 'Environment'}) {
    if (!fighter.alive || amount <= 0) {
      return;
    }
    if (zones.isProtected(fighter)) {
      return;
    }
    fighter.takeDamage(amount, label: label);
  }

  /// Called by the zone controller when the storm burns someone.
  void onZoneDamage(Fighter fighter, double amount) {
    if (fighter.isPlayer) {
      zoneDamageTaken += amount;
    }
  }

  /// Late-match enrage: beasts hit harder and move faster after 180 seconds.
  void activateBloodlust() {
    for (final Npc npc in npcs) {
      if (!npc.alive || npc.bloodlust) {
        continue;
      }
      npc.bloodlust = true;
      npc.damageMultiplier *= 1.25;
      npc.speedMultiplier *= 1.10;
    }
    addFloatingText('BLOODLUST', player.position.clone(), const Color(0xFFB91C1C), size: 20);
  }

  Npc? nearestNpc(Vector2 from, {bool includeNeutral = false}) {
    Npc? best;
    double bestDistance = double.infinity;
    for (final Npc npc in npcs) {
      if (!npc.alive || (npc.neutral && !includeNeutral)) {
        continue;
      }
      final double distance = from.distanceTo(npc.position);
      if (distance < bestDistance) {
        best = npc;
        bestDistance = distance;
      }
    }
    return best;
  }

  void addEffect(GameEffect effect) {
    if (effects.length > 220) {
      effects.removeAt(0);
    }
    effects.add(effect);
  }

  void addFloatingText(String text, Vector2 position, Color color, {double size = 14}) {
    addEffect(FloatingText(text: text, position: position.clone(), color: color, size: size));
  }

  /// Drops a power-up. Returns null when the `noPowers` modifier is active.
  PowerUp? spawnPowerUp(Vector2 position, {PowerUpKind? kind, bool announce = false}) {
    if (modifierActive(LevelModifier.noPowers)) {
      return null;
    }
    final PowerUpKind resolved = kind ?? PowerUpKind.values[rng.nextInt(PowerUpKind.values.length)];
    final PowerUp powerUp = PowerUp(position: position.clone(), kind: resolved);
    powerUps.add(powerUp);
    if (announce) {
      addFloatingText('${resolved.icon} ${resolved.label}', position.clone(), resolved.color, size: 14);
    }
    return powerUp;
  }

  void collectPowerUp(PowerUpKind kind, Player collector) {
    if (kind == PowerUpKind.heal) {
      collector.heal(30);
      addFloatingText('+30 HP', collector.position.clone(), const Color(0xFF15803D), size: 15);
      return;
    }
    const double duration = 12;
    final double effectiveDuration = kind == PowerUpKind.magnet ? 20 : duration;
    collector.activePowers
      ..removeWhere((ActivePowerUp p) => p.kind == kind)
      ..add(
        ActivePowerUp(
          kind: kind,
          duration: effectiveDuration,
          description: kind.description,
        )..remaining = effectiveDuration,
      );
    addFloatingText(kind.label.toUpperCase(), collector.position.clone(), kind.color, size: 15);
  }

  void collectChest(CoinChest chest) {
    final int coins = (chest.coins * player.coinBonusMultiplier).round();
    battleCoins += coins;
    addFloatingText('+$coins 🪙', chest.position.clone(), const Color(0xFFD97706), size: 16);
    addEffect(
      RingPulse(
        position: chest.position.clone(),
        startRadius: 6,
        endRadius: 48,
        color: const Color(0xFFD97706),
        life: 0.4,
      ),
    );
  }

  /// Called when a destroyable hazard (crystal) dies.
  void onHazardDestroyed(ArenaHazard hazard) {
    addEffect(
      DeathBurst(position: hazard.position.clone(), color: const Color(0xFFB9A8E8), radius: 36),
    );
    addFloatingText('SHATTERED', hazard.position.clone(), const Color(0xFF7E22CE), size: 15);
    battleCoins += 10;
  }

  /// Sword sweeps also break arena objects inside the arc.
  void damageHazardsInArc(Vector2 origin, double reach, double facing, double arc, double damage) {
    for (final ArenaHazard hazard in arena.hazards.toList()) {
      if (!hazard.hasHealth || hazard.destroyed) {
        continue;
      }
      if (!isInsideArc(
        origin: origin,
        targetPosition: hazard.position,
        targetRadius: hazard.radius,
        reach: reach,
        facing: facing,
        arc: arc,
      )) {
        continue;
      }
      arena.damageHazard(hazard, damage, this);
    }
  }

  /// Called by NPCs when they die; see [Npc.onDeath].
  void registerNpcDeath(Npc npc) {
    kills++;
    final int coins = 2 + (config.level?.rank.index ?? 6) + (npc.isBoss ? 60 : 0);
    battleCoins += coins;
    final bool spawnChest = rng.nextDouble() < (0.3 * player.chestSpawnMultiplier);
    if (spawnChest) {
      chests.add(
        CoinChest(
          position: npc.position.clone(),
          coins: 20 + rng.nextInt(30) + (npc.isBoss ? 80 : 0),
        ),
      );
    }
  }

  @override
  void onRemove() {
    twist?.dispose();
    super.onRemove();
  }
}

/// Single component that renders the whole world in a predictable order.
class _BattleRenderer extends Component {
  _BattleRenderer(this.game);

  final BattleGame game;

  @override
  void render(Canvas canvas) {
    final BattleGame g = game;
    g.arena.renderFloor(canvas, g);
    g.arena.renderDecor(canvas, g);
    g.arena.renderHazards(canvas, g);
    g.twist?.renderBehind(canvas);
    g.zones.render(canvas, g);

    for (final CoinChest chest in g.chests) {
      chest.render(canvas);
    }
    for (final PowerUp powerUp in g.powerUps) {
      powerUp.render(canvas);
    }

    // Decals first, then shadows, then bodies - keeps stacking readable.
    for (final GameEffect effect in g.effects) {
      if (effect is CorpseDecal) {
        effect.render(canvas);
      }
    }
    for (final Fighter fighter in g.fighters) {
      if (fighter.alive) {
        fighter.renderShadow(canvas);
      }
    }
    for (final Fighter fighter in g.fighters) {
      if (fighter.alive) {
        fighter.render(canvas, g);
      }
    }

    for (final FireProjectile projectile in g.projectiles) {
      projectile.render(canvas);
    }
    for (final PoisonBubble bubble in g.poisonBubbles) {
      bubble.render(canvas);
    }
    for (final GameEffect effect in g.effects) {
      if (effect is! CorpseDecal) {
        effect.render(canvas);
      }
    }

    g.twist?.renderFront(canvas);
    g.zones.renderPlayerArrow(canvas, g);
  }
}
