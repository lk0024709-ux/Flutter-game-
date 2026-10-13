import 'dart:ui';

import 'battle_game.dart';
import 'fighter.dart';

/// Base class for every ranked-map twist.
///
/// A twist owns the dynamic hazards of its arena (geysers, lightning, moving
/// walls, mirror clones, ...) and may modify movement speed and visibility.
/// The [BattleGame] creates exactly one twist per battle and drives it from the
/// main update loop.
abstract class MapTwist {
  MapTwist(this.game);

  /// The battle this twist belongs to.
  final BattleGame game;

  /// Display name, e.g. "Sandfog".
  String get name;

  /// Emoji used by the HUD pill.
  String get icon;

  /// One sentence explaining the twist (shown in level details).
  String get description;

  /// Short HUD text, e.g. "SANDFOG 4s" or "GEYSER 2s". Empty hides the pill.
  String get hudLabel => '';

  /// Movement multiplier applied to every fighter.
  double get speedMultiplier => 1.0;

  /// Visibility multiplier (1.0 = clear, 0.7 = foggy/dark).
  double get visionMultiplier => 1.0;

  /// Extra overlay tint drawn in front of the arena (alpha, colour).
  Color get overlayColor => const Color(0x00000000);

  /// Called every frame while the battle runs.
  void update(double dt) {}

  /// World-space rendering before fighters.
  void renderBehind(Canvas canvas) {}

  /// World-space rendering after fighters.
  void renderFront(Canvas canvas) {}

  /// Hook so twists can tag newly spawned fighters (e.g. mirror clones).
  void onFighterSpawned(Fighter fighter) {}

  /// Called when the battle ends.
  void dispose() {}
}

/// Convenience: an arena with no twist at all (used by elite trials).
class NoTwist extends MapTwist {
  NoTwist(super.game);

  @override
  String get name => 'None';

  @override
  String get icon => '⚪';

  @override
  String get description => 'A clean arena - nothing but steel and instinct.';
}
