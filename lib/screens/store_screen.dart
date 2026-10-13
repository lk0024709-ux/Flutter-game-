import 'package:material_ui/material_ui.dart';

import '../domain/game_models.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.state});

  final GameState state;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.state,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: 23),
                    _buildIntro(),
                    const SizedBox(height: 20),
                    _buildTabs(),
                    const SizedBox(height: 18),
                    if (_tab == 0) ..._buildArmors() else ..._buildBoosters(),
                    const SizedBox(height: 24),
                    _buildForgeSupplies(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        RoundIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        Expanded(child: Text('The supply hall', style: Theme.of(context).textTheme.titleLarge)),
        CoinPill(coins: widget.state.coins, compact: true),
      ],
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Equipped for the road'),
        const SizedBox(height: 6),
        Text('Choose your edge.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 27)),
        const SizedBox(height: 6),
        Text('Good armor is patient. A good tonic knows when to leave.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          _StoreTab(title: 'Armors', icon: Icons.shield_rounded, selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
          _StoreTab(title: 'Boosters', icon: Icons.bolt_rounded, selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
        ],
      ),
    );
  }

  List<Widget> _buildArmors() {
    return [
      for (final armor in ArmorRank.values) ...[
        _ArmorCard(
          armor: armor,
          owned: widget.state.ownsArmor(armor),
          equipped: widget.state.equippedArmor == armor,
          onAction: () {
            if (widget.state.ownsArmor(armor)) {
              widget.state.equipArmor(armor);
            } else {
              final bought = widget.state.buyArmor(armor);
              if (!bought) _showNotEnough();
            }
          },
        ),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 3),
      SurfaceCard(
        padding: const EdgeInsets.all(15),
        color: const Color(0xFFF5F0E5),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark, size: 19),
            const SizedBox(width: 10),
            Expanded(child: Text('One armor can be equipped at a time. Permanent bonuses travel into every campaign battle.', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildBoosters() {
    return [
      SurfaceCard(
        padding: const EdgeInsets.all(15),
        color: const Color(0xFFF5F0E5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.tips_and_updates_outlined, color: AppColors.primaryDark, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Choose one tonic to carry into your next campaign battle. Elite trials are kept fair: boosters are disabled there.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (widget.state.activeBooster != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(color: const Color(0xFFEAF0E1), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('${widget.state.activeBooster!.title} is selected for your next campaign battle.', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.secondary))),
                TextButton(onPressed: () => widget.state.selectBooster(null), child: const Text('Clear')),
              ],
            ),
          ),
        ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: Booster.values.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 11,
          mainAxisSpacing: 11,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          final booster = Booster.values[index];
          return _BoosterCard(
            booster: booster,
            count: widget.state.boosterCount(booster),
            selected: widget.state.activeBooster == booster,
            onBuy: () {
              if (!widget.state.buyBooster(booster)) _showNotEnough();
            },
            onSelect: () => widget.state.selectBooster(booster),
          );
        },
      ),
    ];
  }

  Widget _buildForgeSupplies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(title: 'Forge supplies', subtitle: 'Small investments for the long road'),
        const SizedBox(height: 12),
        _SupplyTile(
          icon: Icons.local_fire_department_rounded,
          title: 'Forge speed-up',
          detail: 'Permanently shortens auto-forge time by 0.5s (min 1.5s).',
          cost: 200,
          buttonLabel: 'Buy',
          enabled: widget.state.forgeInterval > 1.5 && widget.state.coins >= 200,
          onTap: () {
            if (!widget.state.buyForgeSpeedUp()) _showNotEnough();
          },
        ),
        const SizedBox(height: 9),
        _SupplyTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Weapon fragment',
          detail: 'Adds a dagger to the first empty Forge slot.',
          cost: 500,
          buttonLabel: 'Buy',
          enabled: !widget.state.isForgeFull && widget.state.coins >= 500,
          onTap: () {
            if (!widget.state.buyWeaponFragment()) _showNotEnough();
          },
        ),
        const SizedBox(height: 9),
        _SupplyTile(
          icon: Icons.skip_next_rounded,
          title: 'Grade skip token',
          detail: 'Unlock the next available campaign trial with a D grade.',
          cost: 3000,
          buttonLabel: 'Buy',
          enabled: widget.state.coins >= 3000,
          onTap: () {
            if (!widget.state.buyGradeSkipToken()) _showNotEnough();
          },
        ),
      ],
    );
  }

  void _showNotEnough() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough coins for that purchase.')));
  }
}

class _StoreTab extends StatelessWidget {
  const _StoreTab({required this.title, required this.icon, required this.selected, required this.onTap});

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? AppColors.primaryDark : AppColors.textMuted),
              const SizedBox(width: 7),
              Text(title, style: TextStyle(color: selected ? AppColors.textPrimary : AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArmorCard extends StatelessWidget {
  const _ArmorCard({required this.armor, required this.owned, required this.equipped, required this.onAction});

  final ArmorRank armor;
  final bool owned;
  final bool equipped;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final canEquip = owned && !equipped;
    final label = equipped ? 'EQUIPPED' : owned ? 'EQUIP' : 'BUY  ·  ${armor.price}';
    return SurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(color: armor.color.withOpacity(0.15), borderRadius: BorderRadius.circular(17)),
            child: Center(child: Text(armor.icon, style: const TextStyle(fontSize: 27))),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('${armor.rankName} armor', color: armor.color),
                const SizedBox(height: 3),
                Text(armor.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatChip(label: '+${armor.hpBonus} HP', icon: Icons.favorite_rounded, color: armor.color),
                    StatChip(label: '${(armor.defense * 100).round()}% guard', icon: Icons.shield_rounded, color: armor.color),
                    if (armor.speedBonus > 0) StatChip(label: '+${(armor.speedBonus * 100).round()}% speed', icon: Icons.directions_run_rounded, color: armor.color),
                  ],
                ),
                const SizedBox(height: 7),
                Text(armor.description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: ElevatedButton(
              onPressed: equipped ? null : onAction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                backgroundColor: canEquip ? AppColors.secondary : (owned ? const Color(0xFFD8D2C7) : AppColors.primary),
                foregroundColor: owned ? AppColors.textPrimary : Colors.white,
              ),
              child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoosterCard extends StatelessWidget {
  const _BoosterCard({required this.booster, required this.count, required this.selected, required this.onBuy, required this.onSelect});

  final Booster booster;
  final int count;
  final bool selected;
  final VoidCallback onBuy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final hasAny = count > 0;
    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      borderColor: selected ? AppColors.primary.withOpacity(0.55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: const Color(0xFFF6EAD2), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(booster.icon, style: const TextStyle(fontSize: 22))),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: hasAny ? const Color(0xFFEAF0E1) : AppColors.surfaceAlt, borderRadius: BorderRadius.circular(999)),
                child: Text('×$count', style: TextStyle(fontSize: 11, color: hasAny ? AppColors.secondary : AppColors.textMuted, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(booster.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 5),
          Expanded(child: Text(booster.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5))),
          const SizedBox(height: 8),
          if (hasAny)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSelect,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      foregroundColor: selected ? AppColors.secondary : AppColors.textPrimary,
                      side: BorderSide(color: selected ? AppColors.secondary : AppColors.border),
                    ),
                    child: Text(selected ? 'SELECTED' : 'SELECT', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 5),
                OutlinedButton(
                  onPressed: onBuy,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9)),
                  child: Text('🪙${booster.price}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onBuy,
                icon: const Text('🪙', style: TextStyle(fontSize: 12)),
                label: Text('${booster.price}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 9)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SupplyTile extends StatelessWidget {
  const _SupplyTile({required this.icon, required this.title, required this.detail, required this.cost, required this.buttonLabel, required this.enabled, required this.onTap});

  final IconData icon;
  final String title;
  final String detail;
  final int cost;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: AppColors.primaryDark, size: 20),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: enabled ? onTap : null,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [const Text('🪙 ', style: TextStyle(fontSize: 11)), Text('$cost', style: const TextStyle(fontSize: 11))]),
          ),
        ],
      ),
    );
  }
}
