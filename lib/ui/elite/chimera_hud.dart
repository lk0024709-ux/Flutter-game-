import 'package:flutter/material.dart';

import '../../game/battle_game.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../widgets/pill.dart';

/// Elite boss bar.
///
/// Elite mode is the only place the interface turns dark, so the boss bar is
/// built from the dark palette: the chimera's name, a chunky health bar split
/// into three phase segments, phase pips and the live telegraph readout
/// ("🦅 DIVE STRIKE") so the player can read the wind-up from across the room.
class ChimeraHud extends StatelessWidget {
  const ChimeraHud({super.key, required this.game, this.dark = true});

  final BattleGame game;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ValueListenableBuilder<BattleHudState>(
        valueListenable: game.hud,
        builder: (BuildContext context, BattleHudState state, Widget? child) {
          if (state.chimeraName.isEmpty) {
            return const SizedBox.shrink();
          }
          final double hpPercent = state.chimeraMaxHp <= 0
              ? 0
              : (state.chimeraHp / state.chimeraMaxHp).clamp(0.0, 1.0);
          final int phase = state.chimeraPhase;
          final Color surface = dark ? AppColors.darkSurface : AppColors.surface;
          final Color border = dark ? AppColors.darkBorder : AppColors.border;
          final Color text = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
          final Color muted = dark ? AppColors.darkTextMuted : AppColors.textMuted;

          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surface.withAlpha(240),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: border),
              boxShadow: <BoxShadow>[
                BoxShadow(color: AppColors.shadowStrong, blurRadius: 20, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        state.chimeraName.toUpperCase(),
                        style: AppText.label(size: 12, color: text, weight: FontWeight.w800)
                            .copyWith(letterSpacing: 2),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _phasePips(phase),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${state.chimeraHp.ceil()} / ${state.chimeraMaxHp.ceil()}',
                      style: AppText.number(size: 11.5, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Phase-segmented health bar: the notch marks at 66% and 33%
                // show exactly where the phase shifts happen.
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double width = constraints.maxWidth;
                    return SizedBox(
                      height: 14,
                      child: Stack(
                        children: <Widget>[
                          Container(
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: hpPercent,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: phase >= 3
                                      ? <Color>[AppColors.danger, AppColors.accent]
                                      : phase == 2
                                          ? <Color>[AppColors.primaryDark, AppColors.primary]
                                          : <Color>[AppColors.secondary, AppColors.primaryDark],
                                ),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                          ),
                          for (final double mark in <double>[0.33, 0.66])
                            Positioned(
                              left: width * mark - 0.5,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 1.6,
                                color: (dark ? AppColors.darkBackground : AppColors.background).withAlpha(190),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Pill(
                      label: 'PHASE $phase',
                      color: phase >= 3 ? AppColors.danger : AppColors.primary,
                      background: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                      fontSize: 10,
                      bold: true,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (state.chimeraWindup.isNotEmpty)
                      Pill(
                        label: state.chimeraWindup,
                        icon: '⚠️',
                        color: AppColors.danger,
                        background: AppColors.danger.withAlpha(26),
                        fontSize: 10,
                        bold: true,
                      ),
                    const Spacer(),
                    if (state.shield > 0)
                      Pill(
                        label: '🛡️ OWN SHIELD',
                        color: const Color(0xFF0891B2),
                        background: dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                        fontSize: 10,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _phasePips(int phase) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= 3; i++)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: AnimatedContainer(
              duration: AppMotion.quick,
              width: phase >= i ? 16 : 9,
              height: 6,
              decoration: BoxDecoration(
                color: phase >= i
                    ? (i >= 3 ? AppColors.danger : AppColors.primary)
                    : (dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small dark pill used for elite-only readouts (attempts, assist mode, ...).
class EliteTag extends StatelessWidget {
  const EliteTag({super.key, required this.label, this.icon, this.color});

  final String label;
  final String? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Text(icon!, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppText.label(size: 10.5, color: color ?? AppColors.darkTextMuted, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
