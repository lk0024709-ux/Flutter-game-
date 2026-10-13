import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'armor.dart';
import 'battle_game.dart';
import 'effects.dart';
import 'fighter.dart';
import 'levels/level_modifier.dart';
import 'loot/chimera_armor.dart';
import 'loot/elite_power.dart';
import 'npc.dart';
import 'powerups.dart';
import 'store_state.dart';
import 'weapon.dart';

/// The lone warrior.
///
/// Owns the sword arc hit detection, armour effects, elite perks, boosters and
/// the revive economy. Base stats: 120 HP, 220 speed, radius 18.
class Player extends Fighter {
  Player({
    required int fighterId,
    required Vector2 position,
    required WeaponTier weapon,
    required ArmorRank armor,
    required ChimeraArmorKind? eliteArmor,
    required Set<ElitePowerKind> powers,
    required Set<BoosterKind> boosters,
    required this.assistMode,
    required this.ironmanMode,
    required List<LevelModifier> modifiers,
    required this.isEliteBattle,
    required this.coinBonusMultiplier,
    required int revives,
    required this.baseMaxHp,
  })  : weapon = weapon,
        armor = armor,
        eliteArmor = eliteArmor,
        powers = powers,
        boosters = boosters,
        modifiers = modifiers,
        revives = revives,
        super(
          fighterId: fighterId,
          factionId: 0,
          position: position,
          baseRadius: 18,
          maxHp: ironmanMode
              ? 1
              : (baseMaxHp + armor.hpBonus + (eliteArmor?.hpBonus ?? 0)) *
                  (assistMode ? 2.0 : 1.0),
          baseSpeed: 220,
          baseDamage: weapon.damage,
          reach: weapon.reach,
          attackInterval: weapon.cooldown,
          defensePercent: armor.defensePercent,
          isPlayer: true,
        );

  /// Fallback HP before armour (120 in campaign, 240 in elite trials).
  final double baseMaxHp;

  WeaponTier weapon;
  ArmorRank armor;
  ChimeraArmorKind? eliteArmor;
  final Set<ElitePowerKind> powers;
  final Set<BoosterKind> boosters;
  final List<LevelModifier> modifiers;

  final bool assistMode;
  final bool ironmanMode;
  final bool isEliteBattle;

  /// Applied to every coin earned in the battle (title bonuses).
  final double coinBonusMultiplier;

  int revives;
  int kills = 0;

  /// Movement request written by the on-screen joystick.
  final Vector2 inputDirection = Vector2.zero();
  bool attackRequested = false;

  /// Sword animation (0 while idle, 0..1 through the sweep).
  double swingProgress = 0;
  double _swingTimer = 0;
  bool get swinging => _swingTimer > 0;

  final List<ActivePowerUp> activePowers = <ActivePowerUp>[];

  bool _ironWillUsed = false;
  bool _phaseShiftUsed = false;
  bool _omegaShiftUsed = false;
  double _diveDashTimer = 8;
  double _stormcallerTimer = 10;
  double _stormAuraTimer = 0;
  double _poisonAuraTimer = 0;
  double _regenAccumulator = 0;
  final math.Random _rng = math.Random();

  static const double swingDuration = 0.22;

  // ------------------------------------------------------------------ helpers
  /// Total damage reduction (armour + elite armour + boosters + powers).
  double get totalDefensePercent => defensePercent;

  bool hasPower(ElitePowerKind power) => powers.contains(power);

  bool hasEliteArmorEffect(EliteArmorEffect effect) {
    final ChimeraArmorKind? kind = eliteArmor;
    if (kind == null) {
      return false;
    }
    return kind.hasEffect(effect);
  }

  bool get hasMagnet => hasPower(ElitePowerKind.treasureHunter) || hasActive(PowerUpKind.magnet);

  bool hasActive(PowerUpKind kind) =>
      activePowers.any((ActivePowerUp p) => p.kind == kind && p.remaining > 0);

  bool hasModifier(LevelModifier modifier) => modifiers.contains(modifier);

  /// Effective attack cooldown after Swift Strike / Slow Forge.
  double get attackCooldownDuration {
    double cooldown = weapon.cooldown;
    if (hasPower(ElitePowerKind.swiftStrike)) {
      cooldown /= 1.2;
    }
    if (hasModifier(LevelModifier.slowForge)) {
      cooldown *= 1.3;
    }
    return cooldown;
  }

  /// Chest spawn multiplier from the chest magnet power-up.
  int get chestSpawnMultiplier => hasActive(PowerUpKind.magnet) ? 2 : 1;

  // ------------------------------------------------------------------ update
  void updatePlayer(double dt, BattleGame game) {
    updateTimers(dt, game);
    if (!alive) {
      return;
    }
    refreshModifiers(game);

    if (_swingTimer > 0) {
      _swingTimer = math.max(0.0, _swingTimer - dt);
      swingProgress = _swingTimer <= 0 ? 0 : 1 - (_swingTimer / swingDuration);
      if (_swingTimer <= 0) {
        swingProgress = 0;
      }
    }

    if (attackRequested) {
      attackRequested = false;
      performAttack(game);
    }

    _updatePowerUps(dt);
    _updatePassiveEffects(dt, game);

    move(inputDirection, dt, game);
    separate(game);
  }

  void _updatePowerUps(double dt) {
    for (final ActivePowerUp power in activePowers) {
      power.remaining -= dt;
    }
    activePowers.removeWhere((ActivePowerUp p) => p.remaining <= 0);
  }

  void _updatePassiveEffects(double dt, BattleGame game) {
    final bool healingBlocked = hasModifier(LevelModifier.noHeal);
    double healPerSecond = 0;
    if (!healingBlocked) {
      if (armor.effect == ArmorEffect.regen) {
        healPerSecond += 5;
      }
      if (hasPower(ElitePowerKind.regeneration)) {
        healPerSecond += 2;
      }
      healPerSecond *= game.healMultiplierForPlayer;
    }
    if (healPerSecond > 0 && hp < maxHp) {
      _regenAccumulator += healPerSecond * dt;
      if (_regenAccumulator >= 0.25) {
        heal(_regenAccumulator);
        _regenAccumulator = 0;
      }
    }

    // Stormcaller: lightning strikes the nearest beast every 10 seconds.
    if (hasPower(ElitePowerKind.stormcaller)) {
      _stormcallerTimer -= dt;
      if (_stormcallerTimer <= 0) {
        _stormcallerTimer = 10;
        final Npc? victim = game.nearestNpc(position);
        if (victim != null) {
          game.damageArea(
            center: victim.position.clone(),
            radius: 60,
            damage: 35,
            source: this,
            label: 'Stormcaller',
          );
          game.addEffect(
            TelegraphRing(
              position: victim.position.clone(),
              radius: 60,
              color: const Color(0xFF64748B),
              life: 0.35,
            ),
          );
        }
      }
    }

    // Omega Aura: passive damage around the warrior.
    if (hasPower(ElitePowerKind.omegaAura)) {
      _stormAuraTimer -= dt;
      if (_stormAuraTimer <= 0) {
        _stormAuraTimer = 0.5;
        game.damageArea(
          center: position.clone(),
          radius: 110,
          damage: 5 * 0.5,
          source: this,
          label: 'Omega aura',
        );
      }
    }

    // Deathroll Shell: poison aura that chews on nearby enemies.
    if (hasEliteArmorEffect(EliteArmorEffect.poisonAura)) {
      _poisonAuraTimer -= dt;
      if (_poisonAuraTimer <= 0) {
        _poisonAuraTimer = 0.5;
        for (final Npc npc in game.npcs) {
          if (!npc.alive) {
            continue;
          }
          if (position.distanceTo(npc.position) < 110) {
            npc.takeDamage(4 * 0.5, source: this, label: 'Poison aura');
          }
        }
      }
    }

    // Gryphon Plate: an automatic dive dash at the nearest enemy every 8s.
    if (hasEliteArmorEffect(EliteArmorEffect.diveDash)) {
      _diveDashTimer -= dt;
      if (_diveDashTimer <= 0) {
        final Npc? victim = game.nearestNpc(position);
        if (victim != null && position.distanceTo(victim.position) < 320) {
          _diveDashTimer = 8;
          final Vector2 direction = (victim.position - position)..normalize();
          applyKnockback(direction, 520);
          game.damageArea(
            center: victim.position.clone(),
            radius: 70,
            damage: 20,
            source: this,
            label: 'Dive dash',
          );
          game.addEffect(
            RingPulse(
              position: victim.position.clone(),
              startRadius: 10,
              endRadius: 70,
              color: const Color(0xFFB45309),
              life: 0.35,
            ),
          );
        } else {
          _diveDashTimer = 2;
        }
      }
    }
  }

  /// Recomputes damage / defense / speed from every source each frame.
  void refreshModifiers(BattleGame game) {
    double offense = 1.0;
    if (boosters.contains(BoosterKind.damageElixir)) {
      offense *= 1.25;
    }
    if (hasActive(PowerUpKind.fury)) {
      offense *= 1.25;
    }
    if (isEliteBattle) {
      offense *= 1.5;
    }
    if (assistMode) {
      offense *= 1.3;
    }
    damageMultiplier = offense;

    double reduction = armor.defensePercent;
    final ChimeraArmorKind? elite = eliteArmor;
    if (elite != null) {
      reduction += elite.defensePercent;
    }
    if (boosters.contains(BoosterKind.ironSkin)) {
      reduction += 0.20;
    }
    if (hasActive(PowerUpKind.ward)) {
      reduction += 0.30;
    }
    if (hasModifier(LevelModifier.ironSkinless)) {
      reduction *= 0.5;
    }
    if (hasModifier(LevelModifier.noShield)) {
      reduction *= 0.5;
    }
    defensePercent = reduction.clamp(0.0, 0.8);

    double movement = 1.0 + armor.speedBonusPercent + (elite?.speedBonusPercent ?? 0);
    if (hasActive(PowerUpKind.swift)) {
      movement += 0.20;
    }
    speedMultiplier = movement;

    // Assist mode also softens incoming damage.
    if (assistMode) {
      incomingDamageMultiplier = 0.7;
    }

    vampirism = hasPower(ElitePowerKind.vampirism) ? 0.05 : 0.0;
    if (hasEliteArmorEffect(EliteArmorEffect.poisonImmunity)) {
      poisonImmune = true;
    }
  }

  // ------------------------------------------------------------------ combat
  void requestAttack() {
    attackRequested = true;
  }

  /// Sword swing with arc hit detection.
  void performAttack(BattleGame game) {
    if (!canAttack) {
      return;
    }
    attackCooldown = attackCooldownDuration;
    _swingTimer = swingDuration;
    swingProgress = 0.0001;

    final double arc = weapon.attackArc;
    final double reach = weapon.reach + (eliteArmor?.reachBonus ?? 0);

    game.addEffect(
      SlashEffect(
        position: position.clone(),
        facing: facing,
        arc: arc,
        reach: reach,
        color: isEliteBattle ? const Color(0xFFF5F5F4) : const Color(0xFFF5F1EA),
      ),
    );

    // Gather every beast inside the arc.
    final List<Npc> candidates = <Npc>[];
    for (final Npc npc in game.npcs) {
      if (!npc.alive) {
        continue;
      }
      if (isInsideArc(
        origin: position,
        targetPosition: npc.position,
        targetRadius: npc.radius,
        reach: reach,
        facing: facing,
        arc: arc,
      )) {
        candidates.add(npc);
      }
    }
    candidates.sort((Npc a, Npc b) =>
        position.distanceTo(a.position).compareTo(position.distanceTo(b.position)));

    final int maxTargets = weapon.maxTargets; // trident+ hits two enemies
    bool landed = false;

    for (int i = 0; i < candidates.length && i < maxTargets; i++) {
      final Npc victim = candidates[i];
      landed = true;
      double damage = attackDamage;

      // Chimera Fury: every 5th landed hit deals triple damage.
      if (hasPower(ElitePowerKind.chimeraFury) && (hitCount + 1) % 5 == 0) {
        damage *= 3;
        game.addFloatingText(
          'FURY x3',
          victim.position.clone(),
          const Color(0xFFB91C1C),
          size: 16,
        );
      }
      // Apex Predator: bonus damage to wounded beasts.
      if (hasPower(ElitePowerKind.apexPredator) && victim.hpPercent < 0.3) {
        damage *= 1.25;
      }

      victim.takeDamage(damage, source: this, label: 'Sword');
      victim.wakeIfNeutral(game);
      hitCount++;

      game.addEffect(
        HitSpark(
          position: victim.position.clone(),
          radius: victim.radius,
          color: const Color(0xFFF5F1EA),
          count: 6,
        ),
      );
      game.addFloatingText(
        '-${damage.round()}',
        victim.position.clone(),
        const Color(0xFFF5F1EA),
        size: 14,
      );

      // Mythic Blade: 20% chance for a second strike.
      if (weapon.doubleHitChance > 0 && game.rng.nextDouble() < weapon.doubleHitChance) {
        victim.takeDamage(damage * 0.7, source: this, label: 'Double strike');
        game.addFloatingText(
          'DOUBLE',
          victim.position.clone(),
          const Color(0xFF7E22CE),
          size: 13,
        );
      }

      // Storm Blade: on-hit lightning burst.
      if (weapon.hasStormBurst) {
        game.damageArea(
          center: victim.position.clone(),
          radius: WeaponTier.stormBurstRadius,
          damage: WeaponTier.stormBurstDamage,
          source: this,
          label: 'Storm burst',
        );
        game.addEffect(
          StormBurst(position: victim.position.clone(), radius: WeaponTier.stormBurstRadius),
        );
      }
    }

    if (!landed) {
      // Reward precision even on a whiff: short arc whiff visual.
      game.addEffect(
        RingPulse(
          position: position.clone(),
          startRadius: reach * 0.3,
          endRadius: reach * 0.6,
          color: const Color(0x33F5F1EA),
          life: 0.18,
        ),
      );
    }

    // Destructible arena objects (cloning crystals, treasure seals).
    game.damageHazardsInArc(position, reach, facing, arc, 30);
  }

  /// Called by the battle when HP hits zero - consumes a revive if available.
  bool reviveNow(BattleGame game) {
    if (revives <= 0) {
      return false;
    }
    revives--;
    alive = true;
    hp = maxHp * 0.5;
    invulnTimer = 1.6;
    cleanse();
    game.addEffect(
      RingPulse(
        position: position.clone(),
        startRadius: 20,
        endRadius: 200,
        color: const Color(0xFFD97706),
        life: 0.6,
      ),
    );
    game.addFloatingText('REVIVED', position.clone(), const Color(0xFFD97706), size: 20);
    return true;
  }

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

    // Wyvern Wing: dodge instinct.
    final double dodge = eliteArmor?.dodgeChance ?? 0;
    if (!environmental && dodge > 0 && _rng.nextDouble() < dodge) {
      return;
    }

    // Ravager Hide: charge knockback resistance is handled where knockback is
    // applied (see [applyKnockback]).
    final double before = hp;
    super.takeDamage(
      raw,
      source: source,
      ignoreDefense: ignoreDefense,
      environmental: environmental,
      label: label,
    );
    final double applied = before - hp;
    if (applied <= 0) {
      return;
    }

    // Reflect effects (Legend armour, Basilisk Scale, Rann's Regalia).
    if (source != null) {
      double reflect = 0;
      if (armor.effect == ArmorEffect.reflect) {
        reflect += 0.10;
      }
      reflect += eliteArmor?.reflectPercent ?? 0;
      if (reflect > 0) {
        source.takeDamage(applied * reflect, environmental: true, label: 'Reflect');
      }
    }

    // Phase Shift: invulnerability when dropped below 20% HP.
    if (hasPower(ElitePowerKind.phaseShift) && !_phaseShiftUsed && hpPercent < 0.2 && alive) {
      _phaseShiftUsed = true;
      invulnTimer = 1.0;
      return;
    }
    if (hasEliteArmorEffect(EliteArmorEffect.phaseShift) && !_omegaShiftUsed && hpPercent < 0.33 && alive) {
      _omegaShiftUsed = true;
      invulnTimer = 1.5;
      return;
    }

    // Iron Will: survive one fatal hit with 1 HP.
    if (!alive && hasPower(ElitePowerKind.ironWill) && !_ironWillUsed) {
      _ironWillUsed = true;
      alive = true;
      hp = 1;
      invulnTimer = 1.2;
    }
  }

  @override
  void applyKnockback(Vector2 direction, double force) {
    double scaled = force;
    final double resist = eliteArmor?.knockbackResist ?? 0;
    if (resist > 0) {
      scaled *= (1 - resist).clamp(0.0, 1.0);
    }
    super.applyKnockback(direction, scaled);
  }

  // ------------------------------------------------------------------ render
  @override
  Color get bodyColor => const Color(0xFFD8C6A5);

  @override
  Color get accentColor => Color(armor.colorValue);

  @override
  String get displayName => 'Warrior';

  @override
  void renderBody(Canvas canvas) {
    final Color skin = const Color(0xFFC99A6B);
    final Color armorTint = Color(armor.colorValue);
    final Color leather = const Color(0xFF6B4F3A);

    // Cape / cloak behind the body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-8, 2), width: 34, height: 30),
      Paint()..color = const Color(0xFF7C2D12).withAlpha(200),
    );

    // Torso: rounded plate in the armour tint.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 26, height: 30),
        const Radius.circular(9),
      ),
      Paint()..color = Color.lerp(armorTint, const Color(0xFFF5F1EA), 0.35)!,
    );
    // Shoulder pads.
    canvas.drawCircle(Offset(-3, -13), 8, Paint()..color = armorTint);
    canvas.drawCircle(Offset(-3, 13), 8, Paint()..color = armorTint);
    // Belt.
    canvas.drawRect(
      Rect.fromLTWH(-11, 6, 22, 5),
      Paint()..color = leather,
    );

    // Head + helmet.
    canvas.drawCircle(const Offset(4, 0), 9, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(3, 0), radius: 10),
      -math.pi * 0.95,
      math.pi * 1.9,
      true,
      Paint()..color = Color.lerp(armorTint, const Color(0xFF1C1917), 0.25)!,
    );
    // Eye slit.
    canvas.drawRect(
      Rect.fromLTWH(9, -2.5, 6, 5),
      Paint()..color = const Color(0xFF1C1917),
    );

    // Shield on the off hand (appears once defense is meaningful).
    if (defensePercent >= 0.15) {
      final Offset shieldCentre = Offset(2, 18);
      canvas.drawCircle(
        shieldCentre,
        9,
        Paint()..color = Color.lerp(armorTint, const Color(0xFFF5F1EA), 0.5)!,
      );
      canvas.drawCircle(
        shieldCentre,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF7C2D12),
      );
      canvas.drawCircle(shieldCentre, 3, Paint()..color = const Color(0xFF7C2D12));
    }

    // Sword: sweeps through the attack arc while swinging.
    final double arc = weapon.attackArc;
    final double idleAngle = -0.5;
    final double t = swingProgress.clamp(0.0, 1.0);
    final double eased = 1 - math.pow(1 - t, 2).toDouble(); // easeOut, no Flutter dep
    final double sweep = swinging ? (-arc / 2) + arc * eased : idleAngle;
    canvas.save();
    canvas.translate(6, -14);
    canvas.rotate(sweep);
    // Grip.
    canvas.drawRect(
      Rect.fromLTWH(-4, -2.5, 12, 5),
      Paint()..color = leather,
    );
    // Guard.
    canvas.drawRect(
      Rect.fromLTWH(7, -7, 4, 14),
      Paint()..color = const Color(0xFFC9A227),
    );
    // Blade (length scales with weapon reach).
    final double bladeLength = (weapon.reach * 0.42).clamp(22.0, 62.0);
    final Path blade = Path()
      ..moveTo(11, -3.2)
      ..lineTo(11 + bladeLength, -1.2)
      ..lineTo(11 + bladeLength + 6, 0)
      ..lineTo(11 + bladeLength, 1.2)
      ..lineTo(11, 3.2)
      ..close();
    canvas.drawPath(blade, Paint()..color = const Color(0xFFE7E1D3));
    canvas.drawPath(
      Path()
        ..moveTo(11, 0)
        ..lineTo(11 + bladeLength + 4, 0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFB8B0A0),
    );
    // Trail while swinging.
    if (swinging) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: bladeLength * 0.9),
        -arc / 2 + arc * t - 0.5,
        0.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x66F5F1EA),
      );
    }
    canvas.restore();

    // Elite armour shimmer ring.
    if (eliteArmor != null) {
      canvas.drawCircle(
        Offset.zero,
        21,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Color(eliteArmor!.colorValue).withAlpha(150),
      );
    }
  }
}
