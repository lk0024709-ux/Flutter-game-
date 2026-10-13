import 'package:flutter/material.dart';

import '../../game/loot/chest_rarity.dart';
import '../../game/loot/loot_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../widgets/pill.dart';
import '../widgets/primary_button.dart';

/// Animated chest reveal.
///
/// Cards land one by one (roughly 110ms apart, each easing in with a small
/// rise and scale) so a mythic drop actually feels like a drop. Tapping the
/// panel reveals everything at once, which keeps repeat farming quick.
class LootReveal extends StatefulWidget {
  const LootReveal({
    super.key,
    required this.items,
    this.chest,
    this.dark = false,
    this.onDone,
  });

  final List<LootItem> items;
  final ChestRarity? chest;
  final bool dark;
  final VoidCallback? onDone;

  @override
  State<LootReveal> createState() => _LootRevealState();
}

class _LootRevealState extends State<LootReveal> with SingleTickerProviderStateMixin {
  static const Duration _perCard = Duration(milliseconds: 110);
  static const Duration _cardDuration = Duration(milliseconds: 260);

  late final AnimationController _controller;
  late final Duration _total;

  @override
  void initState() {
    super.initState();
    _total = _perCard * widget.items.length + _cardDuration;
    _controller = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {});
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool done = _controller.isCompleted;
    final Color track = widget.dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    final Color text = widget.dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final Color muted = widget.dark ? AppColors.darkTextMuted : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.chest != null) _chestHeader(widget.chest!, track, muted),
        const SizedBox(height: AppSpacing.md),
        AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Column(
              children: List<Widget>.generate(widget.items.length, (int index) {
                final double start = index * (_perCard.inMilliseconds / _total.inMilliseconds);
                final double end = start + (_cardDuration.inMilliseconds / _total.inMilliseconds);
                final double t = ((_controller.value - start) / (end - start)).clamp(0.0, 1.0);
                return _card(widget.items[index], t, track, text, muted);
              }),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!done)
          GestureDetector(
            onTap: () {
              _controller.value = 1;
              setState(() {});
            },
            child: Center(
              child: Text('tap to reveal everything', style: AppText.label(size: 11, color: muted)),
            ),
          )
        else
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: widget.onDone == null ? 'STORE IT ALL' : 'COLLECT',
                  icon: '🎒',
                  onPressed: widget.onDone ?? () {},
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _chestHeader(ChestRarity chest, Color track, Color muted) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: chest.color.withAlpha(120)),
      ),
      child: Row(
        children: <Widget>[
          Text(chest.icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(chest.label, style: AppText.title(size: 14)),
                const SizedBox(height: 2),
                Text(
                  '${chest.itemCount} drops · 🪙${chest.minCoins}-${chest.maxCoins} · ✨${chest.minXp}-${chest.maxXp}',
                  style: AppText.label(size: 11, color: muted),
                ),
              ],
            ),
          ),
          Pill(
            label: chest.lootRarity.label,
            icon: chest.lootRarity.icon,
            color: chest.lootRarity.color,
            background: chest.color.withAlpha(30),
          ),
        ],
      ),
    );
  }

  Widget _card(LootItem item, double t, Color track, Color text, Color muted) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * 18),
        child: Transform.scale(
          scale: 0.96 + 0.04 * t,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(AppRadius.card - 4),
              border: Border.all(color: item.color.withAlpha(140)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.color.withAlpha(28),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(color: item.color.withAlpha(110)),
                  ),
                  child: Center(child: Text(item.icon, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(item.label, style: AppText.title(size: 13.5, color: text)),
                          ),
                          if (item.amount > 0)
                            Text(
                              item.kind == LootItemKind.coins ? '+🪙${item.amount}' : '+${item.amount}',
                              style: AppText.number(size: 13, color: item.color),
                            ),
                          if (item.isUnlock) ...<Widget>[
                            const SizedBox(width: AppSpacing.sm),
                            Pill(
                              label: 'NEW',
                              color: Colors.white,
                              background: item.color,
                              fontSize: 9,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(item.description, style: AppText.body(size: 11.5, color: muted)),
                    ],
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
