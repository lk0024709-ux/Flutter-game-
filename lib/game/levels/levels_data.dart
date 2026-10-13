import 'game_level.dart';

abstract final class LevelsData {
  static const int totalLevels = 350;
  static const List<String> _types = ['Griffin','Drake','Skyhawk','Ironboar','Venomtail'];
  static const List<String> _modifiers = ['npcTough','npcFierce','npcSwift','npcLegion','slippery','darkness','noHeal','fastStorm','mirrorMatch','risingLava','noPowers','lowGravity','ironman','speedrun','bossRush','npcElite','noShield','slowForge','npcLegion','slippery'];
  static final List<GameLevel> all = List<GameLevel>.unmodifiable(List.generate(totalLevels, (index) {
    final rankIndex = index ~/ 50;
    final levelInRank = index % 50 + 1;
    final rank = Rank.values[rankIndex];
    final boss = levelInRank == 50;
    final typeCount = levelInRank <= 10 ? 1 : levelInRank <= 20 ? 2 : levelInRank <= 30 ? 3 : levelInRank <= 40 ? 4 : 5;
    final modifierCount = levelInRank < 11 ? 0 : levelInRank < 21 ? 1 : levelInRank < 41 ? 2 : 3;
    final modifiers = List<String>.generate(modifierCount, (i) => _modifiers[(index + i * 7) % _modifiers.length]);
    return GameLevel(number:index+1,rank:rank,levelInRank:levelInRank,difficulty:1+(levelInRank/50)*2,
      npcCount:8+(levelInRank~/5)+rankIndex*2,mapName:rank.mapName,boss:boss,
      modifiers:boss?List<String>.unmodifiable([...modifiers,'rankBoss']):List<String>.unmodifiable(modifiers),
      baseCoins:40+levelInRank*8+typeCount*0);
  }));

  static GameLevel byNumber(int number) {
    if (number < 1 || number > totalLevels) throw RangeError.range(number,1,totalLevels,'number');
    return all[number-1];
  }
  static List<GameLevel> forRank(Rank rank) => all.where((level)=>level.rank==rank).toList(growable:false);
}
