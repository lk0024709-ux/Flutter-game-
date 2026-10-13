import 'dart:ui';

import 'package:flame/extensions.dart';

import 'battle_game.dart';
import 'fighter.dart';

/// Venomtail poison stacks.
///
/// Stacks cap at 5, each stack ticks 2 damage per second for 4 seconds and every
/// new bite refreshes the whole timer. Armour with `poison immunity` (the
/// Basilisk Scale) clears the stacks instantly.
class PoisonEffect {
  const PoisonEffect._();

  static const int maxStacks = 5;
  static const double damagePerStackPerSecond = 2.0;
  static const double duration = 4.0;

  /// Applies one stack (or [stacks]) and refreshes the timer.
  static void apply(Fighter fighter, {int stacks = 1, BattleGame? game}) {
    if (!fighter.alive) {
      return;
    }
    if (fighter.poisonImmune) {
      return;
    }
    final int before = fighter.poisonStacks;
    fighter.poisonStacks = (fighter.poisonStacks + stacks).clamp(0, maxStacks);
    fighter.poisonTimer = duration;
    if (game != null && fighter.poisonStacks > before && fighter.poisonStacks == maxStacks) {
      game.addFloatingText('MAX POISON', fighter.position, const Color(0xFF4D7C0F), size: 13);
    }
  }

  /// Ticks the poison for one frame. Called from [Fighter.updateTimers].
  static void tick(Fighter fighter, double dt, BattleGame? game) {
    if (fighter.poisonStacks <= 0) {
      return;
    }
    fighter.poisonTimer -= dt;
    if (fighter.poisonTimer <= 0) {
      fighter.poisonStacks = 0;
      fighter.poisonTimer = 0;
      return;
    }
    final double damage = damagePerStackPerSecond * fighter.poisonStacks * dt;
    fighter.takeDamage(damage, environmental: true, label: 'Poison', ignoreDefense: true);
    if (game != null && fighter.poisonStacks > 0 && fighter.combatTimer > 0.9) {
      // Occasional droplet visual so the player can read the poison ticking.
      game.poisonBubbles.add(PoisonBubble(position: fighter.position.clone()));
    }
  }

  /// Clears every stack (Basilisk Scale, antidotes).
  static void cleanse(Fighter fighter) {
    fighter.poisonStacks = 0;
    fighter.poisonTimer = 0;
  }
}

/// A short-lived green bubble drifting off a poisoned fighter.
class PoisonBubble {
  PoisonBubble({required this.position});

  final Vector2 position;
  double age = 0;
  static const double life = 0.9;

  bool get dead => age >= life;

  void update(double dt) => age += dt;

  void render(Canvas canvas) {
    final double t = (age / life).clamp(0.0, 1.0);
    final Paint paint = Paint()
      ..color = const Color(0xFF4D7C0F).withAlpha(((1 - t) * 160).round())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(position.x, position.y - 12 - t * 22),
      2 + t * 3,
      paint,
    );
  }
}
