import 'package:flutter/material.dart';

import '../../game/elite/chimera.dart';
import '../../game/elite/chimera_ability.dart';
import '../../game/level_grade.dart';
import '../../game/loot/chest_rarity.dart';
import '../../game/loot/chimera_armor.dart';
import '../../game/loot/elite_power.dart';
import '../../game/store_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../battle_screen.dart';
import '../campaign_screen.dart' show gradeColorOf;
import '../widgets/pill.dart';
import '../widgets/primary_button.dart';
import '../widgets/stat_chip.dart';
import 'chimera_hud.dart';

/// The Chimera Trials hub.
///
/// Everything here is dark: the trials are a different mode, and the palette
/// switch makes that obvious the moment the screen opens. The page holds the
/// seven trials, the ten elite powers, the elite armour collection and the
/// assist-mode switch.
class EliteScreen extends StatefulWidget {
  const EliteScreen({super.key});

  @override
  State<EliteScreen> createState() => _EliteScreenState();
}

class _EliteScreenState extends State<EliteScreen> {
  final StoreState store = StoreState.instance;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(
          backgroundColor: AppColors.darkBackground,
          elevation: 0,
          foregroundColor: AppColors.darkTextPrimary,
          title: Text('Chimera Trials', style: AppText.heading(size: 19, color: AppColors.darkTextPrimary)),
          actions: <Widget>[
            Center(child: Padding(padding: const EdgeInsets.only(right: 16), child: CoinPill(dark: true))),
          ],
        ),
        body: AnimatedBuilder(
          animation: store,
          builder: (BuildContext context, Widget? child) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                _statusCard(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'SEVEN FUSION BOSSES',
                  style: AppText.label(size: 11, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                      .copyWith(letterSpacing: 2.6),
                ),
                const SizedBox(height: AppSpacing.md),
                ...EliteTrial.trials.map(_trialCard),
                const SizedBox(height: AppSpacing.xl),
                _powersCard(),
                const SizedBox(height: AppSpacing.lg),
                _armorCard(),
                const SizedBox(height: AppSpacing.lg),
                _titlesCard(),
              ],
            );
          },
        ),
      ),
    );
  }

  // -------------------------------------------------------------- status card
  Widget _statusCard() {
    final int defeated = store.chimerasDefeated.length;
    final bool unlocked = store.eliteUnlocked;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.darkSurface, AppColors.darkSurfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🐲', style: TextStyle(fontSize: 30)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      unlocked ? 'ELITE MODE OPEN' : 'ELITE MODE LOCKED',
                      style: AppText.label(size: 11, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                          .copyWith(letterSpacing: 2.2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$defeated / 7 chimeras defeated',
                      style: AppText.heading(size: 19, color: AppColors.darkTextPrimary),
                    ),
                  ],
                ),
              ),
              Pill(
                label: 'LV ${store.playerLevel}',
                icon: '✨',
                color: AppColors.darkTextPrimary,
                background: AppColors.darkBackground,
                border: AppColors.darkBorder,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LabelledBar(
            value: defeated / 7,
            height: 8,
            color: AppColors.primary,
            trackColor: AppColors.darkBackground,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            unlocked
                ? 'Each trial is a 1v1 duel on a dark 1600×1600 arena. Bosses fight in three phases, unlock more attacks as they lose health, and are immune to chip damage during phase shifts.'
                : 'Defeat the Bronze rank boss (level 50) or win twelve campaign battles to open the trials.',
            style: AppText.body(size: 12.5, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              EliteTag(label: '${store.eliteChestsOpened} chests opened', icon: '🎁'),
              EliteTag(label: 'assist ${store.assistMode ? 'ON' : 'OFF'}', icon: '🤝'),
              EliteTag(label: '${store.unlockedPowers.length}/10 powers', icon: '🌟'),
              EliteTag(label: '${store.ownedEliteArmors.length}/7 armours', icon: '🛡️'),
              if (store.equippedEliteArmor != null)
                EliteTag(label: store.equippedEliteArmor!.label, icon: store.equippedEliteArmor!.icon),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- trial cards
  Widget _trialCard(EliteTrial trial) {
    final ChimeraType type = trial.type;
    final LevelGrade best = store.chimeraGrade(type);
    final bool levelReady = store.isLevelCleared(trial.unlockAfterLevel);
    final bool open = store.eliteUnlocked && levelReady;
    final bool assistReady = store.assistAvailable(type);
    final bool assistOn = store.assistMode && assistReady;
    final ChestRarity chest = ChestRarity.forGrade(best.isCleared ? best : LevelGrade.a);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: best.isCleared ? Color(type.colorValue).withAlpha(160) : AppColors.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Color(type.colorValue).withAlpha(40),
                  borderRadius: BorderRadius.circular(AppRadius.card - 6),
                  border: Border.all(color: Color(type.colorValue).withAlpha(130)),
                ),
                child: Center(child: Text(type.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(type.label, style: AppText.title(size: 16, color: AppColors.darkTextPrimary)),
                    const SizedBox(height: 2),
                    Text(type.signature, style: AppText.label(size: 11, color: AppColors.darkTextMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Pill(
                    label: best.isCleared ? best.label : 'NEW',
                    color: best.isCleared ? gradeColorOf(best) : AppColors.darkTextMuted,
                    background: AppColors.darkBackground,
                    bold: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${type.hp.toInt()} HP',
                    style: AppText.number(size: 11, color: AppColors.darkTextMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(type.tagline, style: AppText.body(size: 12, color: AppColors.darkTextMuted)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              EliteTag(label: '${type.speed.toStringAsFixed(0)} speed', icon: '💨'),
              EliteTag(label: 'Lv ${trial.unlockAfterLevel} unlock', icon: '🔓'),
              EliteTag(label: '🪙${trial.coinReward}'),
              EliteTag(label: '${chest.label} drop', icon: chest.icon),
              EliteTag(label: '${trial.armorDrop.icon} ${trial.armorDrop.label}'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'ABILITIES',
            style: AppText.label(size: 10, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                .copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: type.abilities
                .map(
                  (ChimeraAbilityKind ability) => EliteTag(
                    label: '${ability.icon} ${ability.label}',
                    color: AppColors.darkTextPrimary,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'DEFENCES',
            style: AppText.label(size: 10, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                .copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: type.defenses
                .map(
                  (ChimeraDefenseKind defense) => EliteTag(
                    label: '${defense.icon} ${defense.label}',
                    color: AppColors.darkTextPrimary,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: open
                      ? (best.isCleared ? 'FIGHT AGAIN' : 'BEGIN TRIAL')
                      : (store.eliteUnlocked ? 'CLEAR LEVEL ${trial.unlockAfterLevel}' : 'LOCKED'),
                  icon: open ? '⚔️' : '🔒',
                  enabled: open,
                  onPressed: open ? () => _fight(trial) : null,
                ),
              ),
              if (assistReady) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: () {
                    store.setAssistMode(!assistOn);
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.quick,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: assistOn ? AppColors.secondary.withAlpha(60) : AppColors.darkBackground,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: assistOn ? AppColors.secondary : AppColors.darkBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('🤝', style: TextStyle(fontSize: 16)),
                        Text(
                          assistOn ? 'ASSIST ON' : 'ASSIST',
                          style: AppText.label(size: 10, color: AppColors.darkTextPrimary, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (assistReady)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Assist: +50% HP, +30% damage dealt, -30% damage taken, grade capped at B.',
                style: AppText.label(size: 10.5, color: AppColors.darkTextMuted),
              ),
            ),
        ],
      ),
    );
  }

  void _fight(EliteTrial trial) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BattleScreen.elite(trial: trial)),
    );
  }

  // ------------------------------------------------------------- powers codex
  Widget _powersCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ELITE POWERS',
            style: AppText.label(size: 11, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                .copyWith(letterSpacing: 2.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Chests unlock these in order. Every unlocked power is always active in elite trials.',
            style: AppText.body(size: 12, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          ...ElitePowerKind.unlockOrder.asMap().entries.map((MapEntry<int, ElitePowerKind> entry) {
            final ElitePowerKind power = entry.value;
            final bool owned = store.unlockedPowers.contains(power);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Text(
                    owned ? power.icon : '🔒',
                    style: TextStyle(fontSize: 18, color: owned ? null : AppColors.darkTextMuted),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          power.label,
                          style: AppText.title(
                            size: 13,
                            color: owned ? AppColors.darkTextPrimary : AppColors.darkTextMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          power.description,
                          style: AppText.body(size: 11.5, color: AppColors.darkTextMuted),
                        ),
                      ],
                    ),
                  ),
                  if (owned)
                    const Pill(
                      label: 'ACTIVE',
                      color: Colors.white,
                      background: AppColors.secondary,
                      fontSize: 9,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- armor codex
  Widget _armorCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'ELITE ARMOUR',
            style: AppText.label(size: 11, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                .copyWith(letterSpacing: 2.4),
          ),
          const SizedBox(height: 4),
          Text(
            'One set per chimera. Only one can be worn, and it stacks on top of your ranked armour.',
            style: AppText.body(size: 12, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          ...ChimeraArmorKind.values.map((ChimeraArmorKind armor) {
            final bool owned = store.ownedEliteArmors.contains(armor);
            final bool equipped = store.equippedEliteArmor == armor;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GestureDetector(
                onTap: owned
                    ? () {
                        store.equipEliteArmor(equipped ? null : armor);
                        setState(() {});
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: BorderRadius.circular(AppRadius.card - 6),
                    border: Border.all(
                      color: equipped
                          ? AppColors.primary
                          : (owned ? Color(armor.colorValue).withAlpha(140) : AppColors.darkBorder),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        owned ? armor.icon : '🔒',
                        style: TextStyle(fontSize: 20, color: owned ? null : AppColors.darkTextMuted),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              armor.label,
                              style: AppText.title(
                                size: 13,
                                color: owned ? AppColors.darkTextPrimary : AppColors.darkTextMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              armor.description,
                              style: AppText.body(size: 11.5, color: AppColors.darkTextMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+${armor.hpBonus} HP · ${(armor.defensePercent * 100).round()}% defense · ${armor.chimera.label}',
                              style: AppText.label(size: 10.5, color: AppColors.darkTextMuted),
                            ),
                          ],
                        ),
                      ),
                      Pill(
                        label: equipped ? 'WORN' : (owned ? 'EQUIP' : 'LOCKED'),
                        color: equipped ? Colors.white : AppColors.darkTextPrimary,
                        background: equipped ? AppColors.primary : AppColors.darkSurface,
                        fontSize: 9.5,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- title codex
  Widget _titlesCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TITLES',
            style: AppText.label(size: 11, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                .copyWith(letterSpacing: 2.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Titles come from rank bosses, chests and the level ladder. Wearing one changes your profile name in the arena.',
            style: AppText.body(size: 12, color: AppColors.darkTextMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: store.ownedTitles.map((String title) {
              final bool equipped = store.equippedTitle == title;
              return GestureDetector(
                onTap: () {
                  store.equipTitle(title);
                  setState(() {});
                },
                child: Pill(
                  label: title,
                  icon: equipped ? '🏷️' : null,
                  color: equipped ? Colors.white : AppColors.darkTextPrimary,
                  background: equipped ? AppColors.primary : AppColors.darkBackground,
                  border: AppColors.darkBorder,
                ),
              );
            }).toList(),
          ),
          if (store.ownedCosmetics.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'COSMETICS',
              style: AppText.label(size: 10, color: AppColors.darkTextMuted, weight: FontWeight.w800)
                  .copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: store.ownedCosmetics
                  .map((String cosmetic) => StatChip(icon: '🎨', label: cosmetic, color: AppColors.darkTextPrimary))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
