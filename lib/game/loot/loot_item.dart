import 'dart:ui';

import 'chimera_armor.dart';
import 'elite_power.dart';
import 'loot_rarity.dart';

/// One chest's worth of loot, bundled with the roll that produced it.
///
/// The UI opens a chest exactly once and then animates the contents, so the
/// table returns both together: the rarity for the header and the item list
/// for the cards.
class LootTableResult {
  const LootTableResult({
    required this.rarity,
    required this.items,
    this.guaranteedEpics = 0,
  });

  final LootRarity rarity;
  final List<LootItem> items;
  final int guaranteedEpics;

  int get coinTotal => items
      .where((LootItem item) => item.kind == LootItemKind.coins)
      .fold(0, (int sum, LootItem item) => sum + item.amount);

  int get xpTotal => items
      .where((LootItem item) => item.kind == LootItemKind.xp)
      .fold(0, (int sum, LootItem item) => sum + item.amount);

  /// Items that permanently change the collection (powers, armour, titles...).
  List<LootItem> get unlockItems =>
      items.where((LootItem item) => item.isUnlock).toList();

  static const LootTableResult empty = LootTableResult(
    rarity: LootRarity.common,
    items: <LootItem>[],
  );
}

/// A single rolled reward.
class LootItem {
  const LootItem({
    required this.kind,
    required this.label,
    required this.icon,
    required this.rarity,
    required this.description,
    this.amount = 0,
    this.power,
    this.eliteArmor,
    this.title,
    this.boosterName,
  });

  final LootItemKind kind;
  final String label;
  final String icon;
  final LootRarity rarity;

  /// Stack size - coins, XP, fragments or booster charges.
  final int amount;

  final String description;

  /// Set for [LootItemKind.power] drops.
  final ElitePowerKind? power;

  /// Set for [LootItemKind.epicArmor] drops.
  final ChimeraArmorKind? eliteArmor;

  /// Set for [LootItemKind.title] drops.
  final String? title;

  /// Set for [LootItemKind.booster] drops (stored by name in the save file).
  final String? boosterName;

  /// True when the item adds something permanent to the collection.
  bool get isUnlock =>
      kind == LootItemKind.power ||
      kind == LootItemKind.epicArmor ||
      kind == LootItemKind.title ||
      kind == LootItemKind.cosmetic ||
      kind == LootItemKind.weaponFrag;

  Color get color => rarity.color;
}

/// The eight things a chest can hand out.
enum LootItemKind {
  coins('Coins', '🪙'),
  xp('Warrior XP', '✨'),
  power('Elite Power', '🌟'),
  epicArmor('Elite Armor', '🛡️'),
  title('Title', '🏷️'),
  weaponFrag('Weapon Fragment', '⚔️'),
  booster('Booster', '🧪'),
  cosmetic('Cosmetic', '🎨');

  const LootItemKind(this.label, this.icon);

  final String label;
  final String icon;
}
