import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import '../battle_game.dart';
import '../creature.dart';
import '../effects.dart';
import '../fighter.dart';
import '../fire_projectile.dart';
import '../loot/chimera_armor.dart';
import '../npc.dart';
import '../poison_effect.dart';
import 'chimera_abilities/chimera_factory.dart';
import 'chimera_ability.dart';
import 'chimera_ai.dart';
import 'chimera_defenses/chimera_defense_factory.dart';
import 'chimera_phase.dart';
import 'chimera_renderer.dart';

/// The seven fusion bosses of the Chimera Trials.
///
/// Every trial is a pure 1v1 duel: no storm ring, a dark 1600x1600 arena, and a
/// boss with three phases, a handpicked arsenal of abilities and a set of
/// defensive passives. Each chimera is a fusion of two or three wild creatures,
/// which is where its stat line, ability set and silhouette come from.
enum ChimeraType {
  gryphonPrime(
    'Gryphon Prime',
    '🦁🦅',
    800,
    3.5,
    'Dive + Shockwave',
    'elite_mountain',
    0xFF8A6A3B,
    <ChimeraAbilityKind>{
      ChimeraAbilityKind.diveStrike,
      ChimeraAbilityKind.shockwave,
    },
    <ChimeraDefenseKind>{ChimeraDefenseKind.ironHide},
    'Lion courage, eagle sky. It dives before you see the wings.',
  ),
  basilisk(
    'Basilisk',
    '🐉🐍',
    900,
    4.0,
    'Poison Breath + Petrify',
    'elite_swamp',
    0xFF3F6F3A,
    <ChimeraAbilityKind>{
      ChimeraAbilityKind.poisonBreath,
      ChimeraAbilityKind.petrify,
    },
    <ChimeraDefenseKind>{ChimeraDefenseKind.regen},
    'A gaze that hardens blood, breath that rots steel.',
  ),
  ravager(
    'Ravager',
    '🐗🦁',
    1200,
    4.5,
    'Charge + Roar',
    'elite_fortress',
    0xFF7C4A2D,
    <ChimeraAbilityKind>{
      ChimeraAbilityKind.charge,
      ChimeraAbilityKind.roar,
      ChimeraAbilityKind.shockwave,
    },
    <ChimeraDefenseKind>{
      ChimeraDefenseKind.ironHide,
      ChimeraDefenseKind.damageReflect,
    },
    'Armour plate over berserker muscle. It does not stop.',
  ),
  wyvern(
    'Wyvern',
    '🪶🐉',
    700,
    4.0,
    'Fireballs + Dive',
    'elite_cliff',
    0xFF3F6C8A,
    <ChimeraAbilityKind>{
      ChimeraAbilityKind.fireballs,
      ChimeraAbilityKind.diveStrike,
    },
    <ChimeraDefenseKind>{
      ChimeraDefenseKind.dodgeInstinct,
      ChimeraDefenseKind.energyShield,
    },
    'A sky-killer that breathes fire and never lands straight.',
  ),
  deathroll(
    'Deathroll',
    '🐍🐗',
    1000,
    4.5,
    'Roll + Venom Aura',
    'elite_dunes',
    0xFF9C7B4A,
    <ChimeraAbilityKind>{
      ChimeraAbilityKind.rollAttack,
      ChimeraAbilityKind.poisonBreath,
      ChimeraAbilityKind.charge,
    },
    <ChimeraDefenseKind>{
      ChimeraDefenseKind.regen,
      ChimeraDefenseKind.summonMinions,
    },
    'The dunes swallow what it leaves behind.',
  ),
  rannsChimera(
    "Rann's Chimera",
    '🦁🐗🪶',
    1800,
    6.0,
    'Full Arsenal',
    'elite_throne',
    0xFFB45309,
    <ChimeraAbilityKind>{
      ChimeraAbilityKind.diveStrike,
      ChimeraAbilityKind.charge,
      ChimeraAbilityKind.tailSwipe,
      ChimeraAbilityKind.fireballs,
      ChimeraAbilityKind.shockwave,
    },
    <ChimeraDefenseKind>{
      ChimeraDefenseKind.ironHide,
      ChimeraDefenseKind.energyShield,
      ChimeraDefenseKind.mirrorImage,
    },
    'Built from the remains of every king the throne has eaten.',
  ),
  omegaChimera(
    'Omega Chimera',
    '🐲',
    3000,
    8.0,
    'Reality Shift',
    'elite_void',
    0xFF5B4B8A,
    <ChimeraAbilityKind>{
      ChimeraAbilityKind.lightningStrike,
      ChimeraAbilityKind.fireballs,
      ChimeraAbilityKind.shockwave,
      ChimeraAbilityKind.petrify,
      ChimeraAbilityKind.rollAttack,
      ChimeraAbilityKind.roar,
      ChimeraAbilityKind.diveStrike,
      ChimeraAbilityKind.tailSwipe,
    },
    <ChimeraDefenseKind>{
      ChimeraDefenseKind.phaseShift,
      ChimeraDefenseKind.energyShield,
      ChimeraDefenseKind.damageReflect,
      ChimeraDefenseKind.summonMinions,
      ChimeraDefenseKind.mirrorImage,
    },
    'The last fusion. It fights like all of them at once.',
  );

  const ChimeraType(
    this.label,
    this.emoji,
    this.hp,
    this.speedRating,
    this.signature,
    this.arenaId,
    this.colorValue,
    this.abilities,
    this.defenses,
    this.tagline,
  );

  /// Display name ("Gryphon Prime").
  final String label;

  /// Fusion emoji pair shown on cards ("🦁🦅").
  final String emoji;

  /// Exact HP from the design table.
  final double hp;

  /// 3.5 - 8.0 speed rating; 1 rating point = 12 world units/s.
  final double speedRating;

  /// One line summary of the signature moves.
  final String signature;

  /// Elite arena id (see `EliteArenas`).
  final String arenaId;

  /// Body tint.
  final int colorValue;

  /// Abilities this chimera owns, in unlock order.
  final Set<ChimeraAbilityKind> abilities;

  /// Defensive passives this chimera owns.
  final Set<ChimeraDefenseKind> defenses;

  final String tagline;

  Color get color => Color(colorValue);

  /// Movement speed in world units per second.
  double get speed => 70 + speedRating * 12;

  /// Melee damage of a single claw or bite.
  double get damage => 14 + speedRating * 3;

  /// Body radius (46 - 62 world units).
  double get bodyRadius => 44 + (speedRating - 3.5) * 3.2;

  /// The wild creature whose skeleton this fusion is based on.
  CreatureType get baseCreature {
    switch (this) {
      case ChimeraType.gryphonPrime:
      case ChimeraType.rannsChimera:
        return CreatureType.griffin;
      case ChimeraType.basilisk:
      case ChimeraType.deathroll:
        return CreatureType.venomtail;
      case ChimeraType.ravager:
        return CreatureType.ironboar;
      case ChimeraType.wyvern:
      case ChimeraType.omegaChimera:
        return CreatureType.drake;
    }
  }

  /// Suggested level before the trial should be attempted.
  int get recommendedLevel => 60 + index * 42;

  static ChimeraType? byName(String? name) {
    if (name == null) {
      return null;
    }
    for (final ChimeraType type in ChimeraType.values) {
      if (type.name == name) {
        return type;
      }
    }
    return null;
  }
}

/// A single elite trial: one chimera, one chest, one grade.
class EliteTrial {
  const EliteTrial({
    required this.type,
    required this.coinReward,
    required this.xpReward,
    required this.unlockAfterLevel,
  });

  final ChimeraType type;

  /// Base bounty before the grade multiplier.
  final int coinReward;

  /// XP granted for winning.
  final int xpReward;

  /// Campaign level that has to be cleared before the trial opens.
  final int unlockAfterLevel;

  /// Chest tier rolled from the awarded grade.
  ChimeraArmorKind get armorDrop => ChimeraArmorKind.forChimera(type);

  static const List<EliteTrial> trials = <EliteTrial>[
    EliteTrial(
      type: ChimeraType.gryphonPrime,
      coinReward: 2500,
      xpReward: 600,
      unlockAfterLevel: 50,
    ),
    EliteTrial(
      type: ChimeraType.basilisk,
      coinReward: 3500,
      xpReward: 750,
      unlockAfterLevel: 100,
    ),
    EliteTrial(
      type: ChimeraType.ravager,
      coinReward: 4500,
      xpReward: 900,
      unlockAfterLevel: 150,
    ),
    EliteTrial(
      type: ChimeraType.wyvern,
      coinReward: 5500,
      xpReward: 1050,
      unlockAfterLevel: 200,
    ),
    EliteTrial(
      type: ChimeraType.deathroll,
      coinReward: 6500,
      xpReward: 1200,
      unlockAfterLevel: 250,
    ),
    EliteTrial(
      type: ChimeraType.rannsChimera,
      coinReward: 8500,
      xpReward: 1500,
      unlockAfterLevel: 300,
    ),
    EliteTrial(
      type: ChimeraType.omegaChimera,
      coinReward: 12000,
      xpReward: 2000,
      unlockAfterLevel: 350,
    ),
  ];

  /// Alias kept for the elite battle constructor and the codex UI.
  static const List<EliteTrial> all = trials;

  /// Alias kept for the elite battle constructor and the codex UI.
  static const List<EliteTrial> all = trials;

  /// Looks a trial up by fusion type (never null).
  static EliteTrial of(ChimeraType type) {
    for (final EliteTrial trial in trials) {
      if (trial.type == type) {
        return trial;
      }
    }
    return trials.first;
  }

  /// 0-based trial index, used by `BattleConfig.elite`.
  static int indexOf(ChimeraType type) => of(type).type.index;
}

/// The fusion boss simulation.
///
/// A [Chimera] is an [Npc] with a far richer brain: three health phases, a
/// handpicked arsenal of ten possible attacks, up to eight defensive passives,
/// a dash system with contact damage, minion and clone summoning, and its own
/// procedural renderer.
class Chimera extends Npc {
  Chimera({
    required this.type,
    required int fighterId,
    required Vector2 position,
    double difficulty = 1.0,
    bool assistMode = false,
  })  : abilities = ChimeraAbilityFactory.buildAll(type.abilities),
        defenses = ChimeraDefenseFactory.buildAll(type.defenses),
        super(
          type: type.baseCreature,
          fighterId: fighterId,
          factionId: 900 + type.index,
          position: position,
          difficulty: difficulty,
          elite: true,
          boss: true,
          permanent: true,
          hpOverride: type.hp * (assistMode ? 0.85 : 1.0),
          nameOverride: type.label,
        ) {
    radius = type.bodyRadius;
    speed = type.speed;
    damage = type.damage;
    defensePercent = 0.15;
  }

  final ChimeraType type;

  /// Every attack this chimera can ever use, in unlock order.
  final List<ChimeraAbility> abilities;

  /// Every defensive passive this chimera owns.
  final List<ChimeraDefense> defenses;

  // ------------------------------------------------------------------- state
  ChimeraPhaseState phaseState = ChimeraPhaseState.phases.first;

  /// Ability currently winding up (telegraphing), if any.
  ChimeraAbility? pendingAbility;

  /// Seconds left of the current wind-up.
  double windupLeft = 0;

  /// Seconds until the next attack decision.
  double attackTimer = 2.0;

  /// Last attack used, so the AI never repeats itself twice in a row.
  ChimeraAbility? lastAbility;

  /// Dash state.
  double _dashSpeed = 0;
  double _dashLeft = 0;
  double _dashContact = 0;
  double _dashStun = 0;
  double _dashKnockback = 0;
  bool _dashArmoured = false;
  final Set<int> _dashHits = <int>{};

  /// Mirror clone state.
  Npc? clone;
  double cloneLife = 0;

  /// Time spent since the fight started (drives ambient animation).
  double age = 0;

  /// Animation clock; ticks faster in later phases (wing and tail motion).
  double enragePulse = 0;

  /// Seconds left of the "dodged a hit" blink.
  double dodgeFlashTimer = 0;

  /// Battle reference for late callouts (miss text, ability announcements).
  BattleGame? lastGame;

  /// True while the energy shield is up.
  bool get shieldActive => shield > 0;

  /// Body rotation used by the renderer while rolling.
  double rollSpin = 0;

  /// Guards against double phase banners.
  int _lastPhaseIndex = 0;

  /// True while a dash is in progress.
  bool get isDashing => _dashLeft > 0;

  /// True while the chimera is winding an attack up.
  bool get isWindingUp => pendingAbility != null;

  /// 0..1 progress of the current wind-up (used by the renderer + HUD).
  double get windupProgress {
    final ChimeraAbility? ability = pendingAbility;
    if (ability == null || ability.telegraph <= 0) {
      return 0;
    }
    return (1 - windupLeft / ability.telegraph).clamp(0.0, 1.0);
  }

  /// True while the chimera has a living clone in the arena.
  bool get hasClone => clone != null && clone!.alive;

  /// Damage of one claw swipe at the current phase.
  double get contactDamage => damage * damageMultiplier;

  /// Armour multiplier while rolling.
  double get _armourMultiplier => _dashArmoured && isDashing ? 0.6 : 1.0;

  @override
  String get displayName => type.label;

  @override
  Color get bodyColor => type.color;

  @override
  Color get accentColor => Color.lerp(type.color, const Color(0xFFF5F1EA), 0.3)!;

  // ------------------------------------------------------------------ update
  @override
  void updateNpc(double dt, BattleGame game) {
    updateTimers(dt, game);
    if (!alive) {
      return;
    }
    age += dt;
    enragePulse += dt * (1 + phaseState.index);
    if (dodgeFlashTimer > 0) {
      dodgeFlashTimer -= dt;
    }
    lastGame = game;
    _updatePhase(game);
    for (final ChimeraDefense defense in defenses) {
      defense.update(dt, this, game);
    }
    for (final ChimeraAbility ability in abilities) {
      ability.update(dt);
    }
    _updateClone(dt, game);
    if (isDashing) {
      _updateDash(dt, game);
      return;
    }
    if (isWindingUp) {
      _updateWindup(dt, game);
      return;
    }
    _selectTarget(dt, game);

    // Melee pressure when the warrior hugs the boss.
    _meleeTimer -= dt;
    final Fighter? target = this.target;
    if (target != null && target.alive && _meleeTimer <= 0) {
      final double contact = radius + target.radius + 14;
      if (position.distanceTo(target.position) <= contact) {
        _meleeTimer = math.max(0.7, 1.4 - phaseState.index * 0.25);
        target.takeDamage(contactDamage, source: this, label: '${type.label} claws');
        target.applyKnockback(target.position - position, 220);
        game.addEffect(
          HitSpark(
            position: target.position.clone(),
            radius: target.radius,
            color: accentColor,
            count: 6,
          ),
        );
        game.addFloatingText('CLAW', target.position.clone(), accentColor, size: 13);
      }
    }

    final Vector2 desired = ChimeraAi.desiredMovement(this, game);
    move(desired, dt, game);
    if (target != null && target.alive) {
      faceTowards(target.position - position);
    }
    separate(game);

    // Attack scheduling.
    attackTimer -= dt;
    if (attackTimer <= 0) {
      attackTimer = phaseState.attackInterval;
      final ChimeraAbility? chosen = ChimeraAi.chooseAbility(this, game);
      if (chosen != null) {
        _startWindup(chosen, game);
      }
    }
  }

  double _meleeTimer = 0.8;

  void _updatePhase(BattleGame game) {
    final ChimeraPhaseState next = ChimeraPhaseState.forHp(hpPercent);
    if (next.index == _lastPhaseIndex) {
      damageMultiplier = next.damageMultiplier;
      speedMultiplier = next.speedMultiplier;
      return;
    }
    _lastPhaseIndex = next.index;
    phaseState = next;
    damageMultiplier = next.damageMultiplier;
    speedMultiplier = next.speedMultiplier;
    attackTimer = math.min(attackTimer, 0.6);
    game.addFloatingText(
      next.banner,
      position.clone()..y -= radius * 1.6,
      type.color,
      size: 20,
    );
    game.addEffect(
      RingPulse(
        position: position.clone(),
        startRadius: radius * 3.4,
        endRadius: radius * 1.1,
        color: type.color,
        life: 0.7,
      ),
    );
    game.pushArea(center: position.clone(), radius: 320, force: 380);
    for (final ChimeraDefense defense in defenses) {
      defense.onPhaseChange(this, game);
    }
    if (next.minionBatch > 0) {
      summonMinions(game, next.minionBatch, hp: 150);
    }
  }

  void _selectTarget(double dt, BattleGame game) {
    retargetTimer -= dt;
    final Fighter? current = target;
    if (current != null && current.alive && retargetTimer > 0) {
      return;
    }
    retargetTimer = 0.6;
    // Always hunt the warrior: clone fights are for the minions.
    target = game.player;
  }

  // ------------------------------------------------------------------ attacks
  void _startWindup(ChimeraAbility ability, BattleGame game) {
    pendingAbility = ability;
    lastAbility = ability;
    windupLeft = phaseState.telegraph;
    telegraphing = true;
    abilityActive = phaseState.telegraph;
    game.addFloatingText(
      '${ability.icon} ${ability.label.toUpperCase()}',
      position.clone()..y -= radius * 1.3,
      type.color,
      size: 15,
    );
  }

  void _updateWindup(double dt, BattleGame game) {
    windupLeft -= dt;
    // Keep tracking the prey during the wind-up telegraph.
    final Fighter? target = this.target;
    if (target != null && target.alive) {
      faceTowards(target.position - position);
    }
    separate(game);
    if (windupLeft > 0) {
      return;
    }
    final ChimeraAbility? ability = pendingAbility;
    pendingAbility = null;
    telegraphing = false;
    if (ability != null) {
      ability.startCooldown();
      ability.fire(this, game);
      abilityActive = 0.8;
    }
  }

  @override
  void attack(Fighter victim, BattleGame game) {
    victim.takeDamage(attackDamage, source: this, label: type.label);
  }

  // -------------------------------------------------------------------- dash
  /// Dashes to [destination], damaging hostiles it crosses on the way.
  void dashTo(
    BattleGame game, {
    required Vector2 destination,
    required double speed,
    double contactDamage = 0,
    double knockback = 0,
    double stunSeconds = 0,
    bool armoured = false,
  }) {
    final Vector2 delta = destination - position;
    final double distance = delta.length;
    if (distance < 1) {
      return;
    }
    _dashSpeed = speed;
    _dashLeft = (distance / speed).clamp(0.15, 1.1);
    _dashContact = contactDamage;
    _dashKnockback = knockback;
    _dashStun = stunSeconds;
    _dashArmoured = armoured;
    _dashHits.clear();
    velocity
      ..setFrom(delta)
      ..normalize()
      ..scale(speed);
    if (armoured) {
      rollSpin = 0;
    }
    game.addFloatingText('DASH', position.clone()..y -= radius * 1.2, accentColor, size: 13);
  }

  void _updateDash(double dt, BattleGame game) {
    _dashLeft -= dt;
    rollSpin += dt * 9;
    // Keep the velocity alive so the charge actually travels.
    if (velocity.length2 < 1) {
      velocity.setFrom(facingVector..scale(_dashSpeed));
    }
    velocity
      ..normalize()
      ..scale(_dashSpeed);
    faceTowards(velocity);
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;
    game.arena.resolve(this);

    if (_dashContact > 0) {
      final double contactRange = radius * 1.15;
      for (final Fighter other in game.fighters) {
        if (identical(other, this) || !other.alive || other.factionId == factionId) {
          continue;
        }
        if (_dashHits.contains(other.fighterId)) {
          continue;
        }
        if (position.distanceTo(other.position) > contactRange + other.radius) {
          continue;
        }
        _dashHits.add(other.fighterId);
        other.takeDamage(_dashContact, source: this, label: '${type.label} trample');
        if (_dashKnockback > 0) {
          other.applyKnockback(other.position - position, _dashKnockback);
        }
        if (_dashStun > 0) {
          other.applyStun(_dashStun);
        }
        game.addEffect(
          HitSpark(
            position: other.position.clone(),
            radius: other.radius,
            color: accentColor,
            count: 8,
          ),
        );
      }
    }
    if (_dashLeft <= 0) {
      _dashArmoured = false;
      velocity.scale(0.2);
    }
  }

  /// Unit vector of the current facing (used to rebuild dash velocity).
  Vector2 get facingVector => Vector2(math.cos(facing), math.sin(facing));

  // --------------------------------------------------------------- abilities
  /// Damages every hostile inside a circle and paints a ring.
  void areaDamage(
    BattleGame game, {
    required double radius,
    required double damage,
    double knockback = 0,
    String label = '',
    Color? color,
    double spin = 0,
  }) {
    game.damageArea(
      center: position.clone(),
      radius: radius,
      damage: damage,
      source: this,
      label: label.isEmpty ? type.label : label,
    );
    if (knockback > 0) {
      game.pushArea(center: position.clone(), radius: radius, force: knockback);
    }
    final Color ringColor = color ?? accentColor;
    game.addEffect(
      RingPulse(
        position: position.clone(),
        startRadius: radius * 0.35,
        endRadius: radius,
        color: ringColor,
        life: 0.45,
      ),
    );
    if (spin > 0) {
      rollSpin += spin;
    }
  }

  /// Damages hostiles inside a cone in front of the chimera.
  void coneDamage(
    BattleGame game, {
    required double range,
    required double arc,
    required double damage,
    int poisonStacks = 0,
    double knockback = 0,
    String label = '',
    Color? color,
  }) {
    for (final Fighter other in game.fighters) {
      if (identical(other, this) || !other.alive || other.factionId == factionId) {
        continue;
      }
      final Vector2 delta = other.position - position;
      final double distance = delta.length;
      if (distance > range + other.radius) {
        continue;
      }
      final double angle = math.atan2(delta.y, delta.x);
      if (delta.length2 > 0.001 && angleDelta(angle, facing).abs() > arc / 2) {
        continue;
      }
      other.takeDamage(damage, source: this, label: label.isEmpty ? type.label : label);
      if (poisonStacks > 0) {
        PoisonEffect.apply(other, stacks: poisonStacks, game: game);
      }
      if (knockback > 0) {
        other.applyKnockback(delta, knockback);
      }
    }
    game.addEffect(
      PoisonCone(
        origin: position.clone(),
        facing: facing,
        arc: arc,
        range: range,
        color: color ?? accentColor,
      ),
    );
  }

  /// Launches a spread of homing fireballs at the warrior.
  void spawnFireballVolley(
    BattleGame game, {
    int count = 3,
    required double damage,
    double speed = 340,
  }) {
    final Fighter target = game.player;
    final Vector2 toTarget = target.position - position;
    if (toTarget.length2 < 0.001) {
      return;
    }
    final double base = math.atan2(toTarget.y, toTarget.x);
    for (int i = 0; i < count; i++) {
      final double spread = (i - (count - 1) / 2) * 0.22;
      final Vector2 direction = Vector2(
        math.cos(base + spread),
        math.sin(base + spread),
      );
      game.projectiles.add(
        FireProjectile(
          position: position.clone()..add(direction.clone()..scale(radius * 0.8)),
          velocity: direction..scale(speed),
          damage: damage,
          factionId: factionId,
          owner: this,
          radius: 12,
          life: 4,
          homing: target,
          homingStrength: 1.6,
          color: const Color(0xFFEA580C),
        ),
      );
    }
    game.addFloatingText('🔥 VOLLEY', position.clone()..y -= radius, type.color, size: 14);
  }

  /// Petrifying gaze: a harsh slow plus a short stun.
  void petrify(
    BattleGame game, {
    double slowAmount = 0.65,
    double slowSeconds = 3.0,
    double stunSeconds = 0.5,
  }) {
    final Fighter target = game.player;
    if (position.distanceTo(target.position) > 460) {
      return;
    }
    target.applySlow(slowAmount, slowSeconds);
    if (stunSeconds > 0) {
      target.applyStun(stunSeconds);
    }
    game.addEffect(
      RingPulse(
        position: target.position.clone(),
        startRadius: 140,
        endRadius: 30,
        color: const Color(0xFF78716C),
        life: 0.5,
      ),
    );
    game.addFloatingText('🪨 PETRIFIED', target.position.clone(), const Color(0xFF78716C), size: 15);
  }

  /// Fear pulse that shoves everyone away and, later on, calls reinforcements.
  void roarEffect(BattleGame game, {double radius = 400, double fearSeconds = 2.0}) {
    game.pushArea(center: position.clone(), radius: radius, force: 460);
    final Fighter target = game.player;
    if (position.distanceTo(target.position) <= radius) {
      target.fearTimer = math.max(target.fearTimer, fearSeconds);
      game.addFloatingText('FEARED', target.position.clone(), const Color(0xFF7C2D12), size: 15);
    }
    game.addEffect(
      RingPulse(
        position: position.clone(),
        startRadius: radius * 0.2,
        endRadius: radius,
        color: type.color,
        life: 0.6,
      ),
    );
    game.addFloatingText('📣 ROAR', position.clone()..y -= radius * 0.4, type.color, size: 18);
  }

  /// Summons [count] minions of the chimera's own bloodline.
  void summonMinions(BattleGame game, int count, {double hp = 150}) {
    for (int i = 0; i < count; i++) {
      final double angle = game.rng.nextDouble() * math.pi * 2;
      final Vector2 spot = position.clone()
        ..add(Vector2(math.cos(angle), math.sin(angle))..scale(radius * 2.4));
      final Npc minion = game.spawnNpc(
        type: type.baseCreature,
        position: spot,
        difficulty: 1.1,
        mirrorClone: true,
        permanent: true,
        hpOverride: hp,
        nameOverride: '${type.label} spawn',
      );
      minion.factionId = factionId;
    }
    game.addFloatingText('🐾 MINIONS', position.clone()..y -= radius, type.color, size: 15);
  }

  /// Splits off a fighting clone that lives for [life] seconds.
  void summonMirrorImage(BattleGame game, {double life = 10}) {
    if (hasClone) {
      return;
    }
    final Vector2 spot = position.clone()..add(Vector2(math.cos(age), math.sin(age))..scale(radius * 2));
    final Npc image = game.spawnNpc(
      type: type.baseCreature,
      position: spot,
      difficulty: 0.9,
      mirrorClone: true,
      permanent: true,
      hpOverride: 120,
      nameOverride: 'Mirror ${type.label}',
    );
    image.factionId = factionId;
    clone = image;
    cloneLife = life;
    game.addEffect(
      RingPulse(
        position: spot,
        startRadius: 20,
        endRadius: radius * 2,
        color: const Color(0xFF7E22CE),
        life: 0.5,
      ),
    );
    game.addFloatingText('🎭 MIRROR IMAGE', position.clone()..y -= radius * 1.4, const Color(0xFF7E22CE), size: 15);
  }

  void _updateClone(double dt, BattleGame game) {
    if (clone == null) {
      return;
    }
    if (!clone!.alive) {
      clone = null;
      return;
    }
    cloneLife -= dt;
    if (cloneLife <= 0) {
      final Npc image = clone!;
      image.alive = false;
      image.deathHandled = true;
      game.addEffect(
        DeathBurst(position: image.position.clone(), color: const Color(0xFF7E22CE), radius: 40),
      );
      game.addFloatingText('CLONE FADES', image.position.clone(), const Color(0xFF7E22CE), size: 14);
      clone = null;
    }
  }

  /// Small floating callout for abilities that land on the ground.
  void announceAbility(BattleGame game, Vector2 at, String text) {
    game.addFloatingText(text, at, type.color, size: 14);
  }

  /// Predicts where a fighter will be in [lead] seconds.
  static Vector2 predict(Fighter target, double lead) {
    return target.position.clone()
      ..add(target.velocity.clone()..scale(lead));
  }

  // ------------------------------------------------------------------ damage
  @override
  void takeDamage(
    double raw, {
    Fighter? source,
    bool ignoreDefense = false,
    bool environmental = false,
    String label = '',
  }) {
    if (!alive) {
      return;
    }
    double incoming = raw;
    bool dodged = false;
    for (final ChimeraDefense defense in defenses) {
      final double before = incoming;
      incoming = defense.modifyIncomingDamage(this, incoming);
      if (incoming <= 0 && before > 0) {
        dodged = true;
      }
    }
    if (dodged) {
      dodgeFlashTimer = 0.25;
      lastGame?.addFloatingText('MISS', position.clone(), const Color(0xFFF5F1EA), size: 14);
      return;
    }
    incoming *= _armourMultiplier;
    final double before = hp;
    super.takeDamage(
      incoming,
      source: source,
      ignoreDefense: ignoreDefense,
      environmental: environmental,
      label: label,
    );
    final double dealt = before - hp;
    if (dealt > 0 && source != null) {
      final double reflect = defenses.fold<double>(
        0,
        (double sum, ChimeraDefense defense) => sum + defense.reflectPercent,
      );
      if (reflect > 0) {
        source.takeDamage(
          dealt * reflect,
          ignoreDefense: true,
          environmental: true,
          label: '${type.label} reflect',
        );
      }
    }
  }

  @override
  void onDeath(BattleGame game) {
    super.onDeath(game);
    game.addFloatingText(
      '${type.label} FALLS',
      position.clone()..y -= radius * 1.4,
      type.color,
      size: 24,
    );
    game.addEffect(
      RingPulse(
        position: position.clone(),
        startRadius: radius * 5,
        endRadius: radius,
        color: type.color,
        life: 0.9,
      ),
    );
    for (int i = 0; i < 3; i++) {
      game.addEffect(
        DeathBurst(
          position: position.clone()
            ..add(
              Vector2(
                (game.rng.nextDouble() - 0.5) * radius * 4,
                (game.rng.nextDouble() - 0.5) * radius * 4,
              ),
            ),
          color: type.color,
          radius: radius * (0.6 + i * 0.3),
        ),
      );
    }
    // The clone dies with its master.
    final Npc? image = clone;
    if (image != null && image.alive) {
      image.alive = false;
      image.deathHandled = true;
    }
    clone = null;
  }

  @override
  void renderBody(Canvas canvas) {
    ChimeraRenderer.renderBody(canvas, this);
  }
}

/// Green poison cone effect used by breath attacks.
class PoisonCone extends GameEffect {
  PoisonCone({
    required this.origin,
    required this.facing,
    required this.arc,
    required this.range,
    required this.color,
  }) : super(life: 0.4);

  final Vector2 origin;
  final double facing;
  final double arc;
  final double range;
  final Color color;

  @override
  void render(Canvas canvas) {
    final double t = progress;
    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withAlpha(((1 - t) * 110).round());
    final Path cone = Path()
      ..moveTo(origin.x, origin.y)
      ..arcTo(
        Rect.fromCircle(center: origin.toOffset(), radius: range * (0.75 + t * 0.25)),
        facing - arc / 2,
        arc,
        false,
      )
      ..close();
    canvas.drawPath(cone, paint);
    canvas.drawCircle(
      origin.toOffset(),
      range * 0.25 * (1 - t),
      Paint()..color = color.withAlpha(((1 - t) * 160).round()),
    );
  }
}
