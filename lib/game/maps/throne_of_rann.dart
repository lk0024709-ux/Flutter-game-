import '../battle_game.dart';
import '../game_map.dart';
import '../map_twist.dart';
import '../rank.dart';
import '../twists/chaos_cycle_twist.dart';

/// Rank 7 - Throne of Rann. Cosmic void, black marble, gold constellations.
/// Twist: EVERY previous twist cycles every 30s - and Rann's Avatar watches.
class ThroneOfRannMap extends GameMapDef {
  const ThroneOfRannMap()
      : super(
          id: 'throne_of_rann',
          name: 'Throne of Rann',
          emoji: '👑',
          rank: Rank.grandMasters,
          worldSize: 2400,
          decorStyle: MapDecorStyle.cosmic,
          floorColor: 0xFF24202B,
          floorAccent: 0xFF2F2A38,
          decorColor: 0xFFC9A227,
          shrinkMultiplier: 0.8,
          twistName: 'Chaos Cycle',
          twistIcon: '🌌',
          twistDescription:
              'All previous twists rotate every 30s - fog, ice, lava, walls, clones and lightning, forever.',
          tagline: 'The last arena. Rann is watching.',
        );

  @override
  MapTwist buildTwist(BattleGame game) => ChaosCycleTwist(game);
}
