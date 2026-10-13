import '../battle_game.dart';
import '../game_map.dart';
import '../map_twist.dart';
import '../rank.dart';
import '../twists/ice_cold_twist.dart';

/// Rank 2 - Frost Hollow. Icy blue-white stone, pines and frozen ponds.
/// Twist: SLIPPERY ICE patches plus HEAT ZONES that prevent the cold.
class FrostHollowMap extends GameMapDef {
  const FrostHollowMap()
      : super(
          id: 'frost_hollow',
          name: 'Frost Hollow',
          emoji: '🥈',
          rank: Rank.silver,
          worldSize: 2400,
          decorStyle: MapDecorStyle.snow,
          floorColor: 0xFFDCE6EC,
          floorAccent: 0xFFC8D6E0,
          decorColor: 0xFF7C93A3,
          shrinkMultiplier: 1.0,
          twistName: 'Slippery Ice',
          twistIcon: '🧊',
          twistDescription:
              'Ice patches steal your footing while the cold bites for -2 HP/s outside the heat zones.',
          tagline: 'The ice keeps what the storm leaves behind.',
        );

  @override
  MapTwist buildTwist(BattleGame game) => IceColdTwist(game);
}
