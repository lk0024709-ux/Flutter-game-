import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/game_models.dart';

class GameState extends ChangeNotifier {
  GameState._();

  static const String _saveKey = 'bosm_save_v1';

  late final SharedPreferences _preferences;
  Timer? _forgeTimer;
  int _coins = 650;
  int _highestClearedLevel = 0;
  int _campaignWins = 0;
  int _totalMerges = 0;
  int _forgeSpeedUps = 0;
  int _gradeSkipTokens = 0;
  int _weaponFragments = 0;
  int _eliteWins = 0;
  bool _rannslayerTitle = false;
  double _forgeElapsed = 0;
  int _lastForgeSaveMs = 0;
  int _manualForgeReadyAtMs = 0;
  int _lastDaggerSpawnAtMs = 0;
  String _lastDailyRewardDate = '';
  ArmorRank _equippedArmor = ArmorRank.normal;
  Booster? _activeBooster;
  final Set<ArmorRank> _ownedArmors = {ArmorRank.normal};
  final Map<Booster, int> _boosterCounts = {for (final booster in Booster.values) booster: 0};
  final Map<int, int> _bestGrades = {};
  final Map<int, int> _bestTimes = {};
  final Set<int> _clearedElite = {};
  final List<int?> _forgeSlots = List<int?>.filled(9, null);

  int get coins => _coins;
  int get highestClearedLevel => _highestClearedLevel;
  int get campaignWins => _campaignWins;
  int get totalMerges => _totalMerges;
  int get eliteWins => _eliteWins;
  int get gradeSkipTokens => _gradeSkipTokens;
  int get weaponFragments => _weaponFragments;
  bool get hasRannslayerTitle => _rannslayerTitle;
  ArmorRank get equippedArmor => _equippedArmor;
  Booster? get activeBooster => _activeBooster;
  List<int?> get forgeSlots => List.unmodifiable(_forgeSlots);
  int get ownedWeaponCount => _forgeSlots.whereType<int>().length;
  bool get isForgeFull => !_forgeSlots.contains(null);
  double get forgeInterval =>
      math.max(1.5, 5 - 0.3 * (_totalMerges ~/ 10) - 0.5 * _forgeSpeedUps).toDouble();
  double get forgeProgress => isForgeFull ? 0 : (_forgeElapsed / forgeInterval).clamp(0, 1).toDouble();
  int get manualForgeSecondsLeft => math.max(
        0,
        ((_manualForgeReadyAtMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil(),
      ).toInt();
  bool get showRecentDaggerSpawn => DateTime.now().millisecondsSinceEpoch - _lastDaggerSpawnAtMs < 1200;

  WeaponTier get activeWeapon {
    var highest = 0;
    for (final tier in _forgeSlots) {
      if (tier != null && tier > highest) highest = tier;
    }
    return highest == 0 ? WeaponTier.sword : WeaponTierData.fromLevel(highest);
  }

  int boosterCount(Booster booster) => _boosterCounts[booster] ?? 0;
  bool ownsArmor(ArmorRank armor) => _ownedArmors.contains(armor);
  int? bestGradeScore(int globalLevel) => _bestGrades[globalLevel];
  int? bestTime(int globalLevel) => _bestTimes[globalLevel];
  bool hasClearedLevel(int globalLevel) => (_bestGrades[globalLevel] ?? 0) > 0;
  bool hasClearedElite(int index) => _clearedElite.contains(index);

  static Future<GameState> load() async {
    final state = GameState._();
    state._preferences = await SharedPreferences.getInstance();
    state._restore();
    state._simulateOfflineForge();
    state._startForgeTicker();
    return state;
  }

  void _restore() {
    final raw = _preferences.getString(_saveKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _coins = (data['coins'] as num?)?.toInt() ?? _coins;
        _highestClearedLevel = (data['highestClearedLevel'] as num?)?.toInt() ?? 0;
        _campaignWins = (data['campaignWins'] as num?)?.toInt() ?? 0;
        _totalMerges = (data['totalMerges'] as num?)?.toInt() ?? 0;
        _forgeSpeedUps = (data['forgeSpeedUps'] as num?)?.toInt() ?? 0;
        _gradeSkipTokens = (data['gradeSkipTokens'] as num?)?.toInt() ?? 0;
        _weaponFragments = (data['weaponFragments'] as num?)?.toInt() ?? 0;
        _eliteWins = (data['eliteWins'] as num?)?.toInt() ?? 0;
        _rannslayerTitle = data['rannslayerTitle'] == true;
        _manualForgeReadyAtMs = (data['manualForgeReadyAtMs'] as num?)?.toInt() ?? 0;
        _lastForgeSaveMs = (data['lastForgeSaveMs'] as num?)?.toInt() ?? 0;
        _forgeElapsed = (data['forgeElapsed'] as num?)?.toDouble() ?? 0;
        _lastDailyRewardDate = data['lastDailyRewardDate'] as String? ?? '';

        final equippedIndex = (data['equippedArmor'] as num?)?.toInt() ?? 0;
        _equippedArmor = ArmorRank.values[equippedIndex.clamp(0, ArmorRank.values.length - 1) as int];

        _ownedArmors
          ..clear()
          ..add(ArmorRank.normal);
        final ownedValues = data['ownedArmors'] as List<dynamic>? ?? const [];
        for (final value in ownedValues) {
          if (value is num && value.toInt() >= 0 && value.toInt() < ArmorRank.values.length) {
            _ownedArmors.add(ArmorRank.values[value.toInt()]);
          }
        }
        if (!_ownedArmors.contains(_equippedArmor)) _equippedArmor = ArmorRank.normal;

        final boosterValues = data['boosters'] as Map<String, dynamic>? ?? const {};
        for (final booster in Booster.values) {
          _boosterCounts[booster] = (boosterValues[booster.name] as num?)?.toInt() ?? 0;
        }
        final activeName = data['activeBooster'] as String?;
        final matchingBoosters = Booster.values.where((item) => item.name == activeName);
        _activeBooster = matchingBoosters.isEmpty ? null : matchingBoosters.first;
        if (_activeBooster != null && boosterCount(_activeBooster!) == 0) _activeBooster = null;

        final slots = data['forgeSlots'] as List<dynamic>?;
        if (slots != null && slots.length == _forgeSlots.length) {
          for (var i = 0; i < slots.length; i++) {
            final value = slots[i];
            _forgeSlots[i] = value is num && value.toInt() >= 1 && value.toInt() <= WeaponTier.values.length
                ? value.toInt()
                : null;
          }
        }
        final grades = data['bestGrades'] as Map<String, dynamic>? ?? const {};
        _bestGrades
          ..clear()
          ..addAll(grades.map((key, value) => MapEntry(int.tryParse(key) ?? -1, (value as num).toInt())));
        _bestGrades.remove(-1);
        final times = data['bestTimes'] as Map<String, dynamic>? ?? const {};
        _bestTimes
          ..clear()
          ..addAll(times.map((key, value) => MapEntry(int.tryParse(key) ?? -1, (value as num).toInt())));
        _bestTimes.remove(-1);
        final elites = data['clearedElite'] as List<dynamic>? ?? const [];
        _clearedElite
          ..clear()
          ..addAll(elites.whereType<num>().map((value) => value.toInt()));
      } on Object {
        // A damaged save should not prevent a fresh game from starting.
        _resetToDefaults();
      }
    } else {
      _resetToDefaults();
    }
  }

  void _resetToDefaults() {
    _coins = 650;
    const defaults = <int?>[2, 1, 1, null, null, null, null, null, null];
    for (var i = 0; i < _forgeSlots.length; i++) {
      _forgeSlots[i] = defaults[i];
    }
    _ownedArmors
      ..clear()
      ..add(ArmorRank.normal);
    _equippedArmor = ArmorRank.normal;
    _activeBooster = null;
    for (final booster in Booster.values) {
      _boosterCounts[booster] = 0;
    }
    _campaignWins = 0;
    _highestClearedLevel = 0;
    _totalMerges = 0;
    _forgeSpeedUps = 0;
    _gradeSkipTokens = 0;
    _weaponFragments = 0;
    _eliteWins = 0;
    _rannslayerTitle = false;
    _manualForgeReadyAtMs = 0;
    _lastDailyRewardDate = '';
    _bestGrades.clear();
    _bestTimes.clear();
    _clearedElite.clear();
    _forgeElapsed = 0;
    _lastForgeSaveMs = DateTime.now().millisecondsSinceEpoch;
  }

  void _simulateOfflineForge() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastForgeSaveMs <= 0) {
      _lastForgeSaveMs = now;
      _forgeElapsed = 0;
      return;
    }
    var elapsed = _forgeElapsed + math.max(0, (now - _lastForgeSaveMs) / 1000);
    var spawnCount = 0;
    while (elapsed >= forgeInterval && !isForgeFull && spawnCount < 9) {
      final index = _forgeSlots.indexOf(null);
      if (index < 0) break;
      _forgeSlots[index] = 1;
      _lastDaggerSpawnAtMs = now;
      elapsed -= forgeInterval;
      spawnCount++;
    }
    _forgeElapsed = isForgeFull ? 0 : math.min(elapsed, forgeInterval).toDouble();
    _lastForgeSaveMs = now;
  }

  void _startForgeTicker() {
    _forgeTimer?.cancel();
    _forgeTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!isForgeFull) {
        _forgeElapsed += 0.25;
        if (_forgeElapsed >= forgeInterval) {
          _forgeElapsed -= forgeInterval;
          final emptyIndex = _forgeSlots.indexOf(null);
          if (emptyIndex >= 0) {
            _forgeSlots[emptyIndex] = 1;
            _lastDaggerSpawnAtMs = DateTime.now().millisecondsSinceEpoch;
            _lastForgeSaveMs = DateTime.now().millisecondsSinceEpoch;
            _save();
          }
        }
      } else {
        _forgeElapsed = 0;
      }
      notifyListeners();
      if (DateTime.now().second % 15 == 0 && DateTime.now().millisecond < 300) {
        _save();
      }
    });
  }

  bool isRankUnlocked(Rank rank) => _campaignWins >= rank.unlockWins;

  bool isLevelUnlocked(GameLevel level) {
    if (!isRankUnlocked(level.rank)) return false;
    return level.globalLevel <= _highestClearedLevel + 3 || level.globalLevel <= 3;
  }

  bool get eliteModeUnlocked => _highestClearedLevel >= 50;

  bool isEliteUnlocked(int index) {
    if (!eliteModeUnlocked) return false;
    if (index == 0) return true;
    return _clearedElite.contains(index - 1);
  }

  bool buyArmor(ArmorRank armor) {
    if (ownsArmor(armor) || _coins < armor.price) return false;
    _coins -= armor.price;
    _ownedArmors.add(armor);
    _saveAndNotify();
    return true;
  }

  bool equipArmor(ArmorRank armor) {
    if (!ownsArmor(armor)) return false;
    _equippedArmor = armor;
    _saveAndNotify();
    return true;
  }

  bool buyBooster(Booster booster) {
    if (_coins < booster.price) return false;
    _coins -= booster.price;
    _boosterCounts[booster] = boosterCount(booster) + 1;
    _activeBooster ??= booster;
    _saveAndNotify();
    return true;
  }

  void selectBooster(Booster? booster) {
    if (booster != null && boosterCount(booster) <= 0) return;
    _activeBooster = booster;
    _saveAndNotify();
  }

  Booster? consumeBoosterForBattle({required bool elite}) {
    if (elite) return null;
    final booster = _activeBooster;
    if (booster == null || boosterCount(booster) <= 0) return null;
    _boosterCounts[booster] = boosterCount(booster) - 1;
    _activeBooster = null;
    _saveAndNotify();
    return booster;
  }

  bool mergeWeapons(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= _forgeSlots.length || toIndex < 0 || toIndex >= _forgeSlots.length || fromIndex == toIndex) {
      return false;
    }
    final source = _forgeSlots[fromIndex];
    final target = _forgeSlots[toIndex];
    if (source == null) return false;
    if (target == null) {
      _forgeSlots[toIndex] = source;
      _forgeSlots[fromIndex] = null;
    } else if (source == target) {
      if (source >= WeaponTier.values.length) return false;
      _forgeSlots[toIndex] = source + 1;
      _forgeSlots[fromIndex] = null;
      _totalMerges++;
      _coins += 5;
    } else {
      _forgeSlots[fromIndex] = target;
      _forgeSlots[toIndex] = source;
    }
    _saveAndNotify();
    return true;
  }

  bool forgeNow() {
    if (manualForgeSecondsLeft > 0 || isForgeFull) return false;
    final index = _forgeSlots.indexOf(null);
    if (index < 0) return false;
    _forgeSlots[index] = 1;
    _lastDaggerSpawnAtMs = DateTime.now().millisecondsSinceEpoch;
    _manualForgeReadyAtMs = DateTime.now().add(const Duration(seconds: 10)).millisecondsSinceEpoch;
    _saveAndNotify();
    return true;
  }

  bool buyForgeSpeedUp() {
    if (_coins < 200 || forgeInterval <= 1.5) return false;
    _coins -= 200;
    _forgeSpeedUps++;
    _saveAndNotify();
    return true;
  }

  bool buyWeaponFragment() {
    if (_coins < 500 || isForgeFull) return false;
    _coins -= 500;
    _weaponFragments++;
    final emptyIndex = _forgeSlots.indexOf(null);
    if (emptyIndex >= 0) {
      _forgeSlots[emptyIndex] = 1;
      _lastDaggerSpawnAtMs = DateTime.now().millisecondsSinceEpoch;
    }
    _saveAndNotify();
    return true;
  }

  bool buyGradeSkipToken() {
    if (_coins < 3000) return false;
    _coins -= 3000;
    _gradeSkipTokens++;
    _saveAndNotify();
    return true;
  }

  bool useGradeSkip(GameLevel level) {
    if (_gradeSkipTokens <= 0 || hasClearedLevel(level.globalLevel) || !isRankUnlocked(level.rank) || level.globalLevel > _highestClearedLevel + 4) return false;
    _gradeSkipTokens--;
    _bestGrades[level.globalLevel] = LevelGrade.d.score;
    _highestClearedLevel = math.max(_highestClearedLevel, level.globalLevel).toInt();
    _saveAndNotify();
    return true;
  }

  RewardBreakdown recordCampaignResult(GameLevel level, BattleOutcome outcome) {
    final seconds = outcome.durationSeconds;
    final timeGrade = gradeForTime(seconds);
    final healthGrade = gradeForHealth(outcome.hpPercent);
    final damageGrade = gradeForDamage(outcome.damageTaken);
    final grade = finalGradeFor(
      seconds: seconds,
      hpPercent: outcome.hpPercent,
      damageTaken: outcome.damageTaken,
    );
    final previousScore = _bestGrades[level.globalLevel] ?? 0;
    final firstClear = previousScore == 0;
    final newBest = grade.score > previousScore;
    final baseCoins = (40 + level.levelInRank * 8).round();
    final rankMultiplier = level.rank.rewardRankMultiplier;
    final titleMultiplier = (_rannslayerTitle || (outcome.won && level.globalLevel == 350)) ? 1.5 : 1.0;
    final formulaMultiplier = grade.rewardMultiplier * rankMultiplier * (firstClear ? 1.5 : 1);
    final baseReward = (baseCoins * formulaMultiplier).round();
    final bonuses = <String, int>{};
    if (firstClear) bonuses['First clear'] = 300;
    if (newBest) bonuses['New personal best'] = 200;
    if (outcome.damageTaken == 0) bonuses['Untouched'] = 100;
    if (seconds < 60) bonuses['Under 60 seconds'] = 75;
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month}-${today.day}';
    if (outcome.won && _lastDailyRewardDate != dateKey) {
      bonuses['Daily first win'] = 100;
      _lastDailyRewardDate = dateKey;
    }
    if (!outcome.won) {
      bonuses
        ..clear()
        ..['Battle loss'] = 30;
    }
    if (level.isRankBoss && outcome.won) {
      const bossRewards = [2000, 4000, 7000, 11000, 16000, 22000, 50000];
      bonuses['Rank champion'] = bossRewards[level.rank.index];
    }
    final multiplier = formulaMultiplier * titleMultiplier;
    final rawTotal = baseReward + bonuses.values.fold<int>(0, (sum, value) => sum + value);
    final earned = outcome.won ? (rawTotal * titleMultiplier).round() : 30;
    _coins += earned;
    if (outcome.won) {
      _campaignWins++;
      _highestClearedLevel = math.max(_highestClearedLevel, level.globalLevel).toInt();
      if (newBest) _bestGrades[level.globalLevel] = grade.score;
      final oldTime = _bestTimes[level.globalLevel];
      if (oldTime == null || seconds < oldTime) _bestTimes[level.globalLevel] = seconds;
      if (level.globalLevel == 350) _rannslayerTitle = true;
    }
    _saveAndNotify();
    return RewardBreakdown(
      grade: outcome.won ? grade : LevelGrade.none,
      baseCoins: outcome.won ? baseReward : 30,
      multiplier: multiplier,
      firstClear: firstClear,
      bonuses: bonuses,
      total: earned,
      timeGrade: timeGrade,
      healthGrade: healthGrade,
      damageGrade: damageGrade,
    );
  }

  int recordEliteResult(ChimeraType chimera, BattleOutcome outcome) {
    if (!outcome.won) {
      _coins += 30;
      _saveAndNotify();
      return 30;
    }
    final index = chimera.index;
    final firstClear = !_clearedElite.contains(index);
    final rawReward = 450 + 250 * (index + 1) + (firstClear ? 300 : 0);
    final reward = (rawReward * (_rannslayerTitle ? 1.5 : 1)).round();
    _coins += reward;
    _clearedElite.add(index);
    _eliteWins = _clearedElite.length;
    _saveAndNotify();
    return reward;
  }

  void _saveAndNotify() {
    _lastForgeSaveMs = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    _lastForgeSaveMs = DateTime.now().millisecondsSinceEpoch;
    final data = <String, Object?>{
      'coins': _coins,
      'highestClearedLevel': _highestClearedLevel,
      'campaignWins': _campaignWins,
      'totalMerges': _totalMerges,
      'forgeSpeedUps': _forgeSpeedUps,
      'gradeSkipTokens': _gradeSkipTokens,
      'weaponFragments': _weaponFragments,
      'eliteWins': _eliteWins,
      'rannslayerTitle': _rannslayerTitle,
      'equippedArmor': _equippedArmor.index,
      'ownedArmors': _ownedArmors.map((armor) => armor.index).toList(),
      'boosters': {for (final booster in Booster.values) booster.name: boosterCount(booster)},
      'activeBooster': _activeBooster?.name,
      'forgeSlots': _forgeSlots,
      'bestGrades': _bestGrades.map((key, value) => MapEntry(key.toString(), value)),
      'bestTimes': _bestTimes.map((key, value) => MapEntry(key.toString(), value)),
      'clearedElite': _clearedElite.toList(),
      'lastForgeSaveMs': _lastForgeSaveMs,
      'forgeElapsed': _forgeElapsed,
      'manualForgeReadyAtMs': _manualForgeReadyAtMs,
      'lastDailyRewardDate': _lastDailyRewardDate,
    };
    try {
      await _preferences.setString(_saveKey, jsonEncode(data));
    } on Object {
      // Persistence is best-effort; the current session remains playable.
    }
  }

  @override
  void dispose() {
    _forgeTimer?.cancel();
    _save();
    super.dispose();
  }
}
