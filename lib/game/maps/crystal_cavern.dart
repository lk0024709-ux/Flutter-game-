import '../battle_game.dart';
import '../game_map.dart';
import '../map_twist.dart';
import '../rank.dart';
import '../twists/mirror_clone_twist.dart';

/// Rank 5 - Crystal Cavern. Deep purple cave filled with crystal formations.
/// Twist: MIRROR CLONES spawn every 20s; three destructible crystals disable
/// the cloning for 15s.
class CrystalCavernMap extends GameMapDef {
  const CrystalCavernMap()
      : super(
          id: 'crystal_cavern',
          name: 'Crystal Cavern',
          emoji: '💎',
          rank: Rank.diamond,
          worldSize: 2400,
          decorStyle: MapDecorStyle.crystal,
          floorColor: 0xFF3B3450,
          floorAccent: 0xFF4A4162,
          decorColor: 0xFF6D5F9A,
          shrinkMultiplier: 0.9,
          twistName: 'Mirror Clones',
          twistIcon: '🪞',
          twistDescription:
              'Mirror clones spawn every 20s (50% damage taken, 100% dealt); shatter the crystals to stop them.',
          tagline: 'Every reflection here has teeth.',
        );

  @override
  MapTwist buildTwist(BattleGame game) => MirrorCloneTwist(game);
}
