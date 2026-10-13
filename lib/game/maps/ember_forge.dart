import '../battle_game.dart';
import '../game_map.dart';
import '../map_twist.dart';
import '../rank.dart';
import '../twists/lava_geyser_twist.dart';

/// Rank 3 - Ember Forge. Dark volcanic rock, lava pools and drifting embers.
/// Twist: LAVA pools (5 dmg/s) and FIRE GEYSERS every 8s.
class EmberForgeMap extends GameMapDef {
  const EmberForgeMap()
      : super(
          id: 'ember_forge',
          name: 'Ember Forge',
          emoji: '🥇',
          rank: Rank.gold,
          worldSize: 2400,
          decorStyle: MapDecorStyle.volcanic,
          floorColor: 0xFF4A3B33,
          floorAccent: 0xFF5A463C,
          decorColor: 0xFF2A2320,
          shrinkMultiplier: 1.0,
          twistName: 'Lava & Geysers',
          twistIcon: '🌋',
          twistDescription:
              'Lava pools burn for 5 HP/s and fire geysers erupt every 8s for 20 damage plus knockback.',
          tagline: 'The mountain forges heroes and melts the rest.',
        );

  @override
  MapTwist buildTwist(BattleGame game) => LavaGeyserTwist(game);
}
