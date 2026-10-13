import 'dart:math' as math;

import '../store_state.dart';
import 'chest_rarity.dart';
import 'chimera_armor.dart';
import 'elite_power.dart';
import 'loot_item.dart';
import 'loot_rarity.dart';

/// Rolls the contents of an elite chest.
///
/// The first card is always the coin purse, the second always experience, and
/// the remaining slots are filled with the bonus table for that chest tier
/// (guaranteed epic powers, themed armour, weapon fragments, boosters, titles).
class LootTable {
  const LootTable._();

  static const List<String> cosmeticNames = <String>[
    'Ash War Paint',
    'Rann Sigil Banner',
    'Bonewood Hilt',
    'Ember Cape',
    'Frost Mantle',
    'Jade Pauldrons',
  ];

  static List<LootItem> roll({
    required ChestRarity rarity,
    required math.Random rng,
    required Set<ElitePowerKind> ownedPowers,
    required ChimeraArmorKind? themedArmor,
    required bool armorAlreadyOwned,
    required bool assistMode,
  }) {
    final List<LootItem> items = <LootItem>[];

    // Coins.
    final int coins = rarity.minCoins + rng.nextInt(rarity.maxCoins - rarity.minCoins + 1);
    items.add(
      LootItem(
        kind: LootItemKind.coins,
        rarity: LootRarity.rare,
        label: 'Coin purse',
        icon: '🪙',
        amount: coins,
        description: 'Spend it in the Store or on forge speed-ups.',
      ),
    );

    // Experience.
    final int xp = rarity.minXp + rng.nextInt(rarity.maxXp - rarity.minXp + 1);
    items.add(
      LootItem(
        kind: LootItemKind.xp,
        rarity: LootRarity.rare,
        label: 'Battle experience',
        icon: '✨',
        amount: xp,
        description: 'Every level grants +50 coins.',
      ),
    );

    // Elite powers (guaranteed slots first).
    int guaranteed = assistMode ? math.max<int>(0, rarity.guaranteedEpics - 1) : rarity.guaranteedEpics;
    final List<ElitePowerKind> locked = ElitePowerKind.unlockOrder
        .where((ElitePowerKind power) => !ownedPowers.contains(power))
        .toList();
    for (int i = 0; i < guaranteed && locked.isNotEmpty; i++) {
      final ElitePowerKind power = locked.removeAt(0);
      items.add(
        LootItem(
          kind: LootItemKind.power,
          rarity: LootRarity.epic,
          label: power.label,
          icon: power.icon,
          amount: 0,
          description: power.description,
          power: power,
        ),
      );
    }

    // Themed chimera armour.
    if (themedArmor != null && !armorAlreadyOwned) {
      items.add(
        LootItem(
          kind: LootItemKind.epicArmor,
          rarity: LootRarity.legendary,
          label: themedArmor.label,
          icon: themedArmor.icon,
          amount: 0,
          description: themedArmor.description,
          eliteArmor: themedArmor,
        ),
      );
    }

    // Fill the remaining card slots with flavour rewards.
    while (items.length < rarity.itemCount) {
      final double roll = rng.nextDouble();
      if (roll < rarity.titleChance) {
        final String title = _titleFor(rarity, rng);
        items.add(
          LootItem(
            kind: LootItemKind.title,
            rarity: LootRarity.mythic,
            label: title,
            icon: '🏷️',
            amount: 0,
            description: 'Equip it from the Profile screen.',
            title: title,
          ),
        );
        continue;
      }
      if (roll < rarity.titleChance + rarity.weaponChance) {
        final int fragments = 1 + rng.nextInt(3);
        items.add(
          LootItem(
            kind: LootItemKind.weaponFrag,
            rarity: LootRarity.legendary,
            label: 'Weapon fragments',
            icon: '🗡️',
            amount: fragments,
            description: 'Forge your best blade again, instantly.',
          ),
        );
        continue;
      }
      if (roll < rarity.titleChance + rarity.weaponChance + rarity.powerChance && locked.isNotEmpty) {
        final ElitePowerKind power = locked.removeAt(0);
        items.add(
          LootItem(
            kind: LootItemKind.power,
            rarity: LootRarity.epic,
            label: power.label,
            icon: power.icon,
            amount: 0,
            description: power.description,
            power: power,
          ),
        );
        continue;
      }
      if (roll < 0.5) {
        final List<BoosterKind> boosters = BoosterKind.values;
        final BoosterKind booster = boosters[rng.nextInt(boosters.length)];
        items.add(
          LootItem(
            kind: LootItemKind.booster,
            rarity: LootRarity.rare,
            label: booster.label,
            icon: booster.icon,
            amount: 1,
            description: booster.description,
            boosterName: booster.name,
          ),
        );
        continue;
      }
      if (roll < 0.72) {
        final int bonusCoins = 150 + rng.nextInt(450);
        items.add(
          LootItem(
            kind: LootItemKind.coins,
            rarity: LootRarity.common,
            label: 'Coin cache',
            icon: '🪙',
            amount: bonusCoins,
            description: 'The arena pays its debts.',
          ),
        );
        continue;
      }
      if (roll < 0.86) {
        items.add(
          LootItem(
            kind: LootItemKind.xp,
            rarity: LootRarity.common,
            label: 'Battle insight',
            icon: '✨',
            amount: 60 + rng.nextInt(140),
            description: 'Absorbed from the chimera essence.',
          ),
        );
        continue;
      }
      final String cosmetic = cosmeticNames[rng.nextInt(cosmeticNames.length)];
      items.add(
        LootItem(
          kind: LootItemKind.cosmetic,
          rarity: LootRarity.rare,
          label: cosmetic,
          icon: '🎨',
          amount: 0,
          description: 'A cosmetic for your warrior record.',
        ),
      );
    }

    return items;
  }

  static String _titleFor(ChestRarity rarity, math.Random rng) {
    switch (rarity) {
      case ChestRarity.bronze:
      case ChestRarity.silver:
        return <String>['Trial Runner', 'Beast Botherer'][rng.nextInt(2)];
      case ChestRarity.gold:
      case ChestRarity.platinum:
        return <String>['Chimera Hunter', 'Arena Veteran'][rng.nextInt(2)];
      case ChestRarity.diamond:
        return <String>['Trialbreaker', 'Ironhide'][rng.nextInt(2)];
      case ChestRarity.mythic:
        return <String>['Rannslayer', 'Chimerasbane'][rng.nextInt(2)];
    }
  }
}
