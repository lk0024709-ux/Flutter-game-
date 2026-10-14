import 'package:material_ui/material_ui.dart';

import '../domain/game_models.dart';
import '../game/battle_game.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import 'battle_screen.dart';

class EliteScreen extends StatelessWidget {
  const EliteScreen({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: state,
            builder: (context, _) => CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHeader(context),
                      const SizedBox(height: 26),
                      _buildHero(context),
                      const SizedBox(height: 24),
                      const Eyebrow('Seven fusion encounters'),
                      const SizedBox(height: 11),
                      for (final chimera in ChimeraType.values) ...[
                        _ChimeraCard(
                          chimera: chimera,
                          unlocked: state.isEliteUnlocked(chimera.index),
                          cleared: state.hasClearedElite(chimera.index),
                          onTap: () {
                            if (!state.isEliteUnlocked(chimera.index)) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Defeat the previous chimera to open this trial.')));
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BattleScreen(state: state, config: BattleConfig.elite(chimera)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 11),
                      ],
                      const SizedBox(height: 9),
                      Center(child: Text('No boosters. No allies. Just you and the chimera.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.darkMuted))),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        RoundIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Elite mode · dark trial', color: AppColors.darkMuted),
              Text('The Chimera Trials', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        CoinPill(coins: state.coins, compact: true),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    final unlocked = state.eliteModeUnlocked;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B352C), Color(0xFF27241F)],
        ),
        border: Border.all(color: const Color(0xFF4A4438)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('One warrior. One beast.', color: Color(0xFFD4B27A)),
                    const SizedBox(height: 7),
                    Text('A quieter kind of\nchaos.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.darkText, height: 1.08, fontSize: 27)),
                  ],
                ),
              ),
              const Text('🐲', style: TextStyle(fontSize: 49)),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            unlocked ? 'Seven bosses. Three shifting phases. Their arena belongs to them until you take it back.' : 'Clear Bronze level 50 to enter the private arena. Your campaign progress is saved here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.darkMuted),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              _DarkStat(label: 'BOSSES', value: '${state.eliteWins}/7'),
              const SizedBox(width: 9),
              const _DarkStat(label: 'PLAYER HP', value: '2×'),
              const SizedBox(width: 9),
              _DarkStat(label: 'REVIVES', value: '2'),
            ],
          ),
          if (!unlocked) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (state.highestClearedLevel / 50).clamp(0, 1).toDouble(),
                backgroundColor: const Color(0xFF4A4438),
                color: const Color(0xFFD4A75E),
                minHeight: 7,
              ),
            ),
            const SizedBox(height: 7),
            Text('Bronze ${state.highestClearedLevel.clamp(0, 50)}/50', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.darkMuted)),
          ],
        ],
      ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  const _DarkStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(13)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.darkMuted, fontSize: 8, letterSpacing: 0.9)),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.darkText)),
          ],
        ),
      ),
    );
  }
}

class _ChimeraCard extends StatelessWidget {
  const _ChimeraCard({required this.chimera, required this.unlocked, required this.cleared, required this.onTap});

  final ChimeraType chimera;
  final bool unlocked;
  final bool cleared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final faded = !unlocked;
    return Opacity(
      opacity: faded ? 0.62 : 1,
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(15),
        color: AppColors.darkSurface,
        borderColor: cleared ? const Color(0xFF657A4F) : AppColors.darkBorder,
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: chimera.color.withValues(alpha: 0.19), borderRadius: BorderRadius.circular(18)),
              child: Center(child: Text(chimera.emoji, style: const TextStyle(fontSize: 23))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('TRIAL ${chimera.index + 1} · ${chimera.arena}', color: chimera.color),
                  const SizedBox(height: 3),
                  Text(chimera.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.darkText)),
                  const SizedBox(height: 3),
                  Text(chimera.ability, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.darkMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _ElitePill(label: '${chimera.hp} HP'),
                      _ElitePill(label: '${chimera.difficulty.toStringAsFixed(1)} threat'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              cleared ? Icons.check_circle_rounded : unlocked ? Icons.arrow_forward_rounded : Icons.lock_rounded,
              color: cleared ? const Color(0xFF9DB37D) : AppColors.darkMuted,
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

class _ElitePill extends StatelessWidget {
  const _ElitePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.darkSurfaceAlt, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.darkMuted, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}
