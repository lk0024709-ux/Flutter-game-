enum Rank { bronze, silver, gold, platinum, diamond, masters, grandMasters }

extension RankData on Rank {
  String get label => const ['Bronze','Silver','Gold','Platinum','Diamond','Masters','Grand Masters'][index];
  String get icon => const ['🥉','🥈','🥇','💠','💎','🏆','👑'][index];
  String get mapName => const ['The Dust Pit','Frost Hollow','Ember Forge','Jade Temple','Crystal Cavern','Storm Citadel','Throne of Rann'][index];
  double get coinMultiplier => const [1,1.2,1.5,2,2.5,3,5][index];
  int get unlockWins => const [0,3,8,15,25,40,60][index];
  int get campaignRewardMultiplier => const [1,2,3,4,6,8,10][index];
}

class GameLevel {
  const GameLevel({required this.number,required this.rank,required this.levelInRank,required this.difficulty,required this.npcCount,required this.mapName,required this.boss,required this.modifiers,required this.baseCoins});
  final int number;
  final Rank rank;
  final int levelInRank;
  final double difficulty;
  final int npcCount;
  final String mapName;
  final bool boss;
  final List<String> modifiers;
  final int baseCoins;
  String get title => boss ? rank.label + ' Rank Boss' : rank.label + ' · Level ' + levelInRank.toString();
  bool get miniBoss => levelInRank % 10 == 0 && !boss;
}
