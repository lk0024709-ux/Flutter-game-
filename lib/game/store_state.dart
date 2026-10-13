import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'armor.dart';
import 'battle_result.dart';
import 'elite/chimera.dart';
import 'forge_state.dart';
import 'level_grade.dart';
import 'levels/boss_levels.dart';
import 'levels/game_level.dart';
import 'levels/levels_data.dart';
import 'loot/chimera_armor.dart';
import 'loot/chest_rarity.dart';
import 'loot/elite_power.dart';
import 'loot/loot_item.dart';
import 'loot/xp_system.dart';
import 'rank.dart';
import 'weapon.dart';

/// Consumable boosters. Only one can be queued for a battle at a time.
enum BoosterKind {
  revivePotion(
    'Revive Potion',
    '❤️',
    200,
    '+1 automatic revive charge in your next battle.',
  ),
  damageElixir(
    'Damage Elixir',
    '⚔️',
    150,
    '+25% sword damage for one battle.',
  ),
  chestMagnet(
    'Chest Magnet',
    '🧲',
    100,
    'Double coin chest spawns for one battle.',
  ),
  ironSkin(
    'Iron Skin',
    '🛡️',
    180,
    '+20% defense for one battle.',
  );

  const BoosterKind(this.label, this.icon, this.price, this.description);

  final String label;
  final String icon;
  final int price;
  final String description;

  static BoosterKind? byName(String? name) {
    for (final BoosterKind kind in BoosterKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return null;
  }
}

/// Result of applying a battle to the save file - drives the reward popups.
class ProgressionEvent {
  const ProgressionEvent({
    this.levelUps = const <LevelUpInfo>[],
    this.rankUnlocked,
    this.titleUnlocked,
    this.bossDefeated,
    this.permanentMultiplierUnlocked = 0,
    this.firstClear = false,
  });

  final List<LevelUpInfo> levelUps;
  final Rank? rankUnlocked;
  final String? titleUnlocked;
  final Rank? bossDefeated;

  /// 1.5 for the final boss, 0 when nothing was unlocked.
  final double permanentMultiplierUnlocked;
  final bool firstClear;

  bool get isEmpty =>
      levelUps.isEmpty &&
      rankUnlocked == null &&
      titleUnlocked == null &&
      bossDefeated == null &&
      permanentMultiplierUnlocked == 0;
}

/// The single source of truth for everything the player owns and has achieved.
///
/// Persisted to `shared_preferences` as one JSON blob with a 500ms debounce.
class StoreState extends ChangeNotifier {
  StoreState._();

  static final StoreState instance = StoreState._();

  static const String _storageKey = 'blade_brawl_save_v2';

  /// Coin sinks (see the design table).
  static const int forgeSpeedUpPrice = 200;
  static const int weaponFragmentPrice = 500;
  static const int gradeSkipTokenPrice = 3000;

  /// Rank bosses unlock from Bronze L50 onwards.
  static const int bronzeCompletionLevel = 50;

  // ------------------------------------------------------------------ wallet
  int _coins = 0;
  int _lifetimeCoins = 0;

  int get coins => _coins;
  int get lifetimeCoins => _lifetimeCoins;

  // -------------------------------------------------------------------- xp
  int _playerXp = 0;
  int _playerLevel = 1;

  int get playerXp => _playerXp;
  int get playerLevel => _playerLevel;
  double get playerLevelProgress => XpSystem.progressFor(_playerXp);
  int get xpIntoLevel => XpSystem.xpIntoLevel(_playerXp);
  int get xpForLevel => XpSystem.xpForCurrentLevel(_playerXp);
  bool get isMaxLevel => _playerLevel >= XpSystem.maxLevel;

  // ----------------------------------------------------------------- armour
  final Set<ArmorRank> _ownedArmors = <ArmorRank>{ArmorRank.normal};
  ArmorRank _equippedArmor = ArmorRank.normal;

  Set<ArmorRank> get ownedArmors => Set<ArmorRank>.unmodifiable(_ownedArmors);
  ArmorRank get equippedArmor => _equippedArmor;
  bool ownsArmor(ArmorRank rank) => _ownedArmors.contains(rank);

  // ---------------------------------------------------------------- boosters
  final Map<BoosterKind, int> _boosters = <BoosterKind, int>{};
  BoosterKind? _activeBooster;

  Map<BoosterKind, int> get boosterInventory => Map<BoosterKind, int>.unmodifiable(_boosters);
  BoosterKind? get activeBooster => _activeBooster;

  int boosterCount(BoosterKind kind) => _boosters[kind] ?? 0;

  // ------------------------------------------------------------------ grades
  final Map<int, LevelGrade> _bestGrades = <int, LevelGrade>{};

  Map<int, LevelGrade> get bestGrades => Map<int, LevelGrade>.unmodifiable(_bestGrades);

  LevelGrade gradeFor(int levelNumber) => _bestGrades[levelNumber] ?? LevelGrade.none;

  bool isLevelCleared(int levelNumber) => gradeFor(levelNumber).isCleared;

  int get clearedLevelCount => _bestGrades.length;

  // ------------------------------------------------------------------ elites
  final Map<ChimeraType, LevelGrade> _chimeraGrades = <ChimeraType, LevelGrade>{};
  final Set<ChimeraType> _chimerasDefeated = <ChimeraType>{};
  final Map<ChimeraType, int> _eliteAttempts = <ChimeraType, int>{};
  final Set<ChimeraArmorKind> _ownedEliteArmors = <ChimeraArmorKind>{};
  ChimeraArmorKind? _equippedEliteArmor;
  final Set<ElitePowerKind> _unlockedPowers = <ElitePowerKind>{};
  bool _assistMode = false;
  int _eliteChestsOpened = 0;

  Map<ChimeraType, LevelGrade> get chimeraGrades =>
      Map<ChimeraType, LevelGrade>.unmodifiable(_chimeraGrades);
  Set<ChimeraType> get chimerasDefeated => Set<ChimeraType>.unmodifiable(_chimerasDefeated);
  Set<ChimeraArmorKind> get ownedEliteArmors =>
      Set<ChimeraArmorKind>.unmodifiable(_ownedEliteArmors);
  ChimeraArmorKind? get equippedEliteArmor => _equippedEliteArmor;
  Set<ElitePowerKind> get unlockedPowers => Set<ElitePowerKind>.unmodifiable(_unlockedPowers);
  bool get assistMode => _assistMode;
  int get eliteChestsOpened => _eliteChestsOpened;

  LevelGrade chimeraGrade(ChimeraType type) => _chimeraGrades[type] ?? LevelGrade.none;
  bool isChimeraDefeated(ChimeraType type) => _chimerasDefeated.contains(type);
  int eliteAttempts(ChimeraType type) => _eliteAttempts[type] ?? 0;

  /// Assist mode unlocks after five failed attempts on the same chimera.
  bool assistAvailable(ChimeraType type) => eliteAttempts(type) >= 5;

  // ------------------------------------------------------------------ titles
  final Set<String> _ownedTitles = <String>{'Novice'};
  String _equippedTitle = 'Novice';
  final Set<String> _ownedCosmetics = <String>{};

  Set<String> get ownedTitles => Set<String>.unmodifiable(_ownedTitles);
  String get equippedTitle => _equippedTitle;
  Set<String> get ownedCosmetics => Set<String>.unmodifiable(_ownedCosmetics);

  // ------------------------------------------------------------------- stats
  int _totalWins = 0;
  int _totalBattles = 0;
  int _totalKills = 0;
  final Set<Rank> _bossDefeated = <Rank>{};
  int _weaponFragments = 0;
  int _gradeSkipTokens = 0;
  String? _lastDailyWin;
  double _permanentCoinMultiplier = 1.0;
  bool _loaded = false;
  bool _dirty = false;
  Timer? _saveTimer;

  int get totalWins => _totalWins;
  int get totalBattles => _totalBattles;
  int get totalKills => _totalKills;
  Set<Rank> get bossesDefeated => Set<Rank>.unmodifiable(_bossDefeated);
  int get weaponFragments => _weaponFragments;
  int get gradeSkipTokens => _gradeSkipTokens;
  double get permanentCoinMultiplier => _permanentCoinMultiplier;
  bool get isLoaded => _loaded;

  /// Title / power driven bonus applied to every coin the player earns.
  double get coinBonusMultiplier {
    double multiplier = _permanentCoinMultiplier;
    if (_unlockedPowers.contains(ElitePowerKind.treasureHunter)) {
      multiplier *= 1.2;
    }
    return multiplier;
  }

  bool bossDefeated(Rank rank) => _bossDefeated.contains(rank);

  /// Elite mode opens once the Bronze boss is dead.
  bool get eliteUnlocked => _bossDefeated.contains(Rank.bronze) || _totalWins >= 12;

  // ------------------------------------------------------------------- ranks
  bool rankUnlocked(Rank rank) {
    if (rank == Rank.bronze) {
      return true;
    }
    if (_bossDefeated.contains(Rank.values[rank.index - 1])) {
      return true;
    }
    return _totalWins >= rank.unlockWins;
  }

  /// Highest cleared level inside a rank (0 = nothing cleared yet).
  int highestClearedInRank(Rank rank) {
    int highest = 0;
    for (int i = rank.firstLevel; i <= rank.lastLevel; i++) {
      if (isLevelCleared(i)) {
        highest = math.max(highest, i - rank.firstLevel + 1);
      }
    }
    return highest;
  }

  /// Levels unlock one at a time, with the next three always visible.
  bool isLevelUnlocked(int levelNumber) {
    final GameLevel level = LevelsData.byNumber(levelNumber);
    if (!rankUnlocked(level.rank)) {
      return false;
    }
    if (levelNumber == level.rank.firstLevel) {
      return true;
    }
    final int highest = highestClearedInRank(level.rank);
    return level.levelInRank <= highest + 3;
  }

  /// The next level the player should attack.
  int get nextLevelNumber {
    for (int i = 1; i <= Rank.totalLevels; i++) {
      if (!isLevelCleared(i)) {
        return i;
      }
    }
    return Rank.totalLevels;
  }

  // ------------------------------------------------------------------ wallet
  void addCoins(int amount) {
    if (amount <= 0) {
      return;
    }
    _coins += amount;
    _lifetimeCoins += amount;
    _markDirty();
    notifyListeners();
  }

  bool spend(int amount) {
    if (amount <= 0 || _coins < amount) {
      return false;
    }
    _coins -= amount;
    _markDirty();
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------ armour
  bool buyArmor(ArmorRank rank) {
    if (_ownedArmors.contains(rank)) {
      return false;
    }
    if (!spend(rank.price)) {
      return false;
    }
    _ownedArmors.add(rank);
    _equippedArmor = rank;
    _markDirty();
    notifyListeners();
    return true;
  }

  void equipArmor(ArmorRank rank) {
    if (!_ownedArmors.contains(rank) || _equippedArmor == rank) {
      return;
    }
    _equippedArmor = rank;
    _markDirty();
    notifyListeners();
  }

  // ---------------------------------------------------------------- boosters
  bool buyBooster(BoosterKind kind) {
    if (!spend(kind.price)) {
      return false;
    }
    _boosters[kind] = boosterCount(kind) + 1;
    _activeBooster ??= kind;
    _markDirty();
    notifyListeners();
    return true;
  }

  void addBooster(BoosterKind kind, {int count = 1}) {
    _boosters[kind] = boosterCount(kind) + count;
    _markDirty();
    notifyListeners();
  }

  /// Queues a booster for the next battle (only one at a time).
  void activateBooster(BoosterKind? kind) {
    if (kind != null && boosterCount(kind) <= 0) {
      return;
    }
    _activeBooster = kind;
    _markDirty();
    notifyListeners();
  }

  /// Consumes the queued booster once the battle is over.
  void consumeActiveBooster() {
    final BoosterKind? kind = _activeBooster;
    if (kind == null) {
      return;
    }
    _activeBooster = null;
    final int count = boosterCount(kind);
    if (count <= 1) {
      _boosters.remove(kind);
    } else {
      _boosters[kind] = count - 1;
    }
    _markDirty();
    notifyListeners();
  }

  // ------------------------------------------------------------- coin sinks
  /// Forge speed-up: instantly forges one dagger (forge must have space).
  bool buyForgeSpeedUp() {
    if (ForgeState.instance.isFull) {
      return false;
    }
    if (!spend(forgeSpeedUpPrice)) {
      return false;
    }
    ForgeState.instance.rushForge();
    notifyListeners();
    return true;
  }

  /// Weapon fragment: forges a copy of the best blade you own.
  bool buyWeaponFragment() {
    if (ForgeState.instance.isFull) {
      return false;
    }
    if (!spend(weaponFragmentPrice)) {
      return false;
    }
    _weaponFragments++;
    final WeaponTier tier = ForgeState.instance.bestTier;
    ForgeState.instance.injectWeapon(tier);
    _markDirty();
    notifyListeners();
    return true;
  }

  void addWeaponFragments(int amount) {
    _weaponFragments = math.max<int>(0, _weaponFragments + amount);
    _markDirty();
    notifyListeners();
  }

  /// Grade skip token: clears the next locked level with a C grade.
  bool buyGradeSkipToken() {
    if (!spend(gradeSkipTokenPrice)) {
      return false;
    }
    _gradeSkipTokens++;
    final int target = nextLevelNumber;
    final LevelGrade previous = gradeFor(target);
    if (!previous.isCleared) {
      _bestGrades[target] = LevelGrade.c;
    }
    _markDirty();
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------------ titles
  void unlockTitle(String title) {
    if (title.trim().isEmpty || !_ownedTitles.add(title)) {
      return;
    }
    _markDirty();
    notifyListeners();
  }

  void equipTitle(String title) {
    if (!_ownedTitles.contains(title)) {
      return;
    }
    _equippedTitle = title;
    _markDirty();
    notifyListeners();
  }

  void addCosmetic(String name) {
    if (_ownedCosmetics.add(name)) {
      _markDirty();
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------- xp
  List<LevelUpInfo> addXp(int amount) {
    if (amount <= 0) {
      return const <LevelUpInfo>[];
    }
    _playerXp += amount;
    final int newLevel = XpSystem.levelForXp(_playerXp);
    final List<LevelUpInfo> rewards = <LevelUpInfo>[];
    if (newLevel > _playerLevel) {
      rewards.addAll(XpSystem.levelUpsBetween(_playerLevel, newLevel));
      _playerLevel = newLevel;
      for (final LevelUpInfo info in rewards) {
        _coins += info.coinReward;
        _lifetimeCoins += info.coinReward;
        _weaponFragments += info.fragmentReward;
        if (info.booster != null) {
          final BoosterKind booster = info.booster!;
          _boosters[booster] = boosterCount(booster) + 1;
        }
        if (info.cosmetic != null) {
          _ownedCosmetics.add(info.cosmetic!);
        }
        if (info.title != null) {
          _ownedTitles.add(info.title!);
        }
      }
    }
    _markDirty();
    notifyListeners();
    return rewards;
  }

  // ----------------------------------------------------------- daily bonus
  bool markDailyWin() {
    final DateTime now = DateTime.now();
    final String key = '${now.year}-${now.month}-${now.day}';
    if (_lastDailyWin == key) {
      return false;
    }
    _lastDailyWin = key;
    _markDirty();
    return true;
  }

  // --------------------------------------------------------------- results
  /// Applies a finished campaign battle. Returns the progression event.
  ProgressionEvent recordCampaignResult(BattleResult result) {
    _totalBattles++;
    addCoins(result.rewardLines.fold<int>(0, (int sum, RewardLine line) => sum + line.coins));
    final List<LevelUpInfo> levelUps = addXp(result.xpReward);
    _totalKills += result.kills;

    if (!result.win) {
      _markDirty();
      notifyListeners();
      return ProgressionEvent(levelUps: levelUps);
    }

    _totalWins++;
    final int number = result.levelNumber;
    final LevelGrade previous = gradeFor(number);
    final bool firstClear = !previous.isCleared;
    if (firstClear || result.grade.betterThan(previous)) {
      _bestGrades[number] = firstClear ? result.grade : LevelGrade.best(previous, result.grade);
    }

    Rank? rankUnlocked;
    String? titleUnlocked;
    double multiplierUnlocked = 0;
    Rank? bossBeaten;

    final BossLevelDef? boss = BossLevels.forLevel(number);
    if (boss != null && !_bossDefeated.contains(boss.rank)) {
      _bossDefeated.add(boss.rank);
      bossBeaten = boss.rank;
      titleUnlocked = '${boss.name} Slayer';
      unlockTitle(titleUnlocked);
      if (boss.unlocksRank != null) {
        rankUnlocked = boss.unlocksRank;
      }
      if (boss.titleReward != null) {
        unlockTitle(boss.titleReward!);
        titleUnlocked = boss.titleReward;
      }
      if (boss.permanentCoinMultiplier > 1) {
        multiplierUnlocked = boss.permanentCoinMultiplier;
        _permanentCoinMultiplier = math.max(_permanentCoinMultiplier, boss.permanentCoinMultiplier);
      }
    }

    _markDirty();
    notifyListeners();
    return ProgressionEvent(
      levelUps: levelUps,
      rankUnlocked: rankUnlocked,
      titleUnlocked: titleUnlocked,
      bossDefeated: bossBeaten,
      permanentMultiplierUnlocked: multiplierUnlocked,
      firstClear: firstClear,
    );
  }

  /// Applies a finished elite trial plus its chest loot.
  ProgressionEvent recordEliteResult({
    required ChimeraType chimera,
    required BattleResult result,
    required List<LootItem> loot,
    required bool assistModeUsed,
  }) {
    _totalBattles++;
    _totalKills += result.kills;
    addCoins(result.rewardLines.fold<int>(0, (int sum, RewardLine line) => sum + line.coins));

    int lootXp = 0;
    for (final LootItem item in loot) {
      switch (item.kind) {
        case LootItemKind.coins:
          addCoins(item.amount);
          break;
        case LootItemKind.xp:
          lootXp += item.amount;
          break;
        case LootItemKind.power:
          if (item.power != null) {
            _unlockedPowers.add(item.power!);
          }
          break;
        case LootItemKind.epicArmor:
          if (item.eliteArmor != null) {
            _ownedEliteArmors.add(item.eliteArmor!);
            _equippedEliteArmor ??= item.eliteArmor;
          }
          break;
        case LootItemKind.title:
          if (item.title != null) {
            unlockTitle(item.title!);
          }
          break;
        case LootItemKind.weaponFrag:
          _weaponFragments += item.amount;
          break;
        case LootItemKind.booster:
          final BoosterKind? booster = BoosterKind.byName(item.boosterName);
          if (booster != null) {
            _boosters[booster] = boosterCount(booster) + 1;
          }
          break;
        case LootItemKind.cosmetic:
          _ownedCosmetics.add(item.label);
          break;
      }
    }

    final List<LevelUpInfo> levelUps = addXp(result.xpReward + lootXp);

    if (result.win) {
      _totalWins++;
      _chimerasDefeated.add(chimera);
      final LevelGrade previous = chimeraGrade(chimera);
      if (result.grade.betterThan(previous) || !previous.isCleared) {
        _chimeraGrades[chimera] = result.grade;
      }
      _eliteChestsOpened++;
      if (assistModeUsed) {
        _assistMode = false;
      }
    } else {
      _eliteAttempts[chimera] = eliteAttempts(chimera) + 1;
    }

    _markDirty();
    notifyListeners();
    return ProgressionEvent(levelUps: levelUps, firstClear: result.firstClear);
  }

  void setAssistMode(bool value) {
    _assistMode = value;
    _markDirty();
    notifyListeners();
  }

  void equipEliteArmor(ChimeraArmorKind? armor) {
    if (armor != null && !_ownedEliteArmors.contains(armor)) {
      return;
    }
    _equippedEliteArmor = armor;
    _markDirty();
    notifyListeners();
  }

  // ------------------------------------------------------------ persistence
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _fromJson(decoded);
        }
      } catch (error) {
        debugPrint('StoreState: could not decode save ($error)');
      }
    }
    _playerLevel = XpSystem.levelForXp(_playerXp);
    _loaded = true;
    notifyListeners();
  }

  void _fromJson(Map<String, dynamic> json) {
    _coins = _int(json['coins'], 0);
    _lifetimeCoins = _int(json['lifetimeCoins'], _coins);
    _playerXp = _int(json['playerXp'], 0);

    _ownedArmors
      ..clear()
      ..add(ArmorRank.normal);
    for (final String name in _strings(json['ownedArmors'])) {
      _ownedArmors.add(ArmorRank.byName(name));
    }
    _equippedArmor = ArmorRank.byName(json['equippedArmor'] as String?);

    _boosters.clear();
    final Object? boosterJson = json['boosters'];
    if (boosterJson is Map) {
      boosterJson.forEach((Object? key, Object? value) {
        final BoosterKind? kind = BoosterKind.byName(key?.toString());
        if (kind != null) {
          _boosters[kind] = _int(value, 0);
        }
      });
    }
    _activeBooster = BoosterKind.byName(json['activeBooster'] as String?);

    _bestGrades.clear();
    final Object? gradeJson = json['bestGrades'];
    if (gradeJson is Map) {
      gradeJson.forEach((Object? key, Object? value) {
        final int? number = int.tryParse(key?.toString() ?? '');
        if (number != null) {
          _bestGrades[number] = LevelGrade.byName(value?.toString());
        }
      });
    }

    _chimeraGrades.clear();
    final Object? chimeraJson = json['chimeraGrades'];
    if (chimeraJson is Map) {
      chimeraJson.forEach((Object? key, Object? value) {
        final ChimeraType? type = ChimeraType.byName(key?.toString());
        if (type != null) {
          _chimeraGrades[type] = LevelGrade.byName(value?.toString());
        }
      });
    }
    _chimerasDefeated
      ..clear()
      ..addAll(_chimeraTypes(_strings(json['chimerasDefeated'])));
    _eliteAttempts.clear();
    final Object? attemptsJson = json['eliteAttempts'];
    if (attemptsJson is Map) {
      attemptsJson.forEach((Object? key, Object? value) {
        final ChimeraType? type = ChimeraType.byName(key?.toString());
        if (type != null) {
          _eliteAttempts[type] = _int(value, 0);
        }
      });
    }
    _ownedEliteArmors.clear();
    for (final String name in _strings(json['ownedEliteArmors'])) {
      final ChimeraArmorKind? armor = ChimeraArmorKind.byName(name);
      if (armor != null) {
        _ownedEliteArmors.add(armor);
      }
    }
    _equippedEliteArmor = ChimeraArmorKind.byName(json['equippedEliteArmor'] as String?);

    _unlockedPowers.clear();
    for (final String name in _strings(json['unlockedPowers'])) {
      for (final ElitePowerKind power in ElitePowerKind.values) {
        if (power.name == name) {
          _unlockedPowers.add(power);
        }
      }
    }

    _ownedTitles
      ..clear()
      ..add('Novice')
      ..addAll(_strings(json['ownedTitles']));
    final String? title = json['equippedTitle'] as String?;
    _equippedTitle = title != null && _ownedTitles.contains(title) ? title : 'Novice';
    _ownedCosmetics
      ..clear()
      ..addAll(_strings(json['ownedCosmetics']));

    _totalWins = _int(json['totalWins'], 0);
    _totalBattles = _int(json['totalBattles'], 0);
    _totalKills = _int(json['totalKills'], 0);
    _bossDefeated
      ..clear()
      ..addAll(
        _strings(json['bossDefeated']).map((String name) => Rank.byName(name)),
      );
    _weaponFragments = _int(json['weaponFragments'], 0);
    _gradeSkipTokens = _int(json['gradeSkipTokens'], 0);
    _lastDailyWin = json['lastDailyWin'] as String?;
    _permanentCoinMultiplier =
        _double(json['permanentCoinMultiplier'], 1.0).clamp(1.0, 4.0);
    _assistMode = json['assistMode'] == true;
    _eliteChestsOpened = _int(json['eliteChestsOpened'], 0);
  }

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'coins': _coins,
      'lifetimeCoins': _lifetimeCoins,
      'playerXp': _playerXp,
      'ownedArmors': _ownedArmors.map((ArmorRank a) => a.name).toList(),
      'equippedArmor': _equippedArmor.name,
      'boosters': _boosters.map((BoosterKind k, int v) => MapEntry<String, int>(k.name, v)),
      'activeBooster': _activeBooster?.name,
      'bestGrades': _bestGrades.map(
        (int level, LevelGrade grade) => MapEntry<String, String>(level.toString(), grade.name),
      ),
      'chimeraGrades': _chimeraGrades.map(
        (ChimeraType type, LevelGrade grade) => MapEntry<String, String>(type.name, grade.name),
      ),
      'chimerasDefeated': _chimerasDefeated.map((ChimeraType t) => t.name).toList(),
      'eliteAttempts': _eliteAttempts.map(
        (ChimeraType type, int count) => MapEntry<String, int>(type.name, count),
      ),
      'ownedEliteArmors': _ownedEliteArmors.map((ChimeraArmorKind a) => a.name).toList(),
      'equippedEliteArmor': _equippedEliteArmor?.name,
      'unlockedPowers': _unlockedPowers.map((ElitePowerKind p) => p.name).toList(),
      'ownedTitles': _ownedTitles.toList(),
      'equippedTitle': _equippedTitle,
      'ownedCosmetics': _ownedCosmetics.toList(),
      'totalWins': _totalWins,
      'totalBattles': _totalBattles,
      'totalKills': _totalKills,
      'bossDefeated': _bossDefeated.map((Rank r) => r.name).toList(),
      'weaponFragments': _weaponFragments,
      'gradeSkipTokens': _gradeSkipTokens,
      'lastDailyWin': _lastDailyWin,
      'permanentCoinMultiplier': _permanentCoinMultiplier,
      'assistMode': _assistMode,
      'eliteChestsOpened': _eliteChestsOpened,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void _markDirty() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      save();
    });
  }

  Future<void> save() async {
    if (!_dirty) {
      return;
    }
    _dirty = false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  /// Full wipe (profile screen "reset progress").
  Future<void> resetProgress() async {
    _coins = 0;
    _lifetimeCoins = 0;
    _playerXp = 0;
    _playerLevel = 1;
    _ownedArmors
      ..clear()
      ..add(ArmorRank.normal);
    _equippedArmor = ArmorRank.normal;
    _boosters.clear();
    _activeBooster = null;
    _bestGrades.clear();
    _chimeraGrades.clear();
    _chimerasDefeated.clear();
    _eliteAttempts.clear();
    _ownedEliteArmors.clear();
    _equippedEliteArmor = null;
    _unlockedPowers.clear();
    _ownedTitles
      ..clear()
      ..add('Novice');
    _equippedTitle = 'Novice';
    _ownedCosmetics.clear();
    _totalWins = 0;
    _totalBattles = 0;
    _totalKills = 0;
    _bossDefeated.clear();
    _weaponFragments = 0;
    _gradeSkipTokens = 0;
    _lastDailyWin = null;
    _permanentCoinMultiplier = 1.0;
    _assistMode = false;
    _eliteChestsOpened = 0;
    _dirty = true;
    notifyListeners();
    await save();
  }

  /// Chest tier for a finished elite trial.
  ChestRarity chestFor(LevelGrade grade) => ChestRarity.forGrade(grade);

  // ----------------------------------------------------------------- helpers
  Iterable<ChimeraType> _chimeraTypes(List<String> names) {
    return names
        .map(ChimeraType.byName)
        .where((ChimeraType? type) => type != null)
        .cast<ChimeraType>();
  }

  static List<String> _strings(Object? value) {
    if (value is List) {
      return value.whereType<Object>().map((Object e) => e.toString()).toList();
    }
    return const <String>[];
  }

  static int _int(Object? value, int fallback) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static double _double(Object? value, double fallback) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }
}
