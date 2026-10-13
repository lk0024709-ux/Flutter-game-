import 'package:flutter/material.dart';

import '../game/forge_state.dart';
import '../game/game_map.dart';
import '../game/levels/game_level.dart';
import '../game/levels/levels_data.dart';
import '../game/rank.dart';
import '../game/store_state.dart';
import '../game/weapon.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'campaign_screen.dart';
import 'battle3d_screen.dart';
import 'elite/elite_screen.dart';
import 'models3d_screen.dart';
import 'store_screen.dart';
import 'widgets/pill.dart';
import 'widgets/primary_button.dart';
import 'widgets/stat_chip.dart';
import 'widgets/surface_card.dart';

/// The hub: forge, campaign entry, elite entry, store and a quick stats strip.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ForgeState forge = ForgeState.instance;
  final StoreState store = StoreState.instance;

  int? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[forge, store]),
          builder: (BuildContext context, Widget? child) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                _header(),
                const SizedBox(height: AppSpacing.xl),
                _heroCard(),
                const SizedBox(height: AppSpacing.lg),
                _forgeCard(),
                const SizedBox(height: AppSpacing.lg),
                _statsCard(),
                const SizedBox(height: AppSpacing.lg),
                _campaignCard(),
                const SizedBox(height: AppSpacing.lg),
                _eliteCard(),
                const SizedBox(height: AppSpacing.lg),
                _storeCard(),
                const SizedBox(height: AppSpacing.lg),
                _arena3dCard(),
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text(
                    'Blade Brawl: Rannbhoomi  •  forged with Flutter + Flame',
                    style: AppText.label(size: 11, color: AppColors.textMuted),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ header
  Widget _header() {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: softShadow(),
          ),
          child: const Center(
            child: Text('⚔️', style: TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('BLADE BRAWL', style: AppText.heading(size: 19)),
              const SizedBox(height: 2),
              Text(
                'RANNBHOOMI',
                style: AppText.label(size: 10, weight: FontWeight.w700).copyWith(
                  letterSpacing: 3.4,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            CoinPill(animate: true),
            const SizedBox(height: 6),
            Pill(
              label: 'LV ${store.playerLevel}',
              icon: '✨',
              color: AppColors.secondary,
              background: AppColors.surfaceAlt,
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------- hero card
  Widget _heroCard() {
    final WeaponTier weapon = forge.activeWeapon;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF3B372F), Color(0xFF6B4A22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        boxShadow: softShadow(strong: true),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'THE FORGE YARD',
            style: AppText.label(size: 11, color: const Color(0xFFE8DCC8), weight: FontWeight.w800)
                .copyWith(letterSpacing: 2.6),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Merge blades.\nForge legends.',
            style: AppText.display(size: 30, color: Colors.white).copyWith(height: 1.08),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            store.equippedTitle == 'Novice'
                ? 'Build the blade, then take it into the arena.'
                : 'Fighting as "${store.equippedTitle}".',
            style: AppText.body(size: 13, color: const Color(0xFFE8DCC8)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Row(
              children: <Widget>[
                Text(weapon.icon, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Active blade · ${weapon.label}',
                        style: AppText.title(size: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${weapon.damage.toInt()} damage · ${weapon.perk}',
                        style: AppText.body(size: 12, color: const Color(0xFFE8DCC8)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '⚡${weapon.cooldown.toStringAsFixed(2)}s',
                  style: AppText.number(size: 12, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: 'PLAY NEXT LEVEL',
                  icon: '⚔️',
                  height: 52,
                  onPressed: () => _openCampaign(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- forge card
  Widget _forgeCard() {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Weapon Forge',
            subtitle: 'Drag a blade onto its twin to merge. Tap two tiles to swap.',
            icon: '🔥',
            trailing: Pill(
              label: '${forge.merges} merges',
              icon: '🔨',
              color: AppColors.textMuted,
              background: AppColors.surfaceAlt,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              _FurnaceRing(forge: forge),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      forge.isFull ? 'Furnace blocked' : 'Next dagger in ${forge.secondsUntilNext.toStringAsFixed(1)}s',
                      style: AppText.title(size: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'One dagger every ${forge.intervalSeconds.toStringAsFixed(1)}s. Two equal blades fuse one tier higher.',
                      style: AppText.body(size: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        GhostButton(
                          label: forge.canForgeNow ? 'FORGE NOW' : '${forge.manualCooldownLeft.ceil()}s',
                          icon: '🔨',
                          onPressed: forge.canForgeNow ? () => forge.forgeNow() : null,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        GhostButton(
                          label: 'RUSH · 🪙${StoreState.forgeSpeedUpPrice}',
                          icon: '⚡',
                          onPressed: forge.isFull || store.coins < StoreState.forgeSpeedUpPrice
                              ? null
                              : () {
                                  if (store.buyForgeSpeedUp()) {
                                    _snack('Furnace rushed - a dagger slams out.');
                                  } else {
                                    _snack('Not enough coins.');
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ForgeState.gridSize,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (BuildContext context, int index) {
              return _slot(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _slot(int index) {
    final WeaponTier? tier = forge.slots[index];
    final bool selected = _selectedSlot == index;
    final Widget tile = _WeaponTile(
      tier: tier,
      selected: selected,
      onTap: () => _onSlotTap(index),
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (DragTargetDetails<int> details) => details.data != index,
      onAcceptWithDetails: (DragTargetDetails<int> details) => _merge(details.data, index),
      builder: (BuildContext context, List<int?> candidates, List<dynamic> rejected) {
        final bool hovering = candidates.isNotEmpty;
        return AnimatedScale(
          scale: hovering ? 1.04 : 1.0,
          duration: AppMotion.quick,
          curve: Curves.easeOut,
          child: LongPressDraggable<int>(
            data: index,
            delay: const Duration(milliseconds: 140),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(width: 96, height: 96, child: _WeaponTile(tier: tier, lifted: true)),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: tile),
            child: tile,
          ),
        );
      },
    );
  }

  void _onSlotTap(int index) {
    final WeaponTier? tier = forge.slots[index];
    if (_selectedSlot == null) {
      if (tier == null) {
        _snack('That slot is empty - the furnace fills it for you.');
        return;
      }
      setState(() => _selectedSlot = index);
      return;
    }
    if (_selectedSlot == index) {
      setState(() => _selectedSlot = null);
      return;
    }
    final int from = _selectedSlot!;
    setState(() => _selectedSlot = null);
    _merge(from, index);
  }

  void _merge(int from, int to) {
    final MergeOutcome outcome = forge.moveOrMerge(from, to);
    switch (outcome) {
      case MergeOutcome.merged:
        _snack('Merged into ${forge.slots[to]?.label ?? 'a new blade'}!');
        break;
      case MergeOutcome.swapped:
        _snack('Blades swapped.');
        break;
      case MergeOutcome.moved:
        break;
      case MergeOutcome.refused:
        _snack('Two mythic blades cannot fuse any further.');
        break;
    }
  }

  // -------------------------------------------------------------- stats card
  Widget _statsCard() {
    final int cleared = store.clearedLevelCount;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          StatColumn(value: '$cleared', label: 'levels cleared', icon: '🗺️'),
          StatColumn(value: '${store.totalWins}', label: 'battles won', icon: '🏆'),
          StatColumn(value: '${store.totalKills}', label: 'beasts felled', icon: '🐾'),
          StatColumn(
            value: '${store.chimerasDefeated.length}/7',
            label: 'chimeras',
            icon: '🐲',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- campaign card
  Widget _campaignCard() {
    final int next = _nextLevelNumber();
    final int cleared = store.clearedLevelCount;
    final Rank rank = Rank.ofLevel(next);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: _openCampaign,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Campaign',
            subtitle: '350 levels across seven ranked arenas.',
            icon: '🗺️',
            trailing: Text(
              '$cleared/350',
              style: AppText.number(size: 13, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LabelledBar(value: cleared / Rank.totalLevels, color: AppColors.secondary),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Pill(
                label: '${rank.icon} ${rank.label}',
                color: Color(rank.colorValue),
                background: AppColors.surfaceAlt,
              ),
              const SizedBox(width: AppSpacing.sm),
              Pill(
                label: 'Next · L$next',
                icon: '➡️',
                color: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _nextLevelNumber() {
    for (int number = 1; number <= Rank.totalLevels; number++) {
      if (!store.isLevelCleared(number) && store.isLevelUnlocked(number)) {
        return number;
      }
    }
    return Rank.totalLevels;
  }

  void _openCampaign() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CampaignScreen()),
    );
  }

  // --------------------------------------------------------------- elite card
  Widget _eliteCard() {
    final bool unlocked = store.eliteUnlocked;
    final int defeated = store.chimerasDefeated.length;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.darkBackground, AppColors.darkSurfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        boxShadow: softShadow(strong: true),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🐲', style: TextStyle(fontSize: 26)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CHIMERA TRIALS',
                      style: AppText.label(size: 11, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                          .copyWith(letterSpacing: 2.4),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unlocked ? 'Elite mode open' : 'Locked',
                      style: AppText.heading(size: 20, color: AppColors.darkTextPrimary),
                    ),
                  ],
                ),
              ),
              Pill(
                label: '$defeated/7',
                icon: '🏆',
                color: AppColors.darkTextPrimary,
                background: AppColors.darkSurface,
                border: AppColors.darkBorder,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            unlocked
                ? 'Seven fusion bosses, three phases each, and one chest per trial. Assist mode unlocks after five defeats on the same chimera.'
                : 'Defeat the Bronze rank boss (level 50) or win twelve battles to open the trials.',
            style: AppText.body(size: 12.5, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: unlocked ? 'ENTER ELITE MODE' : 'HOW TO UNLOCK',
                  icon: '🐲',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const EliteScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- 3D showcase
  Widget _arena3dCard() {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Battle3DScreen(map: Maps.byId(_arenaPreviewMapId())),
          ),
        );
        _snack('Entering the 3D arena preview.');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: '3D Arena (preview)',
            subtitle: 'Walk the arena in 3D with downloaded models.',
            icon: '🧊',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'A playable slice of the 3D pivot: real .glb models, a camera that follows the '
                  'warrior, and creatures that scatter when you get close. Combat and progression '
                  'stay on the 2D engine until this slice is proven on device.',
                  style: AppText.body(size: 11.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              StatChip(icon: '🧊', label: 'software 3D renderer', color: AppColors.textPrimary, background: AppColors.surfaceAlt),
              StatChip(icon: '📦', label: 'Kenney + Khronos GLB', color: AppColors.textPrimary, background: AppColors.surfaceAlt),
              StatChip(icon: '🎮', label: 'WASD / joystick', color: AppColors.textPrimary, background: AppColors.surfaceAlt),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: GhostButton(
                  label: 'MODEL ARSENAL',
                  icon: '🗿',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const Models3DScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Arena used by the 3D preview: the map of the next unlocked level, falling
  /// back to the first rank map.
  String _arenaPreviewMapId() {
    final int next = store.nextLevelNumber;
    final GameLevel level = LevelsData.byNumber(next);
    return level.map.id;
  }

  // --------------------------------------------------------------- store card
  Widget _storeCard() {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: "Warrior's Store",
            subtitle: 'Armour, boosters, forge sinks and elite gear.',
            icon: '🛍️',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              StatChip(
                icon: store.equippedArmor.icon,
                label: store.equippedArmor.setName,
                color: Colors.white,
                background: Color(store.equippedArmor.colorValue),
              ),
              StatChip(
                icon: '🧪',
                label: '${store.boosterInventory.values.fold<int>(0, (int a, int b) => a + b)} boosters',
                color: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
              ),
              StatChip(
                icon: '🌟',
                label: '${store.unlockedPowers.length}/10 powers',
                color: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
              ),
              StatChip(
                icon: '✨',
                label: 'Lv ${store.playerLevel} · ${store.xpIntoLevel}/${store.xpForLevel} XP',
                color: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
              ),
            ],
          ),
        ],
      ),
    );
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

/// Circular furnace timer with the emoji in the middle.
class _FurnaceRing extends StatelessWidget {
  const _FurnaceRing({required this.forge});

  final ForgeState forge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 74,
            height: 74,
            child: CircularProgressIndicator(
              value: forge.isFull ? 1 : forge.progress,
              strokeWidth: 6,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const Text('🔥', style: TextStyle(fontSize: 26)),
        ],
      ),
    );
  }
}

/// One forge slot.
class _WeaponTile extends StatelessWidget {
  const _WeaponTile({
    required this.tier,
    this.selected = false,
    this.lifted = false,
    this.onTap,
  });

  final WeaponTier? tier;
  final bool selected;
  final bool lifted;
  final VoidCallback? onTap;

  static const List<Color> _tierColors = <Color>[
    Color(0xFF78716C),
    Color(0xFFA16207),
    Color(0xFF3F6212),
    Color(0xFF0891B2),
    Color(0xFF6366F1),
    Color(0xFF7C2D12),
  ];

  @override
  Widget build(BuildContext context) {
    final WeaponTier? weapon = tier;
    final Color accent = weapon == null
        ? AppColors.textMuted
        : _tierColors[(weapon.level - 1).clamp(0, _tierColors.length - 1)];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: weapon == null ? AppColors.surfaceAlt : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: selected ? AppColors.primary : (weapon == null ? AppColors.border : accent.withAlpha(140)),
            width: selected ? 2.4 : 1.2,
          ),
          boxShadow: lifted ? softShadow(strong: true) : null,
        ),
        child: Center(
          child: weapon == null
              ? const Icon(Icons.add, color: Color(0xFFB7AE9F))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(weapon.icon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 2),
                    Text(
                      weapon.label,
                      style: AppText.label(size: 10, color: accent, weight: FontWeight.w700),
                    ),
                    Text(
                      '${weapon.damage.toInt()} dmg',
                      style: AppText.label(size: 9, color: AppColors.textMuted),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
