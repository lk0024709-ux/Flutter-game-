import 'package:flutter/material.dart';

import '../../game/store_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Rounded 999px pill used for metadata, filters and statuses.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.color = AppColors.textMuted,
    this.background,
    this.border,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.bold = false,
  });

  final String label;
  final String? icon;
  final Color color;
  final Color? background;
  final Color? border;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border ?? AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Text(icon!, style: TextStyle(fontSize: fontSize + 1)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppText.label(
              size: fontSize,
              color: color,
              weight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Coin wallet pill - lives in the top right of nearly every screen.
/// Rebuilds automatically because [StoreState] is a [ChangeNotifier].
class CoinPill extends StatelessWidget {
  const CoinPill({
    super.key,
    this.compact = false,
    this.dark = false,
    this.animate = true,
  });

  final bool compact;
  final bool dark;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StoreState.instance,
      builder: (BuildContext context, Widget? child) {
        final int coins = StoreState.instance.coins;
        final String text = _format(coins);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurfaceAlt : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: dark ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('🪙', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              if (animate)
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: AppMotion.normal,
                  curve: Curves.easeOut,
                  builder: (BuildContext context, double t, Widget? c) {
                    return Opacity(opacity: t, child: c);
                  },
                  child: Text(
                    text,
                    key: ValueKey<String>(text),
                    style: AppText.number(
                      size: compact ? 12 : 14,
                      color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      weight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  text,
                  style: AppText.number(
                    size: compact ? 12 : 14,
                    color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    weight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _format(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return '${value < 0 ? '-' : ''}$buffer';
  }
}

/// Formats an integer with thousands separators - used across the UI.
String formatCoins(int value) => CoinPill._format(value);

/// Formats seconds as m:ss.
String formatDuration(double seconds) {
  final int total = seconds.floor().clamp(0, 100000);
  final int minutes = total ~/ 60;
  final int rest = total % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
