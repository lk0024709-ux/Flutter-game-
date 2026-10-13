import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ArmorRank {
  normal('Cloth Tunic', '🥉', 0, 0, 0.05, 'Basic protection'),
  advanced('Field Guard', '🥈', 350, 25, 0.12, '+5 HP regen/sec'),
  legend('Legend Plate', '🥇', 900, 50, 0.22, 'Reflects incoming damage'),
  epic('Epic Aegis', '💎', 2200, 100, 0.35, 'Revives once per battle');
  const ArmorRank(this.label, this.icon, this.price, this.hpBonus, this.defense, this.description);
  final String label, icon, description;
  final int price, hpBonus;
  final double defense;
}

class StoreState extends ChangeNotifier {
  StoreState._();
  static final StoreState instance = StoreState._();
  int coins = 500;
  ArmorRank equippedArmor = ArmorRank.normal;
  final Set<ArmorRank> ownedArmors = {ArmorRank.normal};
  final Map<String, int> boosters = {'Revive Potion': 200, 'Damage Elixir': 150, 'Chest Magnet': 100, 'Iron Skin': 180};
  final Set<String> ownedBoosters = {};
  int playerXP = 0;
  int playerLevel = 1;
  int campaignWins = 0;
  int highestLevelUnlocked = 1;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    coins = p.getInt('store.coins') ?? 500;
    playerXP = p.getInt('store.xp') ?? 0;
    playerLevel = p.getInt('store.level') ?? 1;
    campaignWins = p.getInt('store.wins') ?? 0;
    highestLevelUnlocked = p.getInt('store.unlocked') ?? 1;
    final owned = p.getStringList('store.armors') ?? ['normal'];
    ownedArmors.addAll(owned.map((s) => ArmorRank.values.firstWhere((a) => a.name == s, orElse: () => ArmorRank.normal)));
    final equipped = p.getString('store.equipped') ?? 'normal';
    equippedArmor = ArmorRank.values.firstWhere((a) => a.name == equipped, orElse: () => ArmorRank.normal);
    for (final name in p.getStringList('store.boosters') ?? <String>[]) { ownedBoosters.add(name); }
    _loaded = true;
    notifyListeners();
  }

  Future<void> persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('store.coins', coins);
    await p.setInt('store.xp', playerXP);
    await p.setInt('store.level', playerLevel);
    await p.setInt('store.wins', campaignWins);
    await p.setInt('store.unlocked', highestLevelUnlocked);
    await p.setStringList('store.armors', ownedArmors.map((e) => e.name).toList());
    await p.setString('store.equipped', equippedArmor.name);
    await p.setStringList('store.boosters', ownedBoosters.toList());
  }

  bool buyArmor(ArmorRank armor) {
    if (ownedArmors.contains(armor)) { equippedArmor = armor; notifyListeners(); unawaited(persist()); return true; }
    if (coins < armor.price) return false;
    coins -= armor.price;
    ownedArmors.add(armor);
    equippedArmor = armor;
    notifyListeners();
    unawaited(persist());
    return true;
  }

  bool buyBooster(String name) {
    final price = boosters[name];
    if (price == null || coins < price) return false;
    coins -= price;
    ownedBoosters.add(name);
    notifyListeners();
    unawaited(persist());
    return true;
  }

  void award(int amount, {bool win = false}) {
    coins += amount;
    if (win) { campaignWins++; highestLevelUnlocked = (highestLevelUnlocked + 1).clamp(1, 350).toInt(); }
    playerXP += win ? 50 : 10;
    while (playerLevel < 100 && playerXP >= (100 * playerLevel * playerLevel * playerLevel).toDouble().sqrtApprox()) {
      playerXP -= (100 * playerLevel * playerLevel).clamp(100, 1000000).toInt();
      playerLevel++;
      coins += 50;
    }
    notifyListeners();
    unawaited(persist());
  }
}

extension on double {
  double sqrtApprox() => this <= 0 ? 0 : _sqrt(this);
  double _sqrt(double value) {
    var x = value;
    for (var i = 0; i < 12; i++) { x = (x + value / x) / 2; }
    return x;
  }
}
