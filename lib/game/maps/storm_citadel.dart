import '../battle_game.dart';
import '../game_map.dart';
import '../map_twist.dart';
import '../rank.dart';
import '../twists/storm_lightning_twist.dart';

/// Rank 6 - Storm Citadel. Dark grey ramparts and floating platforms.
/// Twist: LIGHTNING strikes every 6s (35 dmg) and rotating WIND PUSH 20 u/s.
class StormCitadelMap extends GameMapDef {
  const StormCitadelMap()
      : super(
          id: 'storm_citadel',
          name: 'Storm Citadel',
          emoji: '🏆',
          rank: Rank.masters,
          worldSize: 2400,
          decorStyle: MapDecorStyle.storm,
          floorColor: 0xFF5B6169,
          floorAccent: 0xFF6B727A,
          decorColor: 0xFF3C4249,
          shrinkMultiplier: 0.85,
          twistName: 'Storm & Wind',
          twistIcon: '🌩️',
          twistDescription:
              'Lightning smashes down every 6s after a 1.5s telegraph while the wind shoves everyone sideways.',
          tagline: 'Stand tall. The sky is the enemy here.',
        );

  @override
  MapTwist buildTwist(BattleGame game) => StormLightningTwist(game);
}
