import 'package:flutter_test/flutter_test.dart';
import 'package:blade_brawl/game/levels/levels_data.dart';
import 'package:blade_brawl/game/levels/game_level.dart';
import 'package:blade_brawl/game/elite/chimera.dart';

void main() {
  test('campaign data contains 350 levels across seven 50-level ranks', () {
    expect(LevelsData.all, hasLength(350));
    for (final rank in Rank.values) {
      expect(LevelsData.forRank(rank), hasLength(50));
    }
    expect(LevelsData.byNumber(50).boss, isTrue);
    expect(LevelsData.byNumber(350).rank, Rank.grandMasters);
    expect(LevelsData.byNumber(350).boss, isTrue);
  });

  test('all seven chimera definitions have unique names and valid health', () {
    expect(ChimeraDefinition.all, hasLength(7));
    expect(ChimeraDefinition.all.map((c) => c.name).toSet(), hasLength(7));
    expect(ChimeraDefinition.all.every((c) => c.hp > 0 && c.attacks.isNotEmpty), isTrue);
  });
}
