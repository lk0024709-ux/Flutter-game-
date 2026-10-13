import '../battle_game.dart';
import '../game_map.dart';
import '../map_twist.dart';
import '../rank.dart';
import 'elite_arena_twist.dart';

/// Elite arenas are 1600x1600 dark platforms, one per chimera.
///
/// They reuse the [GameMapDef] record so the rest of the game (HUD, renderer,
/// spawn logic) treats them like any other map, but their floor palettes come
/// from the elite dark scheme and each one ships a signature hazard through its
/// twist.
class EliteMountainArena extends GameMapDef {
  const EliteMountainArena()
      : super(
          id: 'elite_mountain',
          name: 'Stormcrest Plateau',
          emoji: '🦁',
          rank: Rank.bronze,
          worldSize: GameMapDef.eliteWorldSize,
          decorStyle: MapDecorStyle.storm,
          floorColor: 0xFF3B3833,
          floorAccent: 0xFF48443C,
          decorColor: 0xFF6B6558,
          shrinkMultiplier: 1.0,
          twistName: 'Wind Shear',
          twistIcon: '🌪️',
          twistDescription:
              'A constant gale shoves fighters across the plateau while rock shards rain from the cliffs.',
          tagline: 'Where the Gryphon Prime tears the sky open.',
        );

  @override
  MapTwist buildTwist(BattleGame game) =>
      EliteArenaTwist(game, profile: EliteArenaProfile.gust);
}

class EliteSwampArena extends GameMapDef {
  const EliteSwampArena()
      : super(
          id: 'elite_swamp',
          name: 'Rotwater Hollow',
          emoji: '🐍',
          rank: Rank.silver,
          worldSize: GameMapDef.eliteWorldSize,
          decorStyle: MapDecorStyle.jade,
          floorColor: 0xFF2A3226,
          floorAccent: 0xFF35402E,
          decorColor: 0xFF5C6B4E,
          shrinkMultiplier: 1.0,
          twistName: 'Venom Pools',
          twistIcon: '🧪',
          twistDescription:
              'Six venom pools bubble toxic gas; every ten seconds the marsh erupts.',
          tagline: 'The Basilisk swims where the water turns to acid.',
        );

  @override
  MapTwist buildTwist(BattleGame game) =>
      EliteArenaTwist(game, profile: EliteArenaProfile.venom);
}

class EliteFortressArena extends GameMapDef {
  const EliteFortressArena()
      : super(
          id: 'elite_fortress',
          name: 'Scorched Bastion',
          emoji: '🐗',
          rank: Rank.gold,
          worldSize: GameMapDef.eliteWorldSize,
          decorStyle: MapDecorStyle.volcanic,
          floorColor: 0xFF38302A,
          floorAccent: 0xFF463A31,
          decorColor: 0xFF6E5343,
          shrinkMultiplier: 1.0,
          twistName: 'Steam Gates',
          twistIcon: '♨️',
          twistDescription:
              'Grinding gate walls sweep the courtyard while steam vents hammer anyone in the open.',
          tagline: 'The Ravager keeps its armour where the fires never die.',
        );

  @override
  MapTwist buildTwist(BattleGame game) =>
      EliteArenaTwist(game, profile: EliteArenaProfile.steam);
}

class EliteCliffArena extends GameMapDef {
  const EliteCliffArena()
      : super(
          id: 'elite_cliff',
          name: 'Skyfall Ledge',
          emoji: '🪶',
          rank: Rank.platinum,
          worldSize: GameMapDef.eliteWorldSize,
          decorStyle: MapDecorStyle.storm,
          floorColor: 0xFF323742,
          floorAccent: 0xFF3D4351,
          decorColor: 0xFF5C6474,
          shrinkMultiplier: 1.0,
          twistName: 'Meteor Rain',
          twistIcon: '☄️',
          twistDescription:
              'Burning rock falls from the cloud layer every few seconds - the updraft in the centre buys cover, not safety.',
          tagline: 'A ledge in the clouds; step back and the sky takes you.',
        );

  @override
  MapTwist buildTwist(BattleGame game) =>
      EliteArenaTwist(game, profile: EliteArenaProfile.meteor);
}

class EliteDunesArena extends GameMapDef {
  const EliteDunesArena()
      : super(
          id: 'elite_dunes',
          name: 'Drowning Sands',
          emoji: '🌀',
          rank: Rank.diamond,
          worldSize: GameMapDef.eliteWorldSize,
          decorStyle: MapDecorStyle.dust,
          floorColor: 0xFF47402F,
          floorAccent: 0xFF544A38,
          decorColor: 0xFF8A7856,
          shrinkMultiplier: 1.0,
          twistName: 'Quicksand',
          twistIcon: '🏜️',
          twistDescription:
              'Quicksand pools drag at your boots and a wandering vortex hunts the arena.',
          tagline: 'Deathroll remembers every warrior the dunes swallowed.',
        );

  @override
  MapTwist buildTwist(BattleGame game) =>
      EliteArenaTwist(game, profile: EliteArenaProfile.quicksand);
}

class EliteThroneArena extends GameMapDef {
  const EliteThroneArena()
      : super(
          id: 'elite_throne',
          name: "Rann's Arena",
          emoji: '🦁',
          rank: Rank.masters,
          worldSize: GameMapDef.eliteWorldSize,
          decorStyle: MapDecorStyle.cosmic,
          floorColor: 0xFF221F1B,
          floorAccent: 0xFF2C2823,
          decorColor: 0xFFB45309,
          shrinkMultiplier: 1.0,
          twistName: 'Golden Court',
          twistIcon: '👑',
          twistDescription:
              'Golden pillars slide across the court, lightning answers the throne and the treasury drops pickups for the bold.',
          tagline: 'The king of beasts fights where kings were crowned.',
        );

  @override
  MapTwist buildTwist(BattleGame game) =>
      EliteArenaTwist(game, profile: EliteArenaProfile.royal);
}

class EliteVoidArena extends GameMapDef {
  const EliteVoidArena()
      : super(
          id: 'elite_void',
          name: 'Collapsing Void',
          emoji: '🐲',
          rank: Rank.grandMasters,
          worldSize: GameMapDef.eliteWorldSize,
          decorStyle: MapDecorStyle.crystal,
          floorColor: 0xFF26232E,
          floorAccent: 0xFF312D3B,
          decorColor: 0xFF514A63,
          shrinkMultiplier: 1.0,
          twistName: 'Gravity Wells',
          twistIcon: '🌀',
          twistDescription:
              'The void folds reality into wells that drag you in while celestial lightning falls.',
          tagline: 'The Omega Chimera is not a beast. It is an ending.',
        );

  @override
  MapTwist buildTwist(BattleGame game) =>
      EliteArenaTwist(game, profile: EliteArenaProfile.gravity);
}

/// Registry of the seven elite arenas.
class EliteArenas {
  const EliteArenas._();

  static const EliteMountainArena mountain = EliteMountainArena();
  static const EliteSwampArena swamp = EliteSwampArena();
  static const EliteFortressArena fortress = EliteFortressArena();
  static const EliteCliffArena cliff = EliteCliffArena();
  static const EliteDunesArena dunes = EliteDunesArena();
  static const EliteThroneArena throne = EliteThroneArena();
  static const EliteVoidArena void_ = EliteVoidArena();

  /// Fallback arena when an id is unknown or empty.
  static const EliteMountainArena fallback = mountain;

  static const List<GameMapDef> all = <GameMapDef>[
    mountain,
    swamp,
    fortress,
    cliff,
    dunes,
    throne,
    void_,
  ];

  /// Resolves an arena by its stable id (used by `EliteTrial.type.arenaId`).
  static GameMapDef forId(String? id) {
    if (id == null || id.isEmpty) {
      return fallback;
    }
    for (final GameMapDef map in all) {
      if (map.id == id) {
        return map;
      }
    }
    return fallback;
  }
}
