import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Compact "icon + value" chip used on armor cards, loadout cards and the
/// battle HUD.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.textPrimary,
    this.background,
    this.dense = false,
  });

  final String icon;
  final String label;
  final Color color;
  final Color? background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(icon, style: TextStyle(fontSize: dense ? 10 : 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.label(
              size: dense ? 10 : 12,
              color: color,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled progress bar (used for XP, HP and rank progress).
class LabelledBar extends StatelessWidget {
  const LabelledBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color = AppColors.primary,
    this.trackColor = AppColors.surfaceAlt,
    this.radius = AppRadius.pill,
  });

  final double value;
  final double height;
  final Color color;
  final Color trackColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        color: trackColor,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: v),
            duration: AppMotion.slow,
            curve: Curves.easeOut,
            builder: (BuildContext context, double t, Widget? child) {
              return FractionallySizedBox(
                widthFactor: t.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
