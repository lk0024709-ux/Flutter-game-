import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/battle_game.dart';
import '../game/battle_result.dart';
import '../game/elite/chimera.dart';
import '../game/elite/elite_battle.dart';
import '../game/level_grade.dart';
import '../game/levels/game_level.dart';
import '../game/levels/levels_data.dart';
import '../game/player.dart';
import '../game/loot/chest_rarity.dart';
import '../game/loot/loot_item.dart';
import '../game/loot/loot_table.dart';
import '../game/safe_zone/zone_hud.dart';
import '../game/store_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'campaign_screen.dart' show gradeColorOf;
import 'elite/chimera_hud.dart';
import 'loot/loot_reveal.dart';
import 'loot/reward_lines.dart';
import 'widgets/pill.dart';
import 'widgets/primary_button.dart';
import 'widgets/stat_chip.dart';
import 'widgets/surface_card.dart';

/// Hosts a single battle: the Flame game, the touch controls and every overlay
/// (boss intro, pause menu, result panel, loot reveal).
///
/// Two entry points exist - [BattleScreen.campaign] for the 350 campaign levels
/// and [BattleScreen.elite] for the Chimera Trials - and both share the same
/// control scheme and result flow.
class BattleScreen extends StatefulWidget {
  const BattleScreen.campaign({super.key, required GameLevel level})
      : level = level,
        trial = null;

  const BattleScreen.elite({super.key, required EliteTrial trial})
      : trial = trial,
        level = null;

  final GameLevel? level;
  final EliteTrial? trial;

  bool get isElite => trial != null;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late final BattleGame game;
  final StoreState store = StoreState.instance;

  double _knobX = 0;
  double _knobY = 0;

  bool _introVisible = true;
  bool _paused = false;
  bool _resolved = false;

  BattleResult? _result;
  ProgressionEvent? _progression;
  List<LootItem> _loot = const <LootItem>[];
  ChestRarity? _chest;
  bool _lootRevealed = false;

  @override
  void initState() {
    super.initState();
    game = widget.isElite
        ? EliteBattleGame.forTrial(widget.trial!)
        : BattleGame(config: BattleConfig.campaign(level: widget.level!));
    _introVisible = widget.isElite || (widget.level?.isBoss ?? false);
    game.paused = _introVisible;
    game.phaseNotifier.addListener(_onPhaseChanged);
  }

  @override
  void dispose() {
    game.phaseNotifier.removeListener(_onPhaseChanged);
    game.pauseEngine();
    super.dispose();
  }

  // ---------------------------------------------------------------- lifecycle
  void _startBattle() {
    setState(() => _introVisible = false);
    game.paused = false;
  }

  void _onPhaseChanged() {
    final BattlePhase phase = game.phaseNotifier.value;
    if (phase == BattlePhase.running || _resolved) {
      return;
    }
    _resolved = true;
    _resolveBattle(phase == BattlePhase.won);
  }

  void _resolveBattle(bool won) {
    final Player player = game.player;
    // GradeCalculator works in 0..100 health percentages while Fighter exposes
    // a 0..1 fraction, so scale once here.
    final GradeBreakdown breakdown = GradeCalculator.evaluate(
      timeSeconds: game.elapsed,
      hpPercent: player.hpPercent * 100,
      damageTaken: player.damageTakenThisBattle,
    );

    late BattleResult result;
    ProgressionEvent progression;
    List<LootItem> loot = const <LootItem>[];
    ChestRarity? chest;

    if (widget.isElite) {
      final EliteBattleGame elite = game as EliteBattleGame;
      final ChimeraType type = elite.trial.type;
      final bool firstClear = !store.isChimeraDefeated(type);
      final bool newBest = breakdown.finalGrade.betterThan(store.chimeraGrade(type));
      if (won) {
        chest = ChestRarity.forGrade(breakdown.finalGrade);
        loot = LootTable.roll(
          rarity: chest,
          rng: math.Random(),
          ownedPowers: store.unlockedPowers,
          themedArmor: elite.trial.armorDrop,
          armorAlreadyOwned: store.ownedEliteArmors.contains(elite.trial.armorDrop),
          assistMode: elite.assistModeUsed,
        );
        result = BattleResult.elite(
          trialIndex: elite.trial.type.index,
          chimeraName: type.label,
          breakdown: breakdown,
          timeSeconds: game.elapsed,
          hpPercent: player.hpPercent,
          damageTaken: player.damageTakenThisBattle,
          kills: game.kills,
          firstClear: firstClear,
          newBest: newBest,
          baseCoinReward: elite.trial.coinReward,
          cappedGradeIndex: elite.assistModeUsed ? LevelGrade.b.index : 0,
        );
      } else {
        result = BattleResult.eliteLoss(
          trialIndex: type.index,
          chimeraName: type.label,
          breakdown: breakdown,
          timeSeconds: game.elapsed,
          hpPercent: player.hpPercent,
          damageTaken: player.damageTakenThisBattle,
          kills: game.kills,
        );
      }
      progression = store.recordEliteResult(
        chimera: type,
        result: result,
        loot: loot,
        assistModeUsed: elite.assistModeUsed,
      );
    } else {
      final GameLevel level = widget.level!;
      final bool firstClear = !store.isLevelCleared(level.number);
      final bool newBest = breakdown.finalGrade.betterThan(store.gradeFor(level.number));
      final bool dailyFirstWin = won && store.markDailyWin();
      result = won
          ? BattleResult.campaignWin(
              level: level,
              breakdown: breakdown,
              timeSeconds: game.elapsed,
              hpPercent: player.hpPercent,
              damageTaken: player.damageTakenThisBattle,
              kills: game.kills,
              firstClear: firstClear,
              newBest: newBest,
              dailyFirstWin: dailyFirstWin,
            )
          : BattleResult.campaignLoss(
              level: level,
              breakdown: breakdown,
              timeSeconds: game.elapsed,
              hpPercent: player.hpPercent,
              damageTaken: player.damageTakenThisBattle,
              kills: game.kills,
            );
      progression = store.recordCampaignResult(result);
    }

    game.paused = true;
    setState(() {
      _result = result;
      _progression = progression;
      _loot = loot;
      _chest = chest;
    });
  }

  // -------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final bool dark = widget.isElite;
    return Scaffold(
      backgroundColor: dark ? AppColors.darkBackground : AppColors.background,
      body: Theme(
        data: dark ? AppTheme.dark : AppTheme.light,
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: GameWidget<BattleGame>(game: game)),
            if (!widget.isElite)
              Positioned.fill(child: StormVignette(controller: game.zones, game: game)),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _topBar(dark),
                  const SizedBox(height: AppSpacing.sm),
                  if (widget.isElite) ChimeraHud(game: game),
                  const Spacer(),
                  _bottomBar(dark),
                ],
              ),
            ),
            if (_introVisible) _introOverlay(dark),
            if (_paused && !_introVisible) _pauseOverlay(dark),
            if (_result != null) _resultOverlay(dark),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- top bar
  Widget _topBar(bool dark) {
    final Color surface = dark ? AppColors.darkSurface : AppColors.surface;
    final Color border = dark ? AppColors.darkBorder : AppColors.border;
    final Color text = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: surface.withAlpha(238),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border),
        boxShadow: softShadow(),
      ),
      child: Row(
        children: <Widget>[
          RoundIconButton(
            icon: '🏠',
            size: 38,
            background: surface,
            onTap: _quit,
            tooltip: 'Leave battle',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ValueListenableBuilder<BattleHudState>(
              valueListenable: game.hud,
              builder: (BuildContext context, BattleHudState state, Widget? child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.isElite
                          ? 'CHIMERA TRIAL'
                          : '${state.mapEmoji} ${state.mapName}',
                      style: AppText.label(size: 10.5, color: text, weight: FontWeight.w800)
                          .copyWith(letterSpacing: 1.4),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isElite
                          ? 'Survive the fusion'
                          : 'L${widget.level!.number} · ${state.aliveEnemies} beasts · ${state.kills} felled',
                      style: AppText.label(size: 10, color: dark ? AppColors.darkTextMuted : AppColors.textMuted),
                    ),
                  ],
                );
              },
            ),
          ),
          if (!widget.isElite) ZoneHud(controller: game.zones, game: game),
          const SizedBox(width: AppSpacing.sm),
          RoundIconButton(
            icon: '⏸️',
            size: 38,
            background: surface,
            onTap: _pause,
            tooltip: 'Pause',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- bottom bar
  Widget _bottomBar(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _vitals(dark),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _joystick(dark),
              const Spacer(),
              _attackButton(dark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitals(bool dark) {
    final Player player = game.player;
    final Color surface = dark ? AppColors.darkSurface : AppColors.surface;
    final Color border = dark ? AppColors.darkBorder : AppColors.border;
    final Color track = dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface.withAlpha(238),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: border),
        boxShadow: softShadow(),
      ),
      child: ValueListenableBuilder<BattleHudState>(
        valueListenable: game.hud,
        builder: (BuildContext context, BattleHudState state, Widget? child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('${state.weaponIcon} ${state.weaponLabel}', style: AppText.label(size: 11, weight: FontWeight.w700)),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${state.armorIcon} ${state.armorLabel}', style: AppText.label(size: 11)),
                  const Spacer(),
                  PlayerStatusChips(fighter: player, dark: dark),
                  Text(
                    '${state.hp.ceil()}/${state.maxHp.ceil()} HP',
                    style: AppText.number(size: 11, color: state.hpPercent < 0.3 ? AppColors.danger : null),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LabelledBar(
                value: state.hpPercent,
                height: 10,
                color: state.hpPercent < 0.3 ? AppColors.danger : AppColors.hpGreen,
                trackColor: track,
              ),
              if (state.shield > 0) ...<Widget>[
                const SizedBox(height: 4),
                LabelledBar(
                  value: (state.shield / math.max(1.0, state.maxHp * 0.4)).clamp(0.0, 1.0),
                  height: 5,
                  color: const Color(0xFF0891B2),
                  trackColor: track,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Pill(
                    label: '⏱ ${formatDuration(state.timeSeconds)}',
                    color: dark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    background: track,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (state.revives > 0)
                    Pill(
                      label: 'REVIVE ×${state.revives}',
                      icon: '❤️',
                      color: AppColors.danger,
                      background: track,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: state.powerUps
                            .map((String power) => Pill(label: power, color: AppColors.secondary, background: track))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _joystick(bool dark) {
    final Color surface = dark ? AppColors.darkSurface : AppColors.surface;
    final Color border = dark ? AppColors.darkBorder : AppColors.border;
    return GestureDetector(
      onPanStart: (DragStartDetails details) => _updateStick(details.localPosition, true),
      onPanUpdate: (DragUpdateDetails details) => _updateStick(details.localPosition, false),
      onPanEnd: (DragEndDetails details) => setState(() {
        _knobX = 0;
        _knobY = 0;
        game.input.move.setZero();
      }),
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          color: surface.withAlpha(190),
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Icon(Icons.open_with, color: AppColors.textMuted, size: 22),
            Transform.translate(
              offset: Offset(_knobX * 40, _knobY * 40),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: softShadow(strong: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateStick(Offset local, bool start) {
    // The joystick is 132px wide, so normalise around the centre.
    final double dx = (local.dx - 66) / 46;
    final double dy = (local.dy - 66) / 46;
    final double length = math.sqrt(dx * dx + dy * dy);
    final double scale = length > 1 ? 1 / length : 1;
    final double nx = dx * scale;
    final double ny = dy * scale;
    setState(() {
      _knobX = nx;
      _knobY = ny;
    });
    game.input.move.setValues(nx, ny);
    if (start && !_introVisible && !_paused) {
      game.paused = false;
    }
  }

  Widget _attackButton(bool dark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTapDown: (TapDownDetails details) => game.input.queueAttack(),
          onTap: () => game.input.queueAttack(),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.accent, Color(0xFF5A2C12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: softShadow(strong: true),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('🗡️', style: TextStyle(fontSize: 30)),
                SizedBox(height: 2),
                Text(
                  'SWING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Pill(
          label: 'hold to keep swinging',
          color: dark ? AppColors.darkTextMuted : AppColors.textMuted,
          background: dark ? AppColors.darkSurface : AppColors.surface,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ overlays
  Widget _introOverlay(bool dark) {
    final bool elite = widget.isElite;
    final String title = elite ? widget.trial!.type.label : (widget.level!.boss?.name ?? 'Rank Boss');
    final String subtitle =
        elite ? widget.trial!.type.tagline : (widget.level!.boss?.subtitle ?? '');
    final String icon = elite ? widget.trial!.type.emoji : (widget.level!.boss?.emoji ?? '👑');

    return Container(
      color: (dark ? AppColors.darkBackground : AppColors.background).withAlpha(238),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: AppMotion.slow,
          curve: Curves.easeOut,
          builder: (BuildContext context, double t, Widget? child) {
            return Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(icon, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'BOSS ENCOUNTER',
                  style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(title, style: AppText.display(size: 32), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 13, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (widget.isElite && !store.eliteUnlocked)
                  Text(
                    'Elite mode locked - clear the Bronze boss or win 12 battles.',
                    textAlign: TextAlign.center,
                    style: AppText.label(size: 11, color: AppColors.danger),
                  ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(label: 'FIGHT', icon: '⚔️', onPressed: _startBattle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay(bool dark) {
    final Player player = game.player;
    return Container(
      color: (dark ? AppColors.darkBackground : AppColors.background).withAlpha(232),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: SurfaceCard(
            color: dark ? AppColors.darkSurface : AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('PAUSED', style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 3)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.isElite ? widget.trial!.type.label : 'Level ${widget.level!.number}',
                  style: AppText.heading(size: 22),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    StatColumn(value: '${game.kills}', label: 'beasts felled', icon: '🐾'),
                    StatColumn(value: formatDuration(game.elapsed), label: 'time', icon: '⏱'),
                    StatColumn(
                      value: '${player.damageTakenThisBattle.ceil()}',
                      label: 'damage taken',
                      icon: '🩸',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    if (player.poisonStacks > 0) StatChip(icon: '☠️', label: '${player.poisonStacks} poison'),
                    if (player.shield > 0) StatChip(icon: '🛡️', label: '${player.shield.ceil()} shield'),
                    StatChip(icon: '⚔️', label: '${player.weapon.label} (${player.weapon.damage.toInt()} dmg)'),
                    StatChip(icon: '🥋', label: player.armor.setName),
                    StatChip(icon: '💀', label: '${game.hud.value.aliveEnemies} beasts alive'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PrimaryButton(
                        label: 'RESUME',
                        icon: '▶️',
                        onPressed: () => setState(() => _paused = false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: GhostButton(label: 'QUIT', icon: '🚪', onPressed: _quit),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultOverlay(bool dark) {
    final BattleResult result = _result!;
    final bool won = result.win;
    return Container(
      color: (dark ? AppColors.darkBackground : AppColors.background).withAlpha(240),
      child: SafeArea(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: AppMotion.slow,
          curve: Curves.easeOut,
          builder: (BuildContext context, double t, Widget? child) {
            return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 30), child: child));
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text(
                  won ? (widget.isElite ? '🐲' : '🏆') : '💀',
                  style: const TextStyle(fontSize: 54),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  won ? 'VICTORY' : 'DEFEATED',
                  style: AppText.display(size: 30, color: won ? AppColors.success : AppColors.danger),
                ),
              ),
              const SizedBox(height: 4),
              Center(child: Text(result.contextLabel, style: AppText.label(size: 12))),
              const SizedBox(height: AppSpacing.lg),
              if (won) _gradeCard(result),
              const SizedBox(height: AppSpacing.md),
              SurfaceCard(
                color: dark ? AppColors.darkSurface : AppColors.surface,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: RewardBreakdown(
                  result: result,
                  playerLevel: store.playerLevel,
                  playerXp: store.playerXp,
                  xpIntoLevel: store.xpIntoLevel,
                  xpForLevel: store.xpForLevel,
                  progression: _progression,
                  dark: dark,
                ),
              ),
              if (won && _loot.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                SurfaceCard(
                  color: dark ? AppColors.darkSurface : AppColors.surface,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _lootRevealed ? 'TRIAL LOOT' : 'CHEST EARNED',
                        style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.4),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (!_lootRevealed)
                        PrimaryButton(
                          label: 'OPEN ${_chest?.label.toUpperCase() ?? 'CHEST'}',
                          icon: _chest?.icon ?? '🎁',
                          onPressed: () => setState(() => _lootRevealed = true),
                        )
                      else
                        LootReveal(items: _loot, chest: _chest, dark: dark),
                    ],
                  ),
                ),
              ],
              if (_progression != null && !_progression!.isEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                SurfaceCard(
                  color: dark ? AppColors.darkSurface : AppColors.surface,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ProgressionList(event: _progression!, dark: dark),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PrimaryButton(
                      label: won && !widget.isElite ? 'NEXT LEVEL' : 'RETRY',
                      icon: won && !widget.isElite ? '⏭' : '🔄',
                      onPressed: _next,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GhostButton(label: 'HOME', icon: '🏠', onPressed: _quit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gradeCard(BattleResult result) {
    final LevelGrade grade = result.grade;
    final Color color = gradeColorOf(grade);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: color.withAlpha(26),
      borderColor: color.withAlpha(120),
      child: Row(
        children: <Widget>[
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Center(
              child: Text(
                grade.label,
                style: AppText.display(size: 26, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(grade.title, style: AppText.title(size: 16)),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(result.timeSeconds)} · ${(result.hpPercent * 100).round()}% health left',
                  style: AppText.body(size: 12, color: AppColors.textMuted),
                ),
                Text(
                  '${result.damageTaken.ceil()} damage taken · ${result.kills} beasts felled',
                  style: AppText.body(size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            children: <Widget>[
              Pill(label: result.breakdown.timeGrade.label, icon: '⏱', color: AppColors.textPrimary, background: AppColors.surfaceAlt),
              const SizedBox(height: 4),
              Pill(label: result.breakdown.hpGrade.label, icon: '❤️', color: AppColors.textPrimary, background: AppColors.surfaceAlt),
              const SizedBox(height: 4),
              Pill(label: result.breakdown.damageGrade.label, icon: '🩸', color: AppColors.textPrimary, background: AppColors.surfaceAlt),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ actions
  void _pause() {
    if (_introVisible || _result != null) {
      return;
    }
    setState(() => _paused = !_paused);
    game.paused = _paused;
  }

  void _next() {
    if (_result != null && _result!.win && !widget.isElite) {
      final int number = widget.level!.number;
      final int next = number >= 350 ? number : number + 1;
      if (store.isLevelUnlocked(next)) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => BattleScreen.campaign(level: LevelsData.byNumber(next)),
          ),
        );
        return;
      }
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => widget.isElite
            ? BattleScreen.elite(trial: widget.trial!)
            : BattleScreen.campaign(level: widget.level!),
      ),
    );
  }

  void _quit() {
    Navigator.of(context).pop();
  }
}
