import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'fighter.dart';
import 'npc.dart';
import 'player.dart';

/// The five power-up kinds that drop in the arena.
enum PowerUpKind {
  heal('Heal', '❤️', 'Restore 30 HP instantly.', Color(0xFF15803D)),
  fury('Fury', '⚔️', '+25% sword damage for 12s.', Color(0xFFB91C1C)),
  swift('Swift', '💨', '+20% movement speed for 12s.', Color(0xFF0891B2)),
  ward('Ward', '🛡️', '+30% defense for 12s.', Color(0xFF3F6212)),
  magnet('Magnet', '🧲', 'Double chest spawns for 20s.', Color(0xFFB45309));

  const PowerUpKind(this.label, this.icon, this.description, this.color);

  final String label;
  final String icon;
  final String description;
  final Color color;
}

/// A timed power-up currently running on the player.
class ActivePowerUp {
  ActivePowerUp({required this.kind, required this.duration, required this.description});

  final PowerUpKind kind;
  final String description;
  double remaining;
  final double duration;

  double get progress => (remaining / duration).clamp(0.0, 1.0);
}

/// A pickup lying in the arena.
class PowerUp {
  PowerUp({required this.position, required this.kind, this.life = 25});

  final Vector2 position;
  final PowerUpKind kind;
  final double life;

  double age = 0;
  bool collected = false;

  bool get dead => collected || age >= life;

  void update(double dt, BattleGame game) {
    age += dt;
    for (final Fighter fighter in game.fighters) {
      if (!fighter.alive) {
        continue;
      }
      if (position.distanceTo(fighter.position) > fighter.radius + 22) {
        continue;
      }
      if (fighter is Npc) {
        // Beasts only care about healing.
        if (kind == PowerUpKind.heal) {
          fighter.heal(30);
          collected = true;
          game.addFloatingText('+30', fighter.position, const Color(0xFF15803D), size: 13);
          return;
        }
        continue;
      }
      collected = true;
      game.collectPowerUp(kind, fighter as Player);
      return;
    }
  }

  void render(Canvas canvas) {
    final Offset centre = position.toOffset();
    final double bob = math.sin(age * 3) * 4;
    final double fade = age > life - 4 ? (life - age) / 4 : 1;
    final Paint paint = Paint()
      ..color = kind.color.withAlpha((fade * 90).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(centre.translate(0, bob), 24, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kind.color.withAlpha((fade * 220).round());
    canvas.drawCircle(centre.translate(0, bob), 18, paint);

    // Glyph: a simple procedural icon per kind.
    paint
      ..style = PaintingStyle.fill
      ..color = kind.color.withAlpha((fade * 255).round());
    final Offset iconCentre = centre.translate(0, bob);
    switch (kind) {
      case PowerUpKind.heal:
        canvas.drawRect(
          Rect.fromCenter(center: iconCentre, width: 14, height: 4),
          paint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: iconCentre, width: 4, height: 14),
          paint,
        );
        break;
      case PowerUpKind.fury:
        final Path sword = Path()
          ..moveTo(iconCentre.dx - 7, iconCentre.dy + 7)
          ..lineTo(iconCentre.dx + 6, iconCentre.dy - 6)
          ..lineTo(iconCentre.dx + 8, iconCentre.dy - 3)
          ..lineTo(iconCentre.dx - 4, iconCentre.dy + 8)
          ..close();
        canvas.drawPath(sword, paint);
        break;
      case PowerUpKind.swift:
        for (int i = -1; i <= 1; i++) {
          canvas.drawRect(
            Rect.fromLTWH(
              iconCentre.dx - 9,
              iconCentre.dy + i * 5 - 1.5,
              14 - i.abs() * 4,
              3,
            ),
            paint,
          );
        }
        break;
      case PowerUpKind.ward:
        final Path shield = Path()
          ..moveTo(iconCentre.dx, iconCentre.dy - 9)
          ..lineTo(iconCentre.dx + 8, iconCentre.dy - 3)
          ..lineTo(iconCentre.dx, iconCentre.dy + 9)
          ..lineTo(iconCentre.dx - 8, iconCentre.dy - 3)
          ..close();
        canvas.drawPath(shield, paint);
        break;
      case PowerUpKind.magnet:
        canvas.drawArc(
          Rect.fromCircle(center: iconCentre.translate(0, 2), radius: 8),
          math.pi,
          math.pi,
          false,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
        paint.style = PaintingStyle.fill;
        break;
    }
  }
}

/// A coin chest dropped by beasts or spawned by the arena.
class CoinChest {
  CoinChest({required this.position, required this.coins, this.life = 22});

  final Vector2 position;
  final int coins;
  final double life;

  double age = 0;
  bool collected = false;

  bool get dead => collected || age >= life;

  void update(double dt, BattleGame game) {
    age += dt;
    final Fighter player = game.player;
    if (!player.alive) {
      return;
    }
    if (position.distanceTo(player.position) <= player.radius + 26) {
      collected = true;
      game.collectChest(this);
    }
  }

  void render(Canvas canvas) {
    final Offset centre = position.toOffset();
    final Paint paint = Paint();
    // Bigger, richer chests glow warmer.
    final Color body = coins >= 120
        ? const Color(0xFFC9A227)
        : (coins >= 60 ? const Color(0xFFB45309) : const Color(0xFF8A7856));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: 34, height: 22),
        const Radius.circular(5),
      ),
      paint..color = body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre.translate(0, -12), width: 34, height: 12),
        const Radius.circular(5),
      ),
      paint..color = Color.lerp(body, const Color(0xFFF5F1EA), 0.25)!,
    );
    paint
      ..color = const Color(0xFFC9A227)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: 34, height: 30),
        const Radius.circular(5),
      ),
      paint,
    );
    paint.style = PaintingStyle.fill;
  }
}
