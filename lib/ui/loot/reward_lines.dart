import 'package:flutter/material.dart';

import '../../game/battle_result.dart';
import '../../game/loot/xp_system.dart';
import '../../game/store_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../widgets/pill.dart';
import '../widgets/stat_chip.dart';

/// Reward breakdown shown in the result modal: every coin line, the total and
/// the experience bar with any level-ups that happened.
class RewardBreakdown extends StatelessWidget {
  const RewardBreakdown({
    super.key,
    required this.result,
    required this.playerLevel,
    required this.playerXp,
    required this.xpIntoLevel,
    required this.xpForLevel,
    this.progression,
    this.dark = false,
  });

  final BattleResult result;
  final int playerLevel;
  final int playerXp;
  final int xpIntoLevel;
  final int xpForLevel;
  final ProgressionEvent? progression;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color text = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final Color muted = dark ? AppColors.darkTextMuted : AppColors.textMuted;
    final Color track = dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('REWARDS', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.4)),
            const Spacer(),
            Pill(
              label: '+🪙${result.coins}',
              color: AppColors.success,
              background: track,
              bold: true,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...result.rewardLines.map(
          (RewardLine line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: <Widget>[
                Text(line.icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(line.label, style: AppText.body(size: 13, color: text))),
                Text('+🪙${line.coins}', style: AppText.number(size: 13, color: AppColors.success)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Divider(color: track, height: 1),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Text('WARRIOR LEVEL $playerLevel', style: AppText.label(size: 10.5, weight: FontWeight.w800, color: muted).copyWith(letterSpacing: 1.6)),
            const Spacer(),
            Text('+${result.xpReward} XP', style: AppText.number(size: 12, color: AppColors.primaryDark)),
          ],
        ),
        const SizedBox(height: 6),
        LabelledBar(
          value: xpForLevel <= 0 ? 0 : xpIntoLevel / xpForLevel,
          height: 8,
          color: AppColors.primary,
          trackColor: track,
        ),
        const SizedBox(height: 4),
        Text(
          xpIntoLevel >= xpForLevel
              ? 'Level up!'
              : '$xpIntoLevel / $xpForLevel XP to level ${playerLevel + 1}',
          style: AppText.label(size: 11, color: muted),
        ),
        const SizedBox(height: 2),
        Text(
          'Total XP earned: $playerXp',
          style: AppText.label(size: 10.5, color: muted),
        ),
      ],
    );
  }
}

/// Unlocks, titles and level-up rewards gained from the battle that just ended.
class ProgressionList extends StatelessWidget {
  const ProgressionList({super.key, required this.event, this.dark = false});

  final ProgressionEvent event;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color text = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final Color track = dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;

    final List<Widget> rows = <Widget>[];

    for (final LevelUpInfo info in event.levelUps) {
      rows.add(
        _row(
          context,
          icon: '✨',
          title: 'Level ${info.level} reached',
          subtitle: info.summary,
          accent: AppColors.primary,
          track: track,
          text: text,
        ),
      );
    }
    if (event.rankUnlocked != null) {
      rows.add(
        _row(
          context,
          icon: event.rankUnlocked!.icon,
          title: '${event.rankUnlocked!.label} unlocked',
          subtitle: 'New arena: ${event.rankUnlocked!.mapName} · coin multiplier ×${event.rankUnlocked!.coinMultiplier.toStringAsFixed(1)}',
          accent: Color(event.rankUnlocked!.colorValue),
          track: track,
          text: text,
        ),
      );
    }
    if (event.bossDefeated != null) {
      rows.add(
        _row(
          context,
          icon: '👑',
          title: '${event.bossDefeated!.label} boss defeated',
          subtitle: 'The road to the next rank just opened.',
          accent: AppColors.accent,
          track: track,
          text: text,
        ),
      );
    }
    if (event.titleUnlocked != null) {
      rows.add(
        _row(
          context,
          icon: '🏷️',
          title: 'Title unlocked: ${event.titleUnlocked}',
          subtitle: 'Equip it from the store to wear it into battle.',
          accent: AppColors.secondary,
          track: track,
          text: text,
        ),
      );
    }
    if (event.permanentMultiplierUnlocked > 1) {
      rows.add(
        _row(
          context,
          icon: '💰',
          title: 'Permanent coin multiplier ×${event.permanentMultiplierUnlocked.toStringAsFixed(1)}',
          subtitle: 'Applies to every reward from now on.',
          accent: AppColors.success,
          track: track,
          text: text,
        ),
      );
    }

    if (rows.isEmpty) {
      return Row(
        children: <Widget>[
          const Text('📖', style: TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No new unlocks this time - clear more levels or push for a higher grade.',
              style: AppText.body(size: 12.5, color: dark ? AppColors.darkTextMuted : AppColors.textMuted),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('PROGRESSION', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.4)),
        const SizedBox(height: AppSpacing.md),
        ...rows,
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required Color accent,
    required Color track,
    required Color text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(AppRadius.card - 6),
          border: Border.all(color: accent.withAlpha(90)),
        ),
        child: Row(
          children: <Widget>[
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppText.title(size: 13.5, color: text)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.body(
                      size: 11.5,
                      color: dark ? AppColors.darkTextMuted : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
