import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weapon.dart';

/// Result of dragging one forge slot onto another.
enum MergeOutcome {
  /// Target was empty - the weapon simply moved.
  moved,

  /// Same tier - both blades fused into the next tier.
  merged,

  /// Different tiers - the two weapons swapped places.
  swapped,

  /// Both tiers are already mythic - the merge is refused.
  refused,
}

/// Persistent idle-forge state: a 3x3 grid, an auto-forging furnace and the
/// weapon the warrior takes into battle.
///
/// The furnace drops a dagger every [intervalSeconds] seconds into the first
/// empty slot. Merging two equal tiers upgrades the blade one tier higher; the
/// highest blade in the grid becomes the active battle weapon.
class ForgeState extends ChangeNotifier {
  ForgeState._();

  static final ForgeState instance = ForgeState._();

  /// 3x3 grid.
  static const int gridSize = 9;

  static const String _storageKey = 'blade_brawl_forge_v1';

  /// Base auto-forge interval in seconds.
  static const double baseInterval = 5.0;

  /// Interval removed for every [mergeStep] merges.
  static const double intervalStep = 0.3;

  /// How many merges are needed for one interval step.
  static const int mergeStep = 10;

  /// Fastest allowed auto-forge interval.
  static const double minInterval = 1.5;

  /// Manual "Forge Now" cooldown in seconds.
  static const double manualCooldown = 10.0;

  final List<WeaponTier?> _slots = List<WeaponTier?>.filled(gridSize, null);

  int _merges = 0;
  int _lifetimeMerges = 0;
  int _daggersForged = 0;
  double _manualCooldownLeft = 0;
  double _spawnTimer = 0;
  double _lastSpawnAge = 0;
  bool _loaded = false;
  bool _dirty = false;
  Timer? _engine;
  Timer? _saveTimer;
  DateTime? _lastActiveAt;

  /// Read-only view of the grid (null = empty slot).
  List<WeaponTier?> get slots => List<WeaponTier?>.unmodifiable(_slots);

  /// Merges performed this run (drives the furnace speed-up).
  int get merges => _merges;

  /// Merges performed across the whole save file (used by the power formula).
  int get lifetimeMerges => _lifetimeMerges;

  /// Daggers produced by the furnace.
  int get daggersForged => _daggersForged;

  bool get isLoaded => _loaded;

  /// Current auto-forge interval - 5s, reduced by 0.3s per 10 merges, floor 1.5s.
  double get intervalSeconds {
    final double raw = baseInterval - (_merges ~/ mergeStep) * intervalStep;
    return raw.clamp(minInterval, baseInterval);
  }

  /// 0..1 progress of the current forge cycle (drives the furnace ring).
  double get progress {
    if (isFull) {
      return 0;
    }
    final double p = _lastSpawnAge / intervalSeconds;
    return p.clamp(0.0, 1.0);
  }

  /// Seconds until the next dagger appears.
  double get secondsUntilNext {
    final double left = intervalSeconds - _lastSpawnAge;
    return left < 0 ? 0 : left;
  }

  /// True when the furnace cannot place another dagger.
  bool get isFull => !_slots.contains(null);

  /// Manual forge cooldown (0 = ready).
  double get manualCooldownLeft => _manualCooldownLeft;

  bool get canForgeNow => !isFull && _manualCooldownLeft <= 0;

  /// Number of empty slots.
  int get emptySlots => _slots.where((WeaponTier? t) => t == null).length;

  /// Highest tier currently sitting in the grid (dagger fallback).
  WeaponTier get bestTier {
    WeaponTier best = WeaponTier.dagger;
    for (final WeaponTier? tier in _slots) {
      if (tier != null && tier.level > best.level) {
        best = tier;
      }
    }
    return best;
  }

  /// The blade the warrior fights with.
  WeaponTier get activeWeapon => bestTier;

  /// Sum of every tier level in the grid - a rough "forge wealth" metric.
  int get gridPower {
    int total = 0;
    for (final WeaponTier? tier in _slots) {
      total += tier?.level ?? 0;
    }
    return total;
  }

  // ------------------------------------------------------------------ engine

  /// Starts the background forge engine (called once from `main`).
  void startEngine() {
    if (_engine != null) {
      return;
    }
    _lastActiveAt = DateTime.now();
    _engine = Timer.periodic(const Duration(milliseconds: 250), (Timer timer) {
      _tick(0.25);
    });
  }

  /// Advances the forge clock. Public so tests can drive it deterministically.
  void _tick(double dt) {
    final DateTime now = DateTime.now();
    if (_lastActiveAt != null) {
      final double realDt = now.difference(_lastActiveAt!).inMilliseconds / 1000.0;
      _lastActiveAt = now;
      // Guard against clock jumps / huge frame stalls.
      if (realDt > dt * 4 && realDt < 600) {
        dt = realDt;
      }
    }

    if (_manualCooldownLeft > 0) {
      _manualCooldownLeft = math.max(0.0, _manualCooldownLeft - dt);
    }

    if (isFull) {
      _lastSpawnAge = 0;
      notifyListeners();
      return;
    }

    _spawnTimer += dt;
    if (_spawnTimer >= 0.2) {
      _spawnTimer = 0;
      _lastSpawnAge += 0.2;
      if (_lastSpawnAge >= intervalSeconds) {
        _lastSpawnAge = 0;
        final bool spawned = forgeDagger();
        if (!spawned) {
          _lastSpawnAge = intervalSeconds;
        }
      }
      notifyListeners();
    }
  }

  /// Places a dagger in the first empty slot. Returns false when full.
  bool forgeDagger() {
    final int index = _slots.indexOf(null);
    if (index < 0) {
      return false;
    }
    _slots[index] = WeaponTier.dagger;
    _daggersForged++;
    _markDirty();
    notifyListeners();
    return true;
  }

  /// Manual "Forge Now": spawns a dagger if the 10s cooldown has elapsed.
  bool forgeNow() {
    if (!canForgeNow) {
      return false;
    }
    _manualCooldownLeft = manualCooldown;
    return forgeDagger();
  }

  /// Coin-bought forge speed-up: resets the manual cooldown and forges at once.
  bool rushForge() {
    _manualCooldownLeft = 0;
    return forgeDagger();
  }

  // ------------------------------------------------------------------ merging

  /// Drag-and-drop handler for the 3x3 grid.
  MergeOutcome moveOrMerge(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= gridSize || to >= gridSize) {
      return MergeOutcome.refused;
    }
    final WeaponTier? source = _slots[from];
    if (source == null) {
      return MergeOutcome.refused;
    }
    final WeaponTier? target = _slots[to];

    if (target == null) {
      _slots[to] = source;
      _slots[from] = null;
      _markDirty();
      notifyListeners();
      return MergeOutcome.moved;
    }

    if (target.level == source.level) {
      if (target.isMax) {
        return MergeOutcome.refused;
      }
      _slots[to] = target.next;
      _slots[from] = null;
      _merges++;
      _lifetimeMerges++;
      _markDirty();
      notifyListeners();
      return MergeOutcome.merged;
    }

    _slots[to] = source;
    _slots[from] = target;
    _markDirty();
    notifyListeners();
    return MergeOutcome.swapped;
  }

  /// Forges a weapon of [tier] into the first empty slot (fragment purchase).
  bool injectWeapon(WeaponTier tier) {
    final int index = _slots.indexOf(null);
    if (index < 0) {
      return false;
    }
    _slots[index] = tier;
    _markDirty();
    notifyListeners();
    return true;
  }

  /// Sells every weapon at or below [tier] for coins handled by the caller.
  void clearGrid() {
    for (int i = 0; i < gridSize; i++) {
      _slots[i] = null;
    }
    _markDirty();
    notifyListeners();
  }

  // ------------------------------------------------------------- persistence

  /// Offline simulation: fills empty slots based on the elapsed time.
  void simulateOffline(Duration elapsed) {
    final double seconds = elapsed.inMilliseconds / 1000.0;
    if (seconds < 1) {
      return;
    }
    final int daggers = (seconds / intervalSeconds).floor().clamp(0, gridSize);
    for (int i = 0; i < daggers; i++) {
      if (!forgeDagger()) {
        break;
      }
    }
    if (daggers > 0) {
      _lastSpawnAge = 0;
      notifyListeners();
    }
  }

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
        debugPrint('ForgeState: could not decode save ($error)');
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void _fromJson(Map<String, dynamic> json) {
    final Object? rawSlots = json['slots'];
    if (rawSlots is List) {
      for (int i = 0; i < gridSize && i < rawSlots.length; i++) {
        final Object? entry = rawSlots[i];
        if (entry is String) {
          for (final WeaponTier tier in WeaponTier.values) {
            if (tier.name == entry) {
              _slots[i] = tier;
            }
          }
        } else {
          _slots[i] = null;
        }
      }
    }
    _merges = _asInt(json['merges'], 0);
    _lifetimeMerges = _asInt(json['lifetimeMerges'], _merges);
    _daggersForged = _asInt(json['daggersForged'], 0);
    final int lastSeen = _asInt(json['lastSeenMs'], 0);
    if (lastSeen > 0) {
      final Duration away = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(lastSeen),
      );
      if (!away.isNegative) {
        simulateOffline(away);
      }
    }
    if (_slots.every((WeaponTier? t) => t == null)) {
      // Fresh save: hand the player one starter dagger.
      _slots[4] = WeaponTier.dagger;
    }
  }

  Map<String, dynamic> _toJson() {
    return <String, dynamic>{
      'slots': _slots.map((WeaponTier? t) => t?.name).toList(),
      'merges': _merges,
      'lifetimeMerges': _lifetimeMerges,
      'daggersForged': _daggersForged,
      'lastSeenMs': DateTime.now().millisecondsSinceEpoch,
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

  /// Wipes the forge (used by the profile "reset" action).
  Future<void> resetProgress() async {
    for (int i = 0; i < gridSize; i++) {
      _slots[i] = null;
    }
    _slots[4] = WeaponTier.dagger;
    _merges = 0;
    _lifetimeMerges = 0;
    _daggersForged = 0;
    _manualCooldownLeft = 0;
    _lastSpawnAge = 0;
    _dirty = true;
    notifyListeners();
    await save();
  }

  /// Stops background timers (used by tests).
  void stopEngine() {
    _engine?.cancel();
    _engine = null;
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  static int _asInt(Object? value, int fallback) {
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
}
