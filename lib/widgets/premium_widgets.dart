import 'dart:ui' show FontFeature;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.onTap,
    this.borderColor,
    this.radius = 22,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? (isDark ? AppColors.darkBorder : AppColors.border)),
    );
    return Material(
      color: color ?? (isDark ? AppColors.darkSurface : AppColors.surface),
      shape: shape,
      elevation: shadow && !isDark ? 3 : 0,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color ?? AppColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.25,
          ),
    );
  }
}

class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins, this.compact = false});

  final int coins;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 14, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EAD2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8D7B8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 7),
          Text(
            _format(coins),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primaryDark,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }

  String _format(int value) {
    if (value < 10000) return value.toString();
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}k';
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.expanded = false,
    this.compact = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool expanded;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: compact ? 17 : 18),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
    final button = secondary
        ? OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 18, vertical: compact ? 10 : 13),
              foregroundColor: isDark ? AppColors.darkText : AppColors.textPrimary,
            ),
            child: content,
          )
        : ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: compact ? 10 : 14),
              backgroundColor: enabled ? AppColors.primary : const Color(0xFFD6CFC3),
              foregroundColor: Colors.white,
            ),
            child: content,
          );
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (color ?? AppColors.surfaceAlt).withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color ?? AppColors.textMuted),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkSurfaceAlt : AppColors.surface,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkText : AppColors.textPrimary,
        fixedSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}
