import 'package:flutter/material.dart';

import '../game/armor.dart';
import '../game/forge_state.dart';
import '../game/loot/chimera_armor.dart';
import '../game/loot/elite_power.dart';
import '../game/store_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'widgets/pill.dart';
import 'widgets/primary_button.dart';
import 'widgets/stat_chip.dart';
import 'widgets/surface_card.dart';

/// The warrior's store.
///
/// Four shelves: body armour, battle boosters, forge investments and the elite
/// trophy case. Every price here is also listed in the design doc, and the coin
/// sink loop (forge speed-up → fragments → grade skip token) gives late-game
/// coins somewhere to go.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final StoreState store = StoreState.instance;
  final ForgeState forge = ForgeState.instance;

  int _tab = 0;

  static const List<String> _tabs = <String>[
    'Armour',
    'Boosters',
    'Forge',
    'Elite',
    'Titles',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Store', style: AppText.heading(size: 19)),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[store, forge]),
        builder: (BuildContext context, Widget? child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    CoinPill(animate: true),
                    const SizedBox(width: AppSpacing.sm),
                    Pill(
                      label: 'LV ${store.playerLevel}',
                      icon: '✨',
                      color: AppColors.secondary,
                      background: AppColors.surfaceAlt,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (store.permanentCoinMultiplier > 1)
                      Pill(
                        label: '×${store.permanentCoinMultiplier.toStringAsFixed(1)} coins',
                        icon: '💰',
                        color: AppColors.primaryDark,
                        background: AppColors.surfaceAlt,
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  itemCount: _tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    return GestureDetector(
                      onTap: () => setState(() => _tab = index),
                      child: Pill(
                        label: _tabs[index],
                        color: _tab == index ? Colors.white : AppColors.textPrimary,
                        background: _tab == index ? AppColors.primary : AppColors.surface,
                        border: AppColors.border,
                        bold: _tab == index,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _body()),
            ],
          );
        },
      ),
    );
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return _armorTab();
      case 1:
        return _boosterTab();
      case 2:
        return _forgeTab();
      case 3:
        return _eliteTab();
      default:
        return _titleTab();
    }
  }

  // ------------------------------------------------------------------- armour
  Widget _armorTab() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
      itemCount: ArmorRank.values.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        final ArmorRank armor = ArmorRank.values[index];
        final bool owned = store.ownsArmor(armor);
        final bool equipped = store.equippedArmor == armor;
        final bool affordable = store.coins >= armor.price;
        return SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderColor: equipped ? AppColors.primary : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(armor.colorValue).withAlpha(30),
                      borderRadius: BorderRadius.circular(AppRadius.card - 8),
                      border: Border.all(color: Color(armor.colorValue).withAlpha(120)),
                    ),
                    child: Center(child: Text(armor.icon, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(armor.setName, style: AppText.title(size: 15)),
                        const SizedBox(height: 2),
                        Text(armor.description, style: AppText.body(size: 11.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Pill(
                    label: equipped ? 'WORN' : (owned ? 'OWNED' : '🪙${armor.price}'),
                    color: equipped ? Colors.white : AppColors.textPrimary,
                    background: equipped ? AppColors.primary : AppColors.surfaceAlt,
                    bold: equipped,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  StatChip(icon: '❤️', label: '+${armor.hpBonus} HP'),
                  StatChip(icon: '🛡️', label: '${(armor.defensePercent * 100).round()}% defense'),
                  StatChip(icon: '💨', label: '${(armor.speedBonusPercent * 100).toStringAsFixed(0)}% speed'),
                  StatChip(icon: '✨', label: _effectLabel(armor.effect)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PrimaryButton(
                      label: equipped ? 'EQUIPPED' : (owned ? 'EQUIP' : 'BUY'),
                      icon: equipped ? '✅' : (owned ? '🥋' : '🪙'),
                      enabled: !equipped && (owned || affordable),
                      onPressed: () {
                        if (owned) {
                          store.equipArmor(armor);
                          _snack('${armor.setName} equipped.');
                        } else if (store.buyArmor(armor)) {
                          _snack('${armor.setName} purchased and equipped.');
                        } else {
                          _snack('Not enough coins for ${armor.setName}.');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------- boosters
  Widget _boosterTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
      children: <Widget>[
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              const Text('🧪', style: TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'One booster can be armed per battle. It is consumed when the battle ends, win or lose.',
                  style: AppText.body(size: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...BoosterKind.values.map((BoosterKind booster) {
          final int count = store.boosterCount(booster);
          final bool armed = store.activeBooster == booster;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: armed ? AppColors.primary : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(booster.icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(booster.label, style: AppText.title(size: 14.5)),
                            const SizedBox(height: 2),
                            Text(booster.description, style: AppText.body(size: 11.5, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      Pill(
                        label: '×$count',
                        color: count > 0 ? AppColors.success : AppColors.textMuted,
                        background: AppColors.surfaceAlt,
                        bold: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: PrimaryButton(
                          label: 'BUY · 🪙${booster.price}',
                          icon: '🪙',
                          enabled: store.coins >= booster.price,
                          onPressed: () {
                            if (store.buyBooster(booster)) {
                              _snack('${booster.label} added to your pack.');
                            } else {
                              _snack('Not enough coins.');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: GhostButton(
                          label: armed ? 'ARMED' : 'ARM',
                          icon: armed ? '✅' : '🎯',
                          onPressed: count <= 0
                              ? null
                              : () {
                                  store.activateBooster(armed ? null : booster);
                                  _snack(armed ? 'Booster stowed.' : '${booster.label} armed for the next battle.');
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // -------------------------------------------------------------------- forge
  Widget _forgeTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
      children: <Widget>[
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('FORGE INVESTMENTS', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.2)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Coins buy time: a rushed furnace, a free copy of your best blade, or a grade skip when a level refuses to fall.',
                style: AppText.body(size: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  StatChip(icon: '🔨', label: '${forge.lifetimeMerges} lifetime merges'),
                  StatChip(icon: '🗡️', label: 'best: ${forge.bestTier.label}'),
                  StatChip(icon: '🧩', label: '${store.weaponFragments} fragments'),
                  StatChip(icon: '🎟️', label: '${store.gradeSkipTokens} skip tokens'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _sinkCard(
          icon: '⚡',
          title: 'Forge speed-up',
          price: StoreState.forgeSpeedUpPrice,
          description: 'Slams a fresh dagger out of the furnace immediately, ignoring the manual cooldown.',
          currency: '🪙',
          enabled: store.coins >= StoreState.forgeSpeedUpPrice && !forge.isFull,
          onBuy: () {
            if (store.buyForgeSpeedUp()) {
              _snack('Furnace rushed.');
            } else {
              _snack(forge.isFull ? 'The grid is full - merge or clear a slot first.' : 'Not enough coins.');
            }
          },
        ),
        _sinkCard(
          icon: '🧩',
          title: 'Weapon fragment',
          price: StoreState.weaponFragmentPrice,
          description: 'Injects a copy of your strongest blade straight into the grid.',
          currency: '🪙',
          enabled: store.coins >= StoreState.weaponFragmentPrice && !forge.isFull,
          onBuy: () {
            if (store.buyWeaponFragment()) {
              _snack('A copy of your ${forge.bestTier.label} appears in the grid.');
            } else {
              _snack(forge.isFull ? 'The grid is full.' : 'Not enough coins.');
            }
          },
        ),
        _sinkCard(
          icon: '🎟️',
          title: 'Grade skip token',
          price: StoreState.gradeSkipTokenPrice,
          description: 'Clears the next locked campaign level with a C grade so you can push past a wall.',
          currency: '🪙',
          enabled: store.coins >= StoreState.gradeSkipTokenPrice,
          onBuy: () {
            if (store.buyGradeSkipToken()) {
              _snack('Level skipped with a C grade.');
            } else {
              _snack('Not enough coins - the token costs 🪙${StoreState.gradeSkipTokenPrice}.');
            }
          },
        ),
        _sinkCard(
          icon: '🔨',
          title: 'Manual forge now (free)',
          price: 0,
          description: 'Uses the free 10s manual cooldown. Same result, no coins spent.',
          currency: '',
          enabled: forge.canForgeNow,
          onBuy: () {
            forge.forgeNow();
            _snack('Dagger forged.');
          },
        ),
      ],
    );
  }

  Widget _sinkCard({
    required String icon,
    required String title,
    required int price,
    required String description,
    required String currency,
    required bool enabled,
    required VoidCallback onBuy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(title, style: AppText.title(size: 14.5))),
                if (price > 0)
                  Pill(
                    label: '$currency$price',
                    color: enabled ? AppColors.primaryDark : AppColors.textMuted,
                    background: AppColors.surfaceAlt,
                    bold: true,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(description, style: AppText.body(size: 12, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: price > 0 ? 'BUY' : 'USE',
              icon: '🛒',
              enabled: enabled,
              onPressed: onBuy,
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------- elite
  Widget _eliteTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
      children: <Widget>[
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('ELITE INVENTORY', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.2)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Elite armour and powers only drop from chimera chests. Nothing here can be bought with coins.',
                style: AppText.body(size: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  StatChip(icon: '🛡️', label: '${store.ownedEliteArmors.length}/7 armours'),
                  StatChip(icon: '🌟', label: '${store.unlockedPowers.length}/10 powers'),
                  StatChip(icon: '🎁', label: '${store.eliteChestsOpened} chests'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (store.ownedEliteArmors.isEmpty)
          SurfaceCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'No elite armour yet. Beat a chimera and open its chest to start the collection.',
              style: AppText.body(size: 12.5, color: AppColors.textMuted),
            ),
          ),
        ...ChimeraArmorKind.values.where((ChimeraArmorKind a) => store.ownedEliteArmors.contains(a)).map(
          (ChimeraArmorKind armor) {
            final bool equipped = store.equippedEliteArmor == armor;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                borderColor: equipped ? AppColors.primary : null,
                child: Row(
                  children: <Widget>[
                    Text(armor.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(armor.label, style: AppText.title(size: 14)),
                          const SizedBox(height: 2),
                          Text(armor.description, style: AppText.body(size: 11.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    GhostButton(
                      label: equipped ? 'WORN' : 'WEAR',
                      onPressed: () {
                        store.equipEliteArmor(equipped ? null : armor);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('ASSIST MODE', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.2)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Unlocks after five failed attempts on the same chimera: +50% HP, +30% damage, -30% damage taken, grade capped at B.',
                style: AppText.body(size: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PrimaryButton(
                      label: store.assistMode ? 'ASSIST ARMED' : 'ARM ASSIST',
                      icon: '🤝',
                      onPressed: () {
                        store.setAssistMode(!store.assistMode);
                        _snack(store.assistMode ? 'Assist mode armed for the next trial.' : 'Assist mode off.');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('POWER LADDER', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.2)),
              const SizedBox(height: AppSpacing.md),
              ...ElitePowerKind.unlockOrder.map((ElitePowerKind power) {
                final bool owned = store.unlockedPowers.contains(power);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Text(owned ? power.icon : '🔒', style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(power.label, style: AppText.title(size: 12.5))),
                      Expanded(
                        flex: 2,
                        child: Text(
                          power.description,
                          style: AppText.body(size: 11, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- titles
  Widget _titleTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
      children: <Widget>[
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('TITLES', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.2)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Rank bosses, chests and the level ladder hand out titles. Tap one to wear it.',
                style: AppText.body(size: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...store.ownedTitles.map((String title) {
          final bool equipped = store.equippedTitle == title;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: equipped ? AppColors.primary : null,
              child: Row(
                children: <Widget>[
                  Text(equipped ? '🏷️' : '📜', style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(title, style: AppText.title(size: 14))),
                  GhostButton(
                    label: equipped ? 'WORN' : 'WEAR',
                    onPressed: () {
                      store.equipTitle(title);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        if (store.ownedCosmetics.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SurfaceCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('COSMETICS', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.2)),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: store.ownedCosmetics
                      .map((String cosmetic) => StatChip(icon: '🎨', label: cosmetic))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Human readable text for an armour's passive effect.
  String _effectLabel(ArmorEffect effect) {
    switch (effect) {
      case ArmorEffect.none:
        return 'no passive';
      case ArmorEffect.regen:
        return '+5 HP/s regen';
      case ArmorEffect.reflect:
        return 'reflects 10% damage';
      case ArmorEffect.revive:
        return '1 free revive';
    }
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: AppText.body(size: 13, color: Colors.white)),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          duration: AppMotion.reveal,
        ),
      );
  }
}
