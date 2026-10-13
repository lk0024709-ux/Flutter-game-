import 'package:flutter/material.dart';

import '../game/creature.dart';
import '../game/level_grade.dart';
import '../game/levels/game_level.dart';
import '../game/levels/level_modifier.dart';
import '../game/levels/levels_data.dart';
import '../game/rank.dart';
import '../game/store_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'battle_screen.dart';
import 'widgets/pill.dart';
import 'widgets/primary_button.dart';
import 'widgets/surface_card.dart';

/// Level select for all 350 campaign levels.
///
/// One rank is shown at a time (50 levels, five per row) which keeps the grid
/// readable on phones while still exposing every level, its grade and its
/// locked/unlocked state.
class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  final StoreState store = StoreState.instance;
  late Rank _rank;

  @override
  void initState() {
    super.initState();
    _rank = _firstPlayableRank();
  }

  Rank _firstPlayableRank() {
    for (final Rank rank in Rank.values) {
      final bool complete = _clearedInRank(rank) >= Rank.levelsPerRank;
      if (!complete) {
        return rank;
      }
    }
    return Rank.grandMasters;
  }

  int _clearedInRank(Rank rank) {
    int cleared = 0;
    for (final GameLevel level in LevelsData.forRank(rank)) {
      if (store.isLevelCleared(level.number)) {
        cleared++;
      }
    }
    return cleared;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Campaign', style: AppText.heading(size: 19)),
        actions: <Widget>[
          Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: CoinPill())),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (BuildContext context, Widget? child) {
          final List<GameLevel> levels = LevelsData.forRank(_rank);
          final int cleared = _clearedInRank(_rank);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  itemCount: Rank.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final Rank rank = Rank.values[index];
                    final bool unlocked = store.rankUnlocked(rank);
                    return GestureDetector(
                      onTap: unlocked ? () => setState(() => _rank = rank) : null,
                      child: Pill(
                        label: unlocked
                            ? '${rank.label} · ${_clearedInRank(rank)}/50'
                            : '${rank.label} 🔒',
                        icon: rank.icon,
                        color: _rank == rank ? Colors.white : AppColors.textPrimary,
                        background: _rank == rank ? Color(rank.colorValue) : AppColors.surface,
                        border: AppColors.border,
                        bold: _rank == rank,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  color: AppColors.surface,
                  child: Row(
                    children: <Widget>[
                      Text(_rank.icon, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_rank.mapName, style: AppText.title(size: 15)),
                            const SizedBox(height: 2),
                            Text(
                              store.rankUnlocked(_rank)
                                  ? 'Coin multiplier ×${_rank.coinMultiplier.toStringAsFixed(1)} · ${cleared}/50 cleared'
                                  : 'Win ${_rank.unlockWins} battles or beat the previous rank boss to unlock.',
                              style: AppText.body(size: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  itemCount: levels.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return _LevelCell(
                      level: levels[index],
                      grade: store.gradeFor(levels[index].number),
                      unlocked: store.isLevelUnlocked(levels[index].number),
                      onTap: () => _openLevel(levels[index]),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openLevel(GameLevel level) {
    if (!store.isLevelUnlocked(level.number)) {
      _lockedSnack(level);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.cardLarge)),
      ),
      builder: (BuildContext context) => _LevelSheet(level: level),
    );
  }

  void _lockedSnack(GameLevel level) {
    final Rank rank = level.rank;
    final String message = store.rankUnlocked(rank)
        ? 'Clear level ${level.number - 1} first - levels unlock in order (three at a time from your best).'
        : '${rank.label} unlocks after ${rank.unlockWins} wins or the previous rank boss.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: AppText.body(size: 13, color: Colors.white)),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// One square in the level grid.
class _LevelCell extends StatelessWidget {
  const _LevelCell({
    required this.level,
    required this.grade,
    required this.unlocked,
    required this.onTap,
  });

  final GameLevel level;
  final LevelGrade grade;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color gradeColor = gradeColorOf(grade);
    final bool boss = level.isBoss;
    final bool mini = level.isMiniBoss;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        decoration: BoxDecoration(
          color: unlocked ? AppColors.surface : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.card - 4),
          border: Border.all(
            color: boss
                ? AppColors.accent.withAlpha(160)
                : (grade.isCleared ? gradeColor.withAlpha(150) : AppColors.border),
            width: boss ? 1.8 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (!unlocked)
              const Text('🔒', style: TextStyle(fontSize: 15))
            else if (boss)
              const Text('👑', style: TextStyle(fontSize: 15))
            else if (mini)
              const Text('💀', style: TextStyle(fontSize: 15))
            else
              Text(
                level.rank.emoji,
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 2),
            Text(
              '${level.number}',
              style: AppText.number(size: 13, color: unlocked ? AppColors.textPrimary : AppColors.textMuted),
            ),
            const SizedBox(height: 1),
            Text(
              grade.isCleared ? grade.label : '—',
              style: AppText.label(size: 10, color: gradeColor, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colour used for a grade badge throughout the UI.
Color gradeColorOf(LevelGrade grade) {
  switch (grade) {
    case LevelGrade.ss:
      return AppColors.gradeSS;
    case LevelGrade.s:
      return AppColors.gradeS;
    case LevelGrade.a:
      return AppColors.gradeA;
    case LevelGrade.b:
      return AppColors.gradeB;
    case LevelGrade.c:
      return AppColors.gradeC;
    case LevelGrade.d:
      return AppColors.gradeD;
    case LevelGrade.none:
      return AppColors.gradeNone;
  }
}

/// Level detail sheet with modifiers, twist, bestiary and the fight button.
class _LevelSheet extends StatelessWidget {
  const _LevelSheet({required this.level});

  final GameLevel level;

  @override
  Widget build(BuildContext context) {
    final StoreState store = StoreState.instance;
    final LevelGrade best = store.gradeFor(level.number);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(level.rank.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Level ${level.number}', style: AppText.heading(size: 20)),
                        const SizedBox(height: 2),
                        Text(
                          '${level.rank.label} · ${level.phase.label}',
                          style: AppText.label(size: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Pill(
                    label: best.isCleared ? 'BEST ${best.label}' : 'NEW',
                    icon: '🎯',
                    color: gradeColorOf(best),
                    background: AppColors.surfaceAlt,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(level.map.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(level.map.name, style: AppText.title(size: 15))),
                        Pill(
                          label: level.map.twistName,
                          icon: level.map.twistIcon,
                          color: AppColors.accent,
                          background: AppColors.surfaceAlt,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      level.map.twistDescription,
                      style: AppText.body(size: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('OBJECTIVE', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${level.phase.description} ${level.npcCount} beasts share the arena and they fight each other as much as they fight you.',
                style: AppText.body(size: 12.5, color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('BESTIARY', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: level.creatureMix
                    .map(
                      (CreatureType type) => Pill(
                        label: type.label,
                        icon: type.emoji,
                        color: AppColors.textPrimary,
                        background: AppColors.surfaceAlt,
                      ),
                    )
                    .toList(),
              ),
              if (level.modifiers.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text('MODIFIERS', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: level.modifiers
                      .map(
                        (LevelModifier modifier) => Pill(
                          label: modifier.label,
                          icon: modifier.icon,
                          color: AppColors.primaryDark,
                          background: AppColors.surfaceAlt,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
                Text(
                  level.modifiers.map((LevelModifier m) => '${m.icon} ${m.description}').join('\n'),
                  style: AppText.body(size: 11.5, color: AppColors.textMuted),
                ),
              ],
              if (level.boss != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'RANK BOSS',
                        style: AppText.label(size: 10, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                            .copyWith(letterSpacing: 2.4),
                      ),
                      const SizedBox(height: 6),
                      Text(level.boss!.name, style: AppText.heading(size: 18, color: AppColors.darkTextPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        level.boss!.subtitle,
                        style: AppText.body(size: 12, color: AppColors.darkTextMuted),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          StatPill(label: '${level.boss!.hp.toInt()} HP', icon: '❤️'),
                          StatPill(label: '${level.boss!.profile.phases.length} phases', icon: '🔁'),
                          StatPill(label: '🪙${level.boss!.coinReward}', icon: '💰'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Reward preview', style: AppText.title(size: 14)),
                          const SizedBox(height: 3),
                          Text(
                            'Base 🪙${level.previewCoins} · SS pays up to ×${LevelGrade.ss.coinMultiplier.toStringAsFixed(0)}',
                            style: AppText.body(size: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Pill(
                      label: 'DIFF ${level.difficulty.toStringAsFixed(1)}',
                      icon: '⚖️',
                      color: AppColors.danger,
                      background: AppColors.surfaceAlt,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'ENTER THE ARENA',
                icon: '⚔️',
                height: 54,
                expand: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BattleScreen.campaign(level: level),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny key/value pill used inside the boss card.
class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.label, required this.icon});

  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(label, style: AppText.number(size: 11, color: AppColors.darkTextPrimary)),
        ],
      ),
    );
  }
}
