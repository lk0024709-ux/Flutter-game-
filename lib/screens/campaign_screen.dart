import 'package:material_ui/material_ui.dart';

import '../domain/game_models.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';
import '../game/battle_game.dart';
import 'battle_screen.dart';

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key, required this.state});

  final GameState state;

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  Rank _selectedRank = Rank.bronze;

  void _selectRank(Rank rank) {
    if (!widget.state.isRankUnlocked(rank)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rank.title} unlocks at ${rank.unlockWins} campaign wins.')));
      return;
    }
    setState(() => _selectedRank = rank);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.state,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildProgressCard(),
                    const SizedBox(height: 24),
                    const Eyebrow('Your climb'),
                    const SizedBox(height: 11),
                    _buildRankTabs(),
                    const SizedBox(height: 18),
                    _buildMapCard(),
                    const SizedBox(height: 24),
                    SectionHeading(
                      title: '${_selectedRank.title} levels',
                      subtitle: '50 trials · Tap a tile for its briefing',
                      trailing: Text('${_selectedRank.index * 50 + 1}—${(_selectedRank.index + 1) * 50}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                    ),
                    const SizedBox(height: 14),
                    _buildLevelGrid(),
                    const SizedBox(height: 15),
                    _buildLegend(),
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
        RoundIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back to Forge', onPressed: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('Campaign'),
              Text('Ranked arenas', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        CoinPill(coins: widget.state.coins, compact: true),
      ],
    );
  }

  Widget _buildProgressCard() {
    final cleared = widget.state.highestClearedLevel;
    final progress = cleared / 350;
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
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
                    const Eyebrow('Your saga'),
                    const SizedBox(height: 4),
                    Text('${cleared}/350 trials cleared', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('${widget.state.campaignWins} victories · ${widget.state.totalMerges} forge merges', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(color: const Color(0xFFF5E8D1), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(_selectedRank.icon, style: const TextStyle(fontSize: 22))),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.surfaceAlt,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Elite trials ${widget.state.eliteModeUnlocked ? 'unlocked' : 'at Bronze 50'}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted))),
              if (widget.state.hasRannslayerTitle)
                const StatChip(label: 'Rannslayer', icon: Icons.workspace_premium_rounded, color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final rank in Rank.values) ...[
            _RankTab(
              rank: rank,
              selected: rank == _selectedRank,
              unlocked: widget.state.isRankUnlocked(rank),
              onTap: () => _selectRank(rank),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    final map = arenaMaps[_selectedRank.index];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: map.ground.withOpacity(0.5),
        border: Border.all(color: map.accent.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: map.accent.withOpacity(0.17), borderRadius: BorderRadius.circular(18)),
            child: Center(child: Text(_selectedRank.icon, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('${_selectedRank.title} · ${_selectedRank.coinMultiplier.toStringAsFixed(_selectedRank.coinMultiplier == 1 ? 1 : 1)}× coins', color: map.accent),
                const SizedBox(height: 4),
                Text(map.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
                const SizedBox(height: 3),
                Text(map.twist, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary.withOpacity(0.73))),
              ],
            ),
          ),
          const Icon(Icons.landscape_rounded, color: AppColors.textMuted, size: 25),
        ],
      ),
    );
  }

  Widget _buildLevelGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 50,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final level = GameLevel(rank: _selectedRank, levelInRank: index + 1);
        final unlocked = widget.state.isLevelUnlocked(level);
        final gradeScore = widget.state.bestGradeScore(level.globalLevel) ?? 0;
        final grade = gradeScore <= 0 ? LevelGrade.none : LevelGrade.values[gradeScore.clamp(0, LevelGrade.values.length - 1) as int];
        final current = unlocked && level.globalLevel == widget.state.highestClearedLevel + 1;
        return _LevelTile(
          level: level,
          grade: grade,
          unlocked: unlocked,
          current: current,
          onTap: () {
            if (!unlocked) {
              final canSkip = widget.state.gradeSkipTokens > 0 &&
                  widget.state.isRankUnlocked(level.rank) &&
                  level.globalLevel <= widget.state.highestClearedLevel + 4;
              if (canSkip) {
                _showGradeSkipPrompt(level);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clear the earlier trials to reach level ${level.globalLevel}.')));
              }
              return;
            }
            _showLevelBriefing(level);
          },
        );
      },
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _LegendItem(icon: Icons.circle, color: AppColors.primary, label: 'Current'),
        _LegendItem(icon: Icons.star_rounded, color: AppColors.primaryDark, label: 'Mini-boss'),
        _LegendItem(icon: Icons.workspace_premium_rounded, color: Color(0xFF9B742A), label: 'Rank boss'),
        _LegendItem(icon: Icons.lock_rounded, color: AppColors.textMuted, label: 'Locked'),
      ],
    );
  }

  void _showGradeSkipPrompt(GameLevel level) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use a grade skip?'),
        content: Text('Spend one token to clear level ${level.globalLevel} with a D grade and open the next stretch of the campaign.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Keep token')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (widget.state.useGradeSkip(level)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trial cleared with a D grade.')));
              }
            },
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text('Use token'),
          ),
        ],
      ),
    );
  }

  void _showLevelBriefing(GameLevel level) {
    final modifiers = modifiersFor(level);
    final creatures = creaturesFor(level);
    final map = arenaMaps[level.rank.index];
    final baseCoins = 40 + level.levelInRank * 8;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 690),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: level.rank.color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                      child: Center(child: Text(level.isRankBoss ? '👑' : level.rank.icon, style: const TextStyle(fontSize: 24))),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow('${level.rank.title} · LEVEL ${level.levelInRank.toString().padLeft(2, '0')}'),
                          const SizedBox(height: 3),
                          Text(level.isRankBoss ? rankBossName(level) : map.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 18),
                Text(level.isRankBoss ? 'A champion guards this rank. Defeat the boss and its pack to claim a milestone reward.' : map.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 19),
                Row(
                  children: [
                    Expanded(child: _BriefStat(icon: Icons.pets_rounded, label: 'Wild creatures', value: '${level.npcCount}')),
                    const SizedBox(width: 8),
                    Expanded(child: _BriefStat(icon: Icons.speed_rounded, label: 'Difficulty', value: '${level.difficultyMultiplier.toStringAsFixed(1)}×')),
                    const SizedBox(width: 8),
                    Expanded(child: _BriefStat(icon: Icons.monetization_on_rounded, label: 'From', value: '$baseCoins 🪙')),
                  ],
                ),
                const SizedBox(height: 18),
                const Eyebrow('Creature mix'),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final creature in creatures)
                      StatChip(label: '${creature.emoji} ${creature.title}', color: creature.baseColor),
                  ],
                ),
                const SizedBox(height: 17),
                const Eyebrow('Arena modifiers'),
                const SizedBox(height: 9),
                if (modifiers.isEmpty)
                  const StatChip(label: 'Clear skies', icon: Icons.wb_sunny_outlined)
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [for (final modifier in modifiers) StatChip(label: modifier.label, icon: Icons.adjust_rounded, color: AppColors.primary)],
                  ),
                const SizedBox(height: 20),
                ActionButton(
                  label: 'Enter the arena',
                  icon: Icons.arrow_forward_rounded,
                  expanded: true,
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BattleScreen(state: widget.state, config: BattleConfig.campaign(level)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Center(child: Text('Reward depends on your grade, rank, and first-clear bonuses.', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankTab extends StatelessWidget {
  const _RankTab({required this.rank, required this.selected, required this.unlocked, required this.onTap});

  final Rank rank;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : (unlocked ? AppColors.textPrimary : AppColors.textMuted);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.textPrimary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(unlocked ? rank.icon : '🔒', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Text(rank.title, style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.grade, required this.unlocked, required this.current, required this.onTap});

  final GameLevel level;
  final LevelGrade grade;
  final bool unlocked;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBoss = level.isRankBoss;
    final isMini = level.isMiniBoss;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.surface : const Color(0xFFEAE5DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBoss ? const Color(0xFFD5A949) : current ? AppColors.primary : AppColors.border,
          width: isBoss || current ? 1.8 : 1,
        ),
        boxShadow: current ? [BoxShadow(color: AppColors.primary.withOpacity(0.16), blurRadius: 12, offset: const Offset(0, 3))] : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Center(
              child: unlocked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isBoss)
                          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFB18432), size: 16)
                        else if (isMini)
                          const Icon(Icons.star_rounded, color: AppColors.primaryDark, size: 14)
                        else
                          const SizedBox(height: 14),
                        const SizedBox(height: 1),
                        Text('${level.levelInRank}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
                        const SizedBox(height: 1),
                        Text(
                          grade == LevelGrade.none ? (isBoss ? 'BOSS' : 'TRIAL') : grade.label,
                          style: TextStyle(color: grade == LevelGrade.none ? AppColors.textMuted : grade.color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.45),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(height: 3),
                        Text('${level.levelInRank}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
            ),
            if (current)
              Positioned(
                top: 6,
                right: 6,
                child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
              ),
          ],
        ),
      ),
    );
  }
}

class _BriefStat extends StatelessWidget {
  const _BriefStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primaryDark),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}
