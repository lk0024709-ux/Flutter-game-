import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../battle_game.dart';
import '../fighter.dart';
import 'zone_controller.dart';

/// Zone information pill for the top-centre of the battle HUD.
///
/// Shows the current storm radius, the countdown to the next phase, the phase
/// name and a red damage chip when the player is caught outside.
class ZoneHud extends StatelessWidget {
  const ZoneHud({
    super.key,
    required this.controller,
    required this.game,
    this.dark = false,
  });

  final ZoneController controller;
  final BattleGame game;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZoneHudInfo>(
      valueListenable: controller.hud,
      builder: (BuildContext context, ZoneHudInfo info, Widget? child) {
        final Color textColor = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
        return AnimatedContainer(
          duration: AppMotion.quick,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: (dark ? AppColors.darkSurface : AppColors.surface).withAlpha(235),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: info.playerOutside
                  ? AppColors.danger.withAlpha(180)
                  : (dark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                info.suddenDeath ? '🔥' : '🌪️',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                'Zone ${info.zoneLabel}',
                style: AppText.number(size: 12, color: textColor, weight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Container(width: 1, height: 12, color: dark ? AppColors.darkBorder : AppColors.border),
              const SizedBox(width: 6),
              Text(
                info.nextLabel,
                style: AppText.label(
                  size: 11,
                  color: info.suddenDeath ? AppColors.danger : (dark ? AppColors.darkTextMuted : AppColors.textMuted),
                ),
              ),
              if (info.playerOutside) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  '-${info.damagePerSecond.toStringAsFixed(0)}/s',
                  style: AppText.number(size: 11, color: AppColors.danger, weight: FontWeight.w700),
                ),
              ],
              if (info.bloodlust) ...<Widget>[
                const SizedBox(width: 6),
                const Text('🩸', style: TextStyle(fontSize: 11)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Red vignette that pulses while the player stands outside the safe zone.
class StormVignette extends StatelessWidget {
  const StormVignette({
    super.key,
    required this.controller,
    required this.game,
  });

  final ZoneController controller;
  final BattleGame game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<ZoneHudInfo>(
        valueListenable: controller.hud,
        builder: (BuildContext context, ZoneHudInfo info, Widget? child) {
          if (!info.playerOutside) {
            return const SizedBox.shrink();
          }
          final double intensity = (0.1 + (info.damagePerSecond / 30) * 0.25).clamp(0.1, 0.35);
          return AnimatedContainer(
            duration: AppMotion.normal,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.9,
                colors: <Color>[
                  const Color(0x00000000),
                  AppColors.danger.withAlpha((intensity * 255).round()),
                ],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// Small "twist active" indicator used next to the zone pill.
class TwistHud extends StatelessWidget {
  const TwistHud({
    super.key,
    required this.game,
    this.dark = false,
  });

  final BattleGame game;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BattleHudState>(
      valueListenable: game.hud,
      builder: (BuildContext context, BattleHudState state, Widget? child) {
        if (state.twistLabel.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: (dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt).withAlpha(235),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: dark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(state.twistIcon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                state.twistLabel,
                style: AppText.label(
                  size: 11,
                  color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact creature counter pill ("12 beasts • 3 factions left").
class CreatureCounterPill extends StatelessWidget {
  const CreatureCounterPill({super.key, required this.game, this.dark = false});

  final BattleGame game;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BattleHudState>(
      valueListenable: game.hud,
      builder: (BuildContext context, BattleHudState state, Widget? child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: (dark ? AppColors.darkSurface : AppColors.surface).withAlpha(235),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: dark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('🐾', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                '${state.aliveEnemies} beasts',
                style: AppText.number(
                  size: 12,
                  color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '• ${state.aliveFactions} factions',
                style: AppText.label(size: 11, color: dark ? AppColors.darkTextMuted : AppColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Convenience: shield/revive chips for the player status area.
class PlayerStatusChips extends StatelessWidget {
  const PlayerStatusChips({super.key, required this.fighter, this.dark = false});

  final Fighter fighter;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (fighter.poisonStacks > 0)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '☠️ x${fighter.poisonStacks}',
              style: AppText.number(size: 11, color: AppColors.poison, weight: FontWeight.w700),
            ),
          ),
        if (fighter.cowardTimer > 0)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              '🐢 ${fighter.cowardTimer.ceil()}s',
              style: AppText.number(size: 11, color: AppColors.textMuted, weight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
