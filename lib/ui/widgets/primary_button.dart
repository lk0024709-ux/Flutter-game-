import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Filled amber action button with a subtle press-scale animation.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.primary,
    this.textColor = Colors.white,
    this.expand = true,
    this.height = 52,
    this.enabled = true,
    this.trailing,
    this.radius = AppRadius.button,
  });

  final String label;
  final String? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool expand;
  final double height;
  final bool enabled;
  final Widget? trailing;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && onPressed != null;
    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Text(icon!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.button(
              size: 15,
              color: active ? textColor : textColor.withAlpha(150),
            ),
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );

    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: Material(
        color: active ? color : color.withAlpha(110),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: active ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Outlined companion used for secondary actions ("Retry", "Store", ...).
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.textPrimary,
    this.background = AppColors.surface,
    this.height = 52,
    this.expand = true,
  });

  final String label;
  final String? icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color background;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Text(icon!, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.button(size: 14, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small square icon button on a frosted card - used for pause / home / skip.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 42,
    this.background = AppColors.surface,
    this.border = AppColors.border,
    this.tooltip,
  });

  final String icon;
  final VoidCallback? onTap;
  final double size;
  final Color background;
  final Color border;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: background,
      shape: CircleBorder(side: BorderSide(color: border, width: 1)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Text(icon, style: TextStyle(fontSize: size * 0.42)),
          ),
        ),
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}
