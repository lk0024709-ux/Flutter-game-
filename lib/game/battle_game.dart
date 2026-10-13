import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'weapon.dart';

enum CreatureType { griffin, drake, skyhawk, ironboar, venomtail }

class BattleGame extends FlameGame {
  BattleGame(this.weapon, this.onFinished);
  final WeaponTier weapon;
  final ValueChanged<bool> onFinished;
  final Vector2 movement = Vector2.zero();
  late Arena arena;
  double elapsed = 0;
  int get enemiesRemaining => arena.fighters.where((f) => !f.player && f.hp > 0).length;

  @override
  Future<void> onLoad() async {
    arena = Arena(this);
    world.add(arena);
    camera.viewfinder.zoom = 1;
    camera.follow(arena.player, maxSpeed: 900);
  }

  void move(Offset value) {
    movement.setValues(value.dx, value.dy);
    if (movement.length > 1) movement.normalize();
  }
}

class Arena extends Component with HasGameReference<BattleGame> {
  Arena(this.owner);
  final BattleGame owner;
  final List<Fighter> fighters = [];
  late Fighter player;
  bool ended = false;

  @override
  Future<void> onLoad() async {
    player = Fighter(player: true, maxHp: 120, damage: game.weapon.damage,
      range: game.weapon.reach, interval: game.weapon.cooldown, radius: 18,
      speed: 220, color: const Color(0xFFD97706))
      ..position = Vector2(1200, 1200);
    fighters.add(player);
    final stats = <List<num>>[
      [70,160,14,65,7,20,0xFFC2410C],
      [55,130,16,220,14,22,0xFF166534],
      [45,220,12,55,5,16,0xFF92400E],
      [120,110,20,60,11,26,0xFF44403C],
      [60,150,10,70,8,18,0xFF4D7C0F],
    ];
    for (var i = 0; i < 14; i++) {
      final s = stats[i % stats.length];
      final angle = i * pi * 2 / 14;
      final radius = 260 + (i % 4) * 70;
      final fighter = Fighter(player: false, maxHp: s[0].toDouble(),
        damage: s[2].toDouble(), range: s[3].toDouble(),
        interval: s[4] / 10, radius: s[5].toDouble(),
        speed: s[1].toDouble(), color: Color(s[6].toInt()))
        ..position = Vector2(1200 + cos(angle) * radius, 1200 + sin(angle) * radius);
      fighters.add(fighter);
    }
    addAll(fighters);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (ended) return;
    game.elapsed += dt;
    final alive = fighters.where((f) => f.hp > 0).toList();
    if (player.hp <= 0) { ended = true; game.onFinished(false); return; }
    if (alive.where((f) => !f.player).isEmpty) { ended = true; game.onFinished(true); return; }
    for (final fighter in alive) {
      fighter.cooldown = max(0, fighter.cooldown - dt);
      fighter.flash = max(0, fighter.flash - dt);
      if (fighter.player) {
        fighter.velocity = game.movement.clone();
        if (fighter.velocity.length2 > .01) {
          fighter.facing = atan2(fighter.velocity.y, fighter.velocity.x);
        }
      } else {
        Fighter? nearest;
        var best = double.infinity;
        for (final enemy in alive) {
          if (identical(enemy, fighter)) continue;
          final distance = fighter.position.distanceTo(enemy.position);
          if (distance < best) { best = distance; nearest = enemy; }
        }
        if (nearest != null) {
          final delta = nearest.position - fighter.position;
          fighter.facing = atan2(delta.y, delta.x);
          if (best > fighter.range) {
            fighter.velocity = delta.normalized();
          } else if (best < fighter.radius + nearest.radius + 8) {
            fighter.velocity = -delta.normalized() * .4;
          } else {
            fighter.velocity = Vector2(-sin(fighter.facing), cos(fighter.facing)) * .25;
            if (fighter.cooldown <= 0) fighter.attack();
          }
        }
      }
      fighter.move(dt);
    }
    for (var i = 0; i < alive.length; i++) {
      for (var j = i + 1; j < alive.length; j++) {
        final a = alive[i], b = alive[j];
        final delta = b.position - a.position;
        final distance = delta.length, minimum = a.radius + b.radius;
        if (distance > 0 && distance < minimum) {
          final push = delta.normalized() * ((minimum - distance) * .5);
          a.position -= push;
          b.position += push;
        }
      }
    }
  }
}

class Fighter extends PositionComponent with HasGameReference<BattleGame> {
  Fighter({required this.player, required this.maxHp, required this.damage,
    required this.range, required this.interval, required this.radius,
    required this.speed, required this.color}) : hp = maxHp;
  final bool player;
  final double maxHp, damage, range, interval, radius, speed;
  final Color color;
  double hp, cooldown = 0, flash = 0, facing = 0;
  Vector2 velocity = Vector2.zero();

  void attack() {
    if (cooldown > 0 || hp <= 0) return;
    cooldown = interval;
    final targets = game.arena.fighters.where((f) => !identical(f, this) && f.hp > 0).toList()
      ..sort((a, b) => position.distanceTo(a.position).compareTo(position.distanceTo(b.position)));
    var hits = 0;
    final maxHits = player && game.weapon == WeaponTier.trident ? 2 : 1;
    for (final target in targets) {
      final delta = target.position - position;
      if (delta.length > range + target.radius) continue;
      var angle = (atan2(delta.y, delta.x) - facing) % (2 * pi);
      if (angle > pi) angle -= 2 * pi;
      if (angle < -pi) angle += 2 * pi;
      final arc = game.weapon == WeaponTier.axe && player ? pi * 1.1 : pi * .85;
      if (angle.abs() > arc / 2) continue;
      target.takeDamage(damage);
      hits++;
      if (player && game.weapon.index >= WeaponTier.storm.index) {
        for (final nearby in targets) {
          if (!identical(nearby, target) && nearby.position.distanceTo(target.position) <= 60) {
            nearby.takeDamage(15);
          }
        }
      }
      if (hits >= maxHits) break;
    }
  }

  void takeDamage(double amount) { hp = max(0, hp - amount); flash = .16; }

  void move(double dt) {
    if (hp <= 0) return;
    if (velocity.length2 > 1) velocity.normalize();
    position += velocity * speed * dt;
    position.x = position.x.clamp(20, 2380);
    position.y = position.y.clamp(20, 2380);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (hp <= 0) {
      canvas.drawCircle(Offset.zero, radius * .7, Paint()..color = const Color(0x553B352C));
      return;
    }
    canvas.save();
    canvas.rotate(facing);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, radius * .6), width: radius * 2, height: radius * .7),
      Paint()..color = const Color(0x26000000));
    canvas.drawCircle(Offset.zero, radius, Paint()..color = flash > 0 ? const Color(0xFFFFF3D8) : color);
    canvas.drawLine(Offset(radius * .2, 0), Offset(radius + 14, 0),
      Paint()..color = const Color(0xFFE7D8B8)..strokeWidth = player ? 5 : 2.5..strokeCap = StrokeCap.round);
    if (!player) {
      canvas.drawCircle(Offset(radius * .3, -radius * .15), radius * .18,
        Paint()..color = const Color(0xFFFFE8BD));
    }
    canvas.restore();
    if (hp < maxHp) {
      final rect = Rect.fromLTWH(-radius, -radius - 8, radius * 2, 4);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = const Color(0xFFDED8CC));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rect.left, rect.top, rect.width * hp / maxHp, 4),
        const Radius.circular(3)), Paint()..color = const Color(0xFF15803D));
    }
  }
}
