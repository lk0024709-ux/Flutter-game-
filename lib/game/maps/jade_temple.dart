import '../battle_game.dart';
import '../game_map.dart';
import '../map_twist.dart';
import '../rank.dart';
import '../twists/moving_walls_twist.dart';

/// Rank 4 - Jade Temple. Jade stone, broken columns and gold veins.
/// Twist: 4 MOVING WALLS on rails and 2 TREASURE SHRINES (stand 2s for a
/// free power-up).
class JadeTempleMap extends GameMapDef {
  const JadeTempleMap()
      : super(
          id: 'jade_temple',
          name: 'Jade Temple',
          emoji: '💠',
          rank: Rank.platinum,
          worldSize: 2400,
          decorStyle: MapDecorStyle.jade,
          floorColor: 0xFFBFD3BF,
          floorAccent: 0xFFA8C2A8,
          decorColor: 0xFF4F6B4F,
          shrinkMultiplier: 0.9,
          twistName: 'Moving Walls',
          twistIcon: '🧱',
          twistDescription:
              'Four stone walls slide across the temple while treasure shrines grant free power-ups.',
          tagline: 'The old gods watch from behind the columns.',
        );

  @override
  MapTwist buildTwist(BattleGame game) => MovingWallsTwist(game);
}
