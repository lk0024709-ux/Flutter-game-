import 'battle_game.dart';
import 'map_twist.dart';
import 'maps/crystal_cavern.dart';
import 'maps/dust_pit.dart';
import 'maps/ember_forge.dart';
import 'maps/frost_hollow.dart';
import 'maps/jade_temple.dart';
import 'maps/storm_citadel.dart';
import 'maps/throne_of_rann.dart';
import 'rank.dart';

/// Visual recipe used by [Arena] to build procedural scenery.
enum MapDecorStyle {
  /// Bleached bones and dead shrubs on cracked sand.
  dust,

  /// Frozen ponds, pine clusters and drifting snow.
  snow,

  /// Volcanic rock, lava pools and floating embers.
  volcanic,

  /// Jade flagstones with broken columns and gold veins.
  jade,

  /// Deep cavern with crystal formations.
  crystal,

  /// Floating stone platforms over storm clouds.
  storm,

  /// Black marble and gold constellations in a cosmic void.
  cosmic,
}

/// Static definition of one ranked map.
class GameMapDef {
  const GameMapDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rank,
    required this.worldSize,
    required this.decorStyle,
    required this.floorColor,
    required this.floorAccent,
    required this.decorColor,
    required this.shrinkMultiplier,
    required this.twistName,
    required this.twistIcon,
    required this.twistDescription,
    required this.tagline,
  });

  /// Stable identifier (used by the save file and level generator).
  final String id;
  final String name;
  final String emoji;
  final Rank rank;

  /// Square world size in world units.
  final double worldSize;

  final MapDecorStyle decorStyle;

  /// Base floor colour.
  final int floorColor;

  /// Secondary floor colour used for patches / tiles.
  final int floorAccent;

  /// Scenery tint.
  final int decorColor;

  /// Multiplier applied to the storm-ring shrink speed (map tuning).
  final double shrinkMultiplier;

  final String twistName;
  final String twistIcon;
  final String twistDescription;

  /// Short editorial line shown on the level-detail modal.
  final String tagline;

  /// Builds the twist instance for a battle on this map.
  MapTwist buildTwist(BattleGame game);

  /// Elite arenas reuse the same world size constant.
  static const double eliteWorldSize = 1600;
}

/// Registry of the seven handcrafted ranked maps.
class Maps {
  const Maps._();

  static const DustPitMap dustPit = DustPitMap();
  static const FrostHollowMap frostHollow = FrostHollowMap();
  static const EmberForgeMap emberForge = EmberForgeMap();
  static const JadeTempleMap jadeTemple = JadeTempleMap();
  static const CrystalCavernMap crystalCavern = CrystalCavernMap();
  static const StormCitadelMap stormCitadel = StormCitadelMap();
  static const ThroneOfRannMap throneOfRann = ThroneOfRannMap();

  static const List<GameMapDef> all = <GameMapDef>[
    dustPit,
    frostHollow,
    emberForge,
    jadeTemple,
    crystalCavern,
    stormCitadel,
    throneOfRann,
  ];

  /// The map that hosts a given rank.
  static GameMapDef forRank(Rank rank) => all[rank.index.clamp(0, all.length - 1)];

  static GameMapDef byId(String id) {
    for (final GameMapDef map in all) {
      if (map.id == id) {
        return map;
      }
    }
    return dustPit;
  }
}
