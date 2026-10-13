import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../domain/game_models.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import 'campaign_screen.dart';
import 'elite_screen.dart';
import 'store_screen.dart';

class ForgeScreen extends StatefulWidget {
  const ForgeScreen({super.key, required this.state});

  final GameState state;

  @override
  State<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends State<ForgeScreen> {
  GameState get state => widget.state;

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -90,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFFE7C38D).withOpacity(0.3), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: state,
              builder: (context, _) => CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildTopBar(),
                        const SizedBox(height: 26),
                        _buildIntro(),
                        const SizedBox(height: 20),
                        _buildCampaignCard(),
                        const SizedBox(height: 23),
                        _buildFurnaceCard(),
                        const SizedBox(height: 22),
                        _buildForgeGrid(),
                        const SizedBox(height: 22),
                        _buildActiveBlade(),
                        const SizedBox(height: 26),
                        _buildHomeLinks(),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            state.hasRannslayerTitle ? 'RANNSLAYER  ·  ETERNAL CHAMPION' : 'THE ARENA REMEMBERS EVERY BLADE',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textMuted.withOpacity(0.75),
                                  letterSpacing: 1.25,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF493D2F),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BATTLE OF', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              Text('SWORD MASTER', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted, letterSpacing: 1.8)),
            ],
          ),
        ),
        CoinPill(coins: state.coins, compact: true),
      ],
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('The smithy is awake'),
        const SizedBox(height: 7),
        Text('Forge your legend.', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 32)),
        const SizedBox(height: 7),
        Text(
          'Shape a blade, then take it into the wild arena.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildCampaignCard() {
    final weapon = state.activeWeapon;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D4C32), Color(0xFF3C332A)],
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF4A3826).withOpacity(0.17), blurRadius: 24, offset: const Offset(0, 9))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: -22,
            child: Transform.rotate(
              angle: -0.23,
              child: Text(weapon.icon, style: const TextStyle(fontSize: 112, color: Color(0x55FFFFFF))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.13), borderRadius: BorderRadius.circular(999)),
                      child: const Text('CAMPAIGN  ·  350 LEVELS', style: TextStyle(color: Color(0xFFF5E9D3), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                    const Spacer(),
                    Text('${weapon.title} ${weapon.icon}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 23),
                const Text('Enter the arena', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(height: 5),
                Text(
                  state.highestClearedLevel == 0 ? 'Your first trial is waiting.' : 'Level ${state.highestClearedLevel + 1} is ready when you are.',
                  style: const TextStyle(color: Color(0xFFD9C9B1), fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _push(CampaignScreen(state: state)),
                        icon: const Icon(Icons.sports_martial_arts_rounded, size: 18),
                        label: const Text('Choose a level'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE7AA54),
                          foregroundColor: const Color(0xFF332719),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Open the store',
                      onPressed: () => _push(StoreScreen(state: state)),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.12),
                        foregroundColor: Colors.white,
                        fixedSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      icon: const Icon(Icons.storefront_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFurnaceCard() {
    final secondsLeft = (state.forgeInterval * (1 - state.forgeProgress)).ceil();
    final manualText = state.isForgeFull
        ? 'Grid full'
        : state.manualForgeSecondsLeft > 0
            ? 'Ready in ${state.manualForgeSecondsLeft}s'
            : 'Forge now';
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: CircularProgressIndicator(
                    value: state.forgeProgress,
                    strokeWidth: 3.5,
                    backgroundColor: AppColors.surfaceAlt,
                    color: AppColors.primary,
                  ),
                ),
                const Text('🔥', style: TextStyle(fontSize: 25)),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('The auto-forge'),
                const SizedBox(height: 4),
                Text(state.isForgeFull ? 'Every slot is occupied' : 'A dagger in ${secondsLeft.clamp(0, 99)}s', style: Theme.of(context).textTheme.titleMedium),
                Text('One blade every ${state.forgeInterval.toStringAsFixed(1)} seconds', style: Theme.of(context).textTheme.bodySmall),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: state.showRecentDaggerSpawn
                      ? const Text('+1 dagger forged', key: ValueKey('dagger-spawn'), style: TextStyle(color: AppColors.secondary, fontSize: 10, fontWeight: FontWeight.w800))
                      : const SizedBox(key: ValueKey('no-dagger-spawn'), height: 0),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 105,
            child: OutlinedButton(
              onPressed: state.isForgeFull || state.manualForgeSecondsLeft > 0
                  ? null
                  : () {
                      state.forgeNow();
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(manualText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgeGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: 'The forge board',
          subtitle: '${state.ownedWeaponCount}/9 blades · Drag matching tiers together',
          trailing: const Text('3 × 3', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 13),
        SurfaceCard(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) => _ForgeSlot(
              index: index,
              tier: state.forgeSlots[index],
              active: state.forgeSlots[index] == state.activeWeapon.level,
              onDrop: (from) {
                if (state.mergeWeapons(from, index)) HapticFeedback.selectionClick();
              },
            ),
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            const Icon(Icons.swipe_rounded, size: 17, color: AppColors.textMuted),
            const SizedBox(width: 7),
            Expanded(
              child: Text('Same tier merges up. Different tiers trade places.', style: Theme.of(context).textTheme.bodySmall),
            ),
            TextButton.icon(
              onPressed: () => _push(StoreScreen(state: state)),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Supplies'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveBlade() {
    final tier = state.activeWeapon;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: tier.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(tier.icon, style: const TextStyle(fontSize: 25))),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Battle-ready blade'),
                const SizedBox(height: 4),
                Text(tier.title, style: Theme.of(context).textTheme.titleMedium),
                Text('${tier.damage} damage  ·  ${tier.reach.round()} reach', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted.withOpacity(0.7)),
        ],
      ),
    );
  }

  Widget _buildHomeLinks() {
    return Row(
      children: [
        Expanded(
          child: _HomeLink(
            icon: Icons.storefront_rounded,
            title: 'Store',
            subtitle: 'Armor & tonics',
            onTap: () => _push(StoreScreen(state: state)),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: _HomeLink(
            icon: Icons.workspace_premium_rounded,
            title: 'Elite trials',
            subtitle: state.eliteModeUnlocked ? 'Chimera fights' : 'Unlock at level 50',
            onTap: () => _push(EliteScreen(state: state)),
          ),
        ),
      ],
    );
  }
}

class _HomeLink extends StatelessWidget {
  const _HomeLink({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgeSlot extends StatelessWidget {
  const _ForgeSlot({required this.index, required this.tier, required this.active, required this.onDrop});

  final int index;
  final int? tier;
  final bool active;
  final ValueChanged<int> onDrop;

  @override
  Widget build(BuildContext context) {
    final isEmpty = tier == null;
    final weapon = isEmpty ? null : WeaponTierData.fromLevel(tier!);
    final background = isEmpty ? const Color(0xFFF6F3ED) : weapon!.accent.withOpacity(0.10);
    final outline = active ? AppColors.primary : (isEmpty ? const Color(0xFFE8E3D8) : weapon!.accent.withOpacity(0.28));
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: outline, width: active ? 2 : 1),
      ),
      child: Stack(
        children: [
          if (isEmpty)
            const Center(child: Icon(Icons.add_rounded, color: Color(0xFFC5BDAF), size: 22))
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(weapon!.icon, style: const TextStyle(fontSize: 29)),
                  const SizedBox(height: 4),
                  Text(weapon.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          if (active && !isEmpty)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
              ),
            ),
        ],
      ),
    );

    return DragTarget<int>(
      onWillAccept: (from) => from != null && from != index,
      onAccept: onDrop,
      builder: (context, candidateData, rejectedData) => AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: candidateData.isNotEmpty ? 0.96 : 1,
        child: Draggable<int>(
          data: index,
          maxSimultaneousDrags: isEmpty ? 0 : 1,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 88, height: 88, child: content),
          ),
          childWhenDragging: Opacity(opacity: 0.22, child: content),
          child: content,
        ),
      ),
    );
  }
}
