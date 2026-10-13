import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// The workhorse card of the whole app: rounded surface, hairline border and a
/// soft drop shadow. Shadows stay subtle (8% black, blur 16-24, offset 0/4).
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.radius = AppRadius.card,
    this.color,
    this.borderColor,
    this.onTap,
    this.shadow = true,
    this.elevated = false,
    this.animateIn = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool shadow;
  final bool elevated;

  /// When true the card fades + slides up on first build (240ms easeOut).
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final Widget body = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (elevated ? AppColors.surfaceAlt : AppColors.surface),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: shadow ? softShadow(strong: elevated) : null,
      ),
      child: child,
    );

    if (onTap == null && !animateIn) {
      return body;
    }

    final Widget interactive = onTap == null
        ? body
        : Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: body,
            ),
          );

    if (!animateIn) {
      return interactive;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: Curves.easeOut,
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: child,
          ),
        );
      },
      child: interactive,
    );
  }
}

/// A labelled section header: title on the left, optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Text(icon!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppText.title(size: 17)),
                if (subtitle != null)
                  Text(subtitle!, style: AppText.label(size: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small helper that renders a caption under a value.
class StatColumn extends StatelessWidget {
  const StatColumn({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.icon,
  });

  final String value;
  final String label;
  final Color? valueColor;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(icon!, style: const TextStyle(fontSize: 13)),
              ),
            Text(
              value,
              style: AppText.number(size: 16, color: valueColor ?? AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: AppText.label(size: 10)),
      ],
    );
  }
}
