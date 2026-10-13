/// The seven campaign ranks. Every rank owns 50 levels and one handcrafted map.
enum Rank {
  bronze('Bronze', '🥉', 0, 0xFFA16207, 0, 1.0, 'The Dust Pit', 1.0),
  silver('Silver', '🥈', 1, 0xFF94A3B8, 3, 1.5, 'Frost Hollow', 1.2),
  gold('Gold', '🥇', 2, 0xFFD97706, 8, 2.0, 'Ember Forge', 1.5),
  platinum('Platinum', '💠', 3, 0xFF0891B2, 15, 3.0, 'Jade Temple', 2.0),
  diamond('Diamond', '💎', 4, 0xFF6366F1, 25, 4.0, 'Crystal Cavern', 2.5),
  masters('Masters', '🏆', 5, 0xFF7C2D12, 40, 6.0, 'Storm Citadel', 3.0),
  grandMasters('Grand Masters', '👑', 6, 0xFF1C1917, 60, 8.0, 'Throne of Rann', 5.0);

  const Rank(
    this.label,
    this.icon,
    this.index,
    this.colorValue,
    this.unlockWins,
    this.coinMultiplier,
    this.mapName,
    this.mapCoinMultiplier,
  );

  /// Display name.
  final String label;

  /// Rank medal emoji.
  final String icon;

  /// 0-based rank index (also the map index).
  final int index;

  /// Muted rank colour (never neon).
  final int colorValue;

  /// Campaign wins required before the rank opens up.
  final int unlockWins;

  /// Campaign reward multiplier applied to the level coin formula.
  final double coinMultiplier;

  /// Handcrafted map that hosts this rank.
  final String mapName;

  /// Map coin multiplier from the ranked map table.
  final double mapCoinMultiplier;

  /// Levels per rank.
  static const int levelsPerRank = 50;

  /// Total campaign levels (7 ranks x 50).
  static const int totalLevels = 350;

  /// First level number of this rank (1-based).
  int get firstLevel => index * levelsPerRank + 1;

  /// Last level number of this rank (1-based).
  int get lastLevel => firstLevel + levelsPerRank - 1;

  /// The next rank up, or null for Grand Masters.
  Rank? get next => index < Rank.values.length - 1 ? Rank.values[index + 1] : null;

  /// Difficulty scaling applied to creature stats for the whole rank.
  /// Bronze = 1.0 ... Grand Masters = 5.0.
  double get difficultyMultiplier =>
      1.0 + index * (4.0 / (Rank.values.length - 1));

  /// Coin multiplier used by the campaign reward formula.
  double get gradeCoinMultiplier => coinMultiplier;

  /// Resolves the rank that hosts a 1-based campaign level.
  static Rank ofLevel(int level) {
    final int clamped = level.clamp(1, totalLevels);
    return Rank.values[((clamped - 1) ~/ levelsPerRank).clamp(0, Rank.values.length - 1)];
  }

  static Rank byName(String? name) {
    for (final Rank rank in Rank.values) {
      if (rank.name == name) {
        return rank;
      }
    }
    return Rank.bronze;
  }
}
