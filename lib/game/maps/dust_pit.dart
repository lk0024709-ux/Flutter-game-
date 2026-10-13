import '../battle_game.dart';
import '../game_map.dart';
import '../map_twist.dart';
import '../rank.dart';
import '../twists/dust_storm_twist.dart';

/// Rank 1 - The Dust Pit. Sandy beige ground, dead shrubs and bleached bones.
/// Twist: SANDFOG rolls in every 12 seconds for 5 seconds.
class DustPitMap extends GameMapDef {
  const DustPitMap()
      : super(
          id: 'dust_pit',
          name: 'The Dust Pit',
          emoji: '🥉',
          rank: Rank.bronze,
          worldSize: 2400,
          decorStyle: MapDecorStyle.dust,
          floorColor: 0xFFD9C7A3,
          floorAccent: 0xFFCDB694,
          decorColor: 0xFF8A7856,
          shrinkMultiplier: 1.2,
          twistName: 'Sandfog',
          twistIcon: '🌫️',
          twistDescription:
              'Every 12s a sandfog rolls in for 5s: -15% move speed and heavily reduced vision.',
          tagline: 'Where every legend takes its first breath of grit.',
        );

  @override
  MapTwist buildTwist(BattleGame game) => DustStormTwist(game);
}
