/// The sound set that ships in `assets/audio`, with attribution.
///
/// Playback is deliberately separate: this catalogue only describes what is
/// bundled (id, file, source and when it should fire), so the asset report can
/// prove every file exists and the audio service added in the next phase has a
/// single place to look names up.
class AudioAsset {
  const AudioAsset({
    required this.id,
    required this.label,
    required this.path,
    required this.usage,
    this.music = false,
  });

  /// Stable key used by gameplay code (`AudioCatalog.sfx('sword_hit')`).
  final String id;

  /// Human label for the asset report.
  final String label;

  /// Path inside the bundle.
  final String path;

  /// When the cue should play.
  final String usage;

  /// True for longer stingers and themes.
  final bool music;

  String get source => music
      ? 'Kenney music jingles (CC0 1.0) - https://kenney.nl/assets/music-jingles'
      : 'Kenney sound packs (CC0 1.0) - https://kenney.nl/assets';
}

/// Every sound the game ships, grouped by what it is for.
class AudioCatalog {
  AudioCatalog._();

  static const String _sfxRoot = 'assets/audio/sfx';

  static const String _musicRoot = 'assets/audio/music';

  static const List<AudioAsset> sfx = <AudioAsset>[
    AudioAsset(
      id: 'sword_swing',
      label: 'Sword swing',
      path: '$_sfxRoot/sword_swing.ogg',
      usage: 'Player attack startup.',
    ),
    AudioAsset(
      id: 'sword_hit',
      label: 'Blade contact',
      path: '$_sfxRoot/sword_hit.ogg',
      usage: 'Attack connects with a fighter or beast.',
    ),
    AudioAsset(
      id: 'shield_block',
      label: 'Blocked hit',
      path: '$_sfxRoot/shield_block.ogg',
      usage: 'Damage absorbed by armour or a shield.',
    ),
    AudioAsset(
      id: 'creature_hit',
      label: 'Beast hurt',
      path: '$_sfxRoot/creature_hit.ogg',
      usage: 'Creature takes damage.',
    ),
    AudioAsset(
      id: 'creature_death',
      label: 'Beast felled',
      path: '$_sfxRoot/creature_death.ogg',
      usage: 'Creature dies and drops loot.',
    ),
    AudioAsset(
      id: 'boss_roar',
      label: 'Chimera roar',
      path: '$_sfxRoot/boss_roar.ogg',
      usage: 'Rank boss and elite chimera phase change.',
    ),
    AudioAsset(
      id: 'chest_open',
      label: 'Chest opens',
      path: '$_sfxRoot/chest_open.ogg',
      usage: 'Victory chest reveal.',
    ),
    AudioAsset(
      id: 'coin_pickup',
      label: 'Coins counted',
      path: '$_sfxRoot/coin_pickup.ogg',
      usage: 'Coin reward and store purchase.',
    ),
    AudioAsset(
      id: 'powerup',
      label: 'Power picked up',
      path: '$_sfxRoot/powerup.ogg',
      usage: 'Boosters, power-ups and safe-zone shrines.',
    ),
    AudioAsset(
      id: 'level_up',
      label: 'Level up',
      path: '$_sfxRoot/level_up.ogg',
      usage: 'Player level or weapon rank increase.',
    ),
    AudioAsset(
      id: 'footstep',
      label: 'Footstep',
      path: '$_sfxRoot/footstep.ogg',
      usage: 'Walking, throttled to every other step.',
    ),
    AudioAsset(
      id: 'storm_warning',
      label: 'Storm warning',
      path: '$_sfxRoot/storm_warning.ogg',
      usage: 'Storm ring closes in or a twist activates.',
    ),
    AudioAsset(
      id: 'ui_click',
      label: 'UI tap',
      path: '$_sfxRoot/ui_click.ogg',
      usage: 'Cards, buttons and list rows.',
    ),
    AudioAsset(
      id: 'ui_confirm',
      label: 'UI confirm',
      path: '$_sfxRoot/ui_confirm.ogg',
      usage: 'Equip, merge, upgrade and purchase confirmation.',
    ),
  ];

  static const List<AudioAsset> music = <AudioAsset>[
    AudioAsset(
      id: 'home_theme',
      label: 'Home sting',
      path: '$_musicRoot/home_theme.ogg',
      usage: 'Forge and camp screens.',
      music: true,
    ),
    AudioAsset(
      id: 'battle_theme',
      label: 'Battle sting',
      path: '$_musicRoot/battle_theme.ogg',
      usage: 'Battle start and last-fighter-standing.',
      music: true,
    ),
    AudioAsset(
      id: 'elite_theme',
      label: 'Elite sting',
      path: '$_musicRoot/elite_theme.ogg',
      usage: 'Elite trial intro and dark arena.',
      music: true,
    ),
    AudioAsset(
      id: 'shop_theme',
      label: 'Store sting',
      path: '$_musicRoot/shop_theme.ogg',
      usage: 'Warrior store and loot reveal.',
      music: true,
    ),
    AudioAsset(
      id: 'victory',
      label: 'Victory',
      path: '$_musicRoot/victory.ogg',
      usage: 'Level cleared, grade and rewards.',
      music: true,
    ),
    AudioAsset(
      id: 'defeat',
      label: 'Defeat',
      path: '$_musicRoot/defeat.ogg',
      usage: 'Battle lost or storm claimed the warrior.',
      music: true,
    ),
  ];

  /// Everything, sound effects first.
  static List<AudioAsset> get all => <AudioAsset>[...sfx, ...music];

  /// Looks a cue up by id; returns null when the game has no such sound.
  static AudioAsset? byId(String id) {
    for (final AudioAsset asset in all) {
      if (asset.id == id) {
        return asset;
      }
    }
    return null;
  }
}
