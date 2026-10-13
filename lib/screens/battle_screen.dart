import 'dart:async';

import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../domain/game_models.dart';
import '../game/battle_game.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_widgets.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, required this.state, required this.config});

  final GameState state;
  final BattleConfig config;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with SingleTickerProviderStateMixin {
  late final BattleGame _game;
  late final ValueNotifier<BattleHud> _hud;
  late final Booster? _battleBooster;
  late final AnimationController _gradeController;
  BattleOutcome? _outcome;
  RewardBreakdown? _campaignReward;
  int? _eliteReward;
  bool _bossIntroVisible = false;
  Timer? _bossIntroTimer;

  bool get _isResult => _outcome != null;
  bool get _isElite => widget.config.isElite;

  @override
  void initState() {
    super.initState();
    _hud = ValueNotifier(const BattleHud(
      hp: 120,
      maxHp: 120,
      damageTaken: 0,
      seconds: 0,
      enemyCount: 0,
      enemyTotal: 0,
      zoneLabel: 'ZONE 1200',
      twistLabel: 'ARENA TWIST',
      revivals: 0,
      isElite: false,
      bossHp: 0,
      bossMaxHp: 0,
      bossTitle: '',
      phase: 1,
      poisoned: false,
      coward: false,
      powerupDamage: false,
    ));
    final noPowers = widget.config.level != null && modifiersFor(widget.config.level!).contains(LevelModifier.noPowers);
    _battleBooster = widget.state.consumeBoosterForBattle(elite: _isElite || noPowers);
    _game = BattleGame(
      config: widget.config,
      weapon: widget.state.activeWeapon,
      armor: widget.state.equippedArmor,
      booster: _battleBooster,
      onHud: (snapshot) {
        if (mounted) _hud.value = snapshot;
      },
      onFinish: _handleFinish,
    );
    _gradeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _bossIntroVisible = !_isElite && widget.config.level!.isRankBoss;
    if (_bossIntroVisible) {
      _game.setPaused(true);
      _bossIntroTimer = Timer(const Duration(milliseconds: 2500), _dismissBossIntro);
    }
  }

  @override
  void dispose() {
    _bossIntroTimer?.cancel();
    _game.setPaused(true);
    _hud.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  void _handleFinish(BattleOutcome outcome) {
    if (!mounted || _outcome != null) return;
    _game.setPaused(true);
    final reward = _isElite
        ? null
        : widget.state.recordCampaignResult(widget.config.level!, outcome);
    final eliteReward = _isElite ? widget.state.recordEliteResult(widget.config.chimera!, outcome) : null;
    setState(() {
      _outcome = outcome;
      _campaignReward = reward;
      _eliteReward = eliteReward;
    });
    _gradeController.forward(from: 0);
  }

  void _dismissBossIntro() {
    if (!mounted || !_bossIntroVisible) return;
    _bossIntroTimer?.cancel();
    setState(() => _bossIntroVisible = false);
    _game.setPaused(false);
  }

  void _goHome() {
    _game.setPaused(true);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _retry() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => BattleScreen(state: widget.state, config: widget.config)),
    );
  }

  void _nextBattle() {
    if (_isElite) {
      final nextIndex = widget.config.chimera!.index + 1;
      if (nextIndex >= ChimeraType.values.length || !widget.state.isEliteUnlocked(nextIndex)) {
        _goHome();
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => BattleScreen(state: widget.state, config: BattleConfig.elite(ChimeraType.values[nextIndex]))),
      );
      return;
    }
    final current = widget.config.level!;
    final nextGlobal = current.globalLevel + 1;
    if (nextGlobal > 350) {
      _goHome();
      return;
    }
    final rankIndex = (nextGlobal - 1) ~/ 50;
    final levelInRank = (nextGlobal - 1) % 50 + 1;
    final next = GameLevel(rank: Rank.values[rankIndex], levelInRank: levelInRank);
    if (!widget.state.isLevelUnlocked(next)) {
      _goHome();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => BattleScreen(state: widget.state, config: BattleConfig.campaign(next))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eliteTheme = _isElite;
    return Theme(
      data: eliteTheme ? AppTheme.dark : AppTheme.light,
      child: WillPopScope(
        onWillPop: () async {
          if (!_isResult) _togglePause();
          return false;
        },
        child: Scaffold(
          backgroundColor: eliteTheme ? AppColors.darkBackground : AppColors.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              GameWidget<BattleGame>(game: _game),
              SafeArea(
                child: Stack(
                  children: [
                    Positioned(left: 12, right: 12, top: 10, child: _buildTopBar()),
                    Positioned(left: 16, right: 16, top: 73, child: _buildHealthHud()),
                    if (_isElite) Positioned(left: 16, right: 16, top: 133, child: _buildBossHud()),
                    Positioned(left: 0, bottom: 15, child: VirtualJoystick(onChanged: _game.setMovement)),
                    Positioned(right: 22, bottom: 25, child: _AttackButton(onTap: _attack)),
                    if (_game.isPaused && !_isResult && !_bossIntroVisible) _buildPauseOverlay(),
                    if (_bossIntroVisible) _buildBossIntro(),
                    if (_isResult) _buildResultOverlay(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return ValueListenableBuilder<BattleHud>(
      valueListenable: _hud,
      builder: (context, hud, _) => Row(
        children: [
          _HudButton(icon: Icons.home_rounded, label: 'HOME', onTap: _goHome),
          const SizedBox(width: 7),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: _isElite ? AppColors.darkSurface.withOpacity(0.92) : AppColors.surface.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _isElite ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isElite ? 'THE CHIMERA TRIALS' : arenaMaps[widget.config.level!.rank.index].shortName.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _isElite ? AppColors.darkText : AppColors.textPrimary, fontSize: 9, letterSpacing: 0.9, fontWeight: FontWeight.w800),
                    ),
                    if (!_isElite) ...[
                      Text(
                        'LEVEL ${widget.config.level!.globalLevel} · ${hud.zoneLabel}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted, fontSize: 8, letterSpacing: 0.2),
                      ),
                      Text(hud.twistLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primaryDark, fontSize: 7, letterSpacing: 0.7, fontWeight: FontWeight.w800)),
                    ] else
                      Text('PHASE ${hud.phase} · SOLO BOSS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.darkMuted, fontSize: 8)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          _HudButton(icon: _game.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, label: _formatTime(hud.seconds), onTap: _togglePause),
        ],
      ),
    );
  }

  Widget _buildHealthHud() {
    return ValueListenableBuilder<BattleHud>(
      valueListenable: _hud,
      builder: (context, hud, _) {
        final fraction = hud.maxHp <= 0 ? 0.0 : (hud.hp / hud.maxHp).clamp(0, 1).toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                decoration: BoxDecoration(
                  color: _isElite ? AppColors.darkSurface.withOpacity(0.94) : AppColors.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isElite ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded, color: Color(0xFFB94E3F), size: 15),
                        const SizedBox(width: 6),
                        Text('${hud.hp.ceil()}/${hud.maxHp.ceil()}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12)),
                        const SizedBox(width: 7),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 7,
                              color: fraction < 0.3 ? AppColors.danger : const Color(0xFFD9973F),
                              backgroundColor: _isElite ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(widget.state.equippedArmor.icon, style: const TextStyle(fontSize: 15)),
                        if (hud.revivals > 0) ...[
                          const SizedBox(width: 6),
                          Text('↻${hud.revivals}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (hud.poisoned) _PowerPill(label: 'POISON', icon: Icons.science_rounded, danger: true),
                        if (hud.coward) const _PowerPill(label: 'COWARD', icon: Icons.remove_circle_outline_rounded),
                        if (hud.powerupDamage) const _PowerPill(label: 'MIGHT', icon: Icons.bolt_rounded),
                        if (_isElite) const _PowerPill(label: '2 REVIVES', icon: Icons.restart_alt_rounded),
                        if (!_isElite && widget.state.equippedArmor == ArmorRank.advanced)
                          const _PowerPill(label: 'REGEN', icon: Icons.add_rounded),
                        if (_battleBooster == Booster.damage)
                          const _PowerPill(label: 'DAMAGE', icon: Icons.bolt_rounded),
                        if (_battleBooster == Booster.ironSkin)
                          const _PowerPill(label: 'IRON SKIN', icon: Icons.shield_rounded),
                        if (_battleBooster == Booster.magnet)
                          const _PowerPill(label: 'MAGNET', icon: Icons.auto_awesome_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!_isElite) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: _isElite ? AppColors.darkSurface.withOpacity(0.94) : AppColors.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _isElite ? AppColors.darkBorder : AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.pets_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(height: 2),
                    Text('${hud.enemyCount}', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBossHud() {
    return ValueListenableBuilder<BattleHud>(
      valueListenable: _hud,
      builder: (context, hud, _) {
        final ratio = hud.bossMaxHp <= 0 ? 0.0 : (hud.bossHp / hud.bossMaxHp).clamp(0, 1).toDouble();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(color: AppColors.darkSurface.withOpacity(0.92), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.darkBorder)),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(hud.bossTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.darkText))),
                  Text('${hud.bossHp.ceil()} / ${hud.bossMaxHp.ceil()}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.darkMuted, fontFeatures: const [])),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: ratio, color: const Color(0xFFD4A65D), backgroundColor: AppColors.darkSurfaceAlt, minHeight: 8),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(child: Container(height: 3, decoration: BoxDecoration(color: hud.phase >= i + 1 ? const Color(0xFFD4A65D) : AppColors.darkBorder, borderRadius: BorderRadius.circular(999)))),
                    if (i < 2) const SizedBox(width: 5),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBossIntro() {
    final level = widget.config.level!;
    final modifiers = modifiersFor(level);
    final creature = creaturesFor(level).first;
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1500),
        builder: (context, opacity, _) => Opacity(
          opacity: opacity,
          child: Container(
            color: const Color(0xEE171512),
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  right: 12,
                  child: TextButton.icon(
                    onPressed: _dismissBossIntro,
                    icon: const Icon(Icons.fast_forward_rounded, color: Color(0xFFE8DCC8), size: 17),
                    label: const Text('SKIP', style: TextStyle(color: Color(0xFFE8DCC8), letterSpacing: 1, fontWeight: FontWeight.w800)),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(color: const Color(0xFF3B3328), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF6F5D42))),
                          child: Text('LEVEL ${level.globalLevel}  ·  ${level.rank.title.toUpperCase()}', style: const TextStyle(color: Color(0xFFE4C690), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                        ),
                        const SizedBox(height: 24),
                        Text(creature.emoji, style: const TextStyle(fontSize: 78)),
                        const SizedBox(height: 10),
                        Text(rankBossName(level), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFFF5F1EA), fontSize: 31)),
                        const SizedBox(height: 7),
                        Text('${arenaMaps[level.rank.index].title}  ·  ${level.npcCount} creatures', style: const TextStyle(color: Color(0xFFB8AA96), fontSize: 13)),
                        const SizedBox(height: 19),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final modifier in modifiers)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xFF302B24), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF4A4133))),
                                child: Text(modifier.label, style: const TextStyle(color: Color(0xFFD5C7B1), fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 27),
                        const Text('THE ARENA IS YOURS TO CLAIM', style: TextStyle(color: Color(0xFFE2B66C), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.40),
        child: Center(
          child: SurfaceCard(
            color: _isElite ? AppColors.darkSurface : AppColors.surface,
            padding: const EdgeInsets.fromLTRB(23, 23, 23, 20),
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.13), borderRadius: BorderRadius.circular(17)),
                    child: const Icon(Icons.pause_rounded, color: AppColors.primaryDark, size: 26),
                  ),
                  const SizedBox(height: 13),
                  Text('Take a breath.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24)),
                  const SizedBox(height: 5),
                  Text('The arena can wait.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _isElite ? AppColors.darkMuted : AppColors.textMuted)),
                  const SizedBox(height: 18),
                  ActionButton(label: 'Resume battle', icon: Icons.play_arrow_rounded, expanded: true, onPressed: _togglePause),
                  const SizedBox(height: 8),
                  ActionButton(label: 'Return to Forge', icon: Icons.home_rounded, secondary: true, expanded: true, onPressed: _goHome),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final outcome = _outcome!;
    final reward = _campaignReward;
    final grade = reward?.grade ?? LevelGrade.none;
    final success = outcome.won;
    final level = widget.config.level;
    final scoreScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)), weight: 68),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1).chain(CurveTween(curve: Curves.easeOut)), weight: 32),
    ]).animate(_gradeController);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.48),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: SurfaceCard(
              color: _isElite ? AppColors.darkSurface : AppColors.surface,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              radius: 26,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(color: (success ? AppColors.secondary : AppColors.accent).withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                      child: Center(child: Text(success ? (_isElite ? '🐲' : '🏆') : '🛡️', style: const TextStyle(fontSize: 23))),
                    ),
                    const SizedBox(height: 10),
                    Text(success ? (_isElite ? 'Trial conquered' : 'Arena cleared') : 'The arena claims you', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      _isElite ? widget.config.chimera!.title : '${arenaMaps[level!.rank.index].shortName} · Level ${level.globalLevel}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    if (!_isElite) ...[
                      const SizedBox(height: 8),
                      ScaleTransition(
                        scale: scoreScale,
                        child: Text(grade.label, style: TextStyle(fontSize: 92, height: 1, fontWeight: FontWeight.w900, letterSpacing: -7, color: grade.color)),
                      ),
                      Text(grade.title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: grade.color, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                    ] else ...[
                      const SizedBox(height: 18),
                      Text(success ? 'VICTORY' : 'TRY AGAIN', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: success ? const Color(0xFFD7B474) : AppColors.darkMuted, letterSpacing: 2)),
                    ],
                    const SizedBox(height: 17),
                    if (!_isElite && reward != null) _buildScoreBreakdown(reward, outcome),
                    if (_isElite) _buildEliteResult(outcome),
                    const SizedBox(height: 15),
                    _buildRewardCounter(_isElite ? (_eliteReward ?? 30) : reward?.total ?? 30),
                    if (!_isElite && reward != null && reward.bonuses.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      ...reward.bonuses.entries.map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.add_circle_rounded, color: AppColors.secondary, size: 14),
                                const SizedBox(width: 7),
                                Expanded(child: Text(entry.key, style: Theme.of(context).textTheme.bodySmall)),
                                Text('+${entry.value}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.secondary)),
                              ],
                            ),
                          )),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: ActionButton(label: 'Retry', icon: Icons.refresh_rounded, secondary: true, compact: true, onPressed: _retry)),
                        const SizedBox(width: 7),
                        Expanded(child: ActionButton(label: 'Home', icon: Icons.home_rounded, compact: true, onPressed: _goHome)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _nextBattle,
                        icon: Icon(_isElite ? Icons.arrow_forward_rounded : Icons.map_rounded, size: 17),
                        label: Text(_isElite ? 'Next chimera' : 'Next map'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBreakdown(RewardBreakdown reward, BattleOutcome outcome) {
    return Column(
      children: [
        _ScoreRow(icon: Icons.timer_outlined, label: 'Time', value: _formatTime(outcome.durationSeconds), grade: reward.timeGrade),
        _ScoreRow(icon: Icons.favorite_border_rounded, label: 'Health left', value: '${(outcome.hpPercent * 100).round()}%', grade: reward.healthGrade),
        _ScoreRow(icon: Icons.shield_outlined, label: 'Damage taken', value: '${outcome.damageTaken}', grade: reward.damageGrade),
        _ScoreRow(icon: Icons.flag_outlined, label: 'Arena clear', value: 'All foes defeated', grade: outcome.won ? LevelGrade.ss : LevelGrade.none),
      ],
    );
  }

  Widget _buildEliteResult(BattleOutcome outcome) {
    return SurfaceCard(
      color: _isElite ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(outcome.won ? Icons.check_circle_rounded : Icons.history_rounded, color: outcome.won ? const Color(0xFF9DB37D) : AppColors.darkMuted, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(outcome.won ? 'A clean win earns an elite reward.' : 'Study its rhythm and return stronger.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.darkMuted))),
          Text('${outcome.durationSeconds}s', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.darkText)),
        ],
      ),
    );
  }

  Widget _buildRewardCounter(int total) {
    final color = _isElite ? const Color(0xFFD5B172) : AppColors.primaryDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _isElite ? AppColors.darkSurfaceAlt : const Color(0xFFF5EBD7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Text('🪙', style: TextStyle(fontSize: 19)),
          const SizedBox(width: 9),
          Expanded(child: Text('Coins earned', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: _isElite ? AppColors.darkText : AppColors.textPrimary))),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: total),
            duration: const Duration(milliseconds: 750),
            builder: (context, value, _) => Text('+$value', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontFeatures: const [])),
          ),
        ],
      ),
    );
  }

  void _attack() {
    if (_game.isPaused || _isResult) return;
    _game.requestAttack();
    HapticFeedback.selectionClick();
  }

  void _togglePause() {
    if (_isResult) return;
    setState(() => _game.setPaused(!_game.isPaused));
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.icon, required this.label, required this.value, required this.grade});

  final IconData icon;
  final String label;
  final String value;
  final LevelGrade grade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width: 8),
          Container(
            width: 28,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: grade.color.withOpacity(0.13), borderRadius: BorderRadius.circular(8)),
            child: Text(grade.label, style: TextStyle(color: grade.color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final elite = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        constraints: const BoxConstraints(minWidth: 49),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: elite ? AppColors.darkSurface.withOpacity(0.94) : AppColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: elite ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: elite ? AppColors.darkText : AppColors.textPrimary),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 7.5, letterSpacing: 0.5, color: elite ? AppColors.darkMuted : AppColors.textMuted, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _PowerPill extends StatelessWidget {
  const _PowerPill({required this.label, required this.icon, this.danger = false});

  final String label;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = danger ? const Color(0xFFB85545) : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(dark ? 0.17 : 0.1), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.35)),
        ],
      ),
    );
  }
}

class _AttackButton extends StatelessWidget {
  const _AttackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE7AA54).withOpacity(0.94),
          border: Border.all(color: const Color(0xFFFFE4B4), width: 3),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 18, offset: const Offset(0, 5))],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gps_fixed_rounded, color: Color(0xFF3D2C1E), size: 24),
            SizedBox(height: 3),
            Text('ATTACK', style: TextStyle(color: Color(0xFF3D2C1E), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({super.key, required this.onChanged});

  final ValueChanged<Offset> onChanged;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _value = Offset.zero;

  void _update(Offset localPosition) {
    const size = 158.0;
    final center = const Offset(size / 2, size / 2);
    final delta = localPosition - center;
    final normalized = delta.distance <= size * 0.34 ? delta : delta / delta.distance * (size * 0.34);
    setState(() => _value = normalized / (size * 0.34));
    widget.onChanged(_value);
  }

  void _release() {
    setState(() => _value = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _update(details.localPosition),
      onPanUpdate: (details) => _update(details.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox(
        width: 158,
        height: 158,
        child: CustomPaint(painter: _JoystickPainter(value: _value, dark: Theme.of(context).brightness == Brightness.dark)),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  const _JoystickPainter({required this.value, required this.dark});

  final Offset value;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(79, 79);
    canvas.drawCircle(center, 59, Paint()..color = (dark ? AppColors.darkSurface : AppColors.surface).withOpacity(0.72));
    canvas.drawCircle(center, 59, Paint()
      ..color = (dark ? AppColors.darkBorder : AppColors.border).withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    for (var i = 0; i < 4; i++) {
      final angle = i * 1.5708;
      final spot = center + Offset.fromDirection(angle, 41);
      canvas.drawCircle(spot, 2.5, Paint()..color = (dark ? AppColors.darkMuted : AppColors.textMuted).withOpacity(0.3));
    }
    final knob = center + value * 37;
    canvas.drawCircle(knob, 23, Paint()..color = const Color(0xFFD9973F).withOpacity(0.95));
    canvas.drawCircle(knob, 23, Paint()
      ..color = const Color(0xFFFFE4B4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawCircle(knob + const Offset(-6, -6), 3, Paint()..color = Colors.white.withOpacity(0.7));
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) => oldDelegate.value != value || oldDelegate.dark != dark;
}

String _formatTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}
