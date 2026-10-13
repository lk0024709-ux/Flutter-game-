import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'weapon.dart';

class ForgeState extends ChangeNotifier {
  ForgeState._();
  static final ForgeState instance = ForgeState._();
  static const int capacity = 9;
  final List<WeaponTier?> slots = List<WeaponTier?>.filled(capacity, null);
  int totalMerges = 0;
  DateTime lastSaved = DateTime.now();
  Timer? _autoForge;
  bool _loaded = false;
  bool get isFull => slots.every((slot) => slot != null);
  WeaponTier get activeWeapon {
    final weapons = slots.whereType<WeaponTier>().toList();
    if (weapons.isEmpty) return WeaponTier.sword;
    weapons.sort((a, b) => b.level.compareTo(a.level));
    return weapons.first;
  }
  Duration get forgeInterval => Duration(milliseconds:
      (5000 - (totalMerges ~/ 10) * 300).clamp(1500, 5000).toInt());

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('forge.slots');
    if (raw != null) {
      try {
        final decoded = (jsonDecode(raw) as List).cast<int?>();
        for (var i = 0; i < capacity && i < decoded.length; i++) {
          final value = decoded[i];
          slots[i] = value == null ? null : WeaponTier.values[value.clamp(0, 5).toInt()];
        }
        totalMerges = prefs.getInt('forge.merges') ?? 0;
        final savedAt = prefs.getInt('forge.savedAt') ?? DateTime.now().millisecondsSinceEpoch;
        final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(savedAt));
        final spawns = elapsed.inMilliseconds ~/ forgeInterval.inMilliseconds;
        for (var i = 0; i < spawns.clamp(0, capacity); i++) {
          if (!spawnDagger(notify: false)) break;
        }
      } catch (_) {
        slots[0] = WeaponTier.dagger;
      }
    } else {
      slots[0] = WeaponTier.dagger;
      slots[1] = WeaponTier.dagger;
      slots[4] = WeaponTier.dagger;
    }
    _loaded = true;
    lastSaved = DateTime.now();
    _autoForge?.cancel();
    _autoForge = Timer.periodic(forgeInterval, (_) {
      if (!isFull) spawnDagger();
      _autoForge?.cancel();
      _autoForge = Timer(forgeInterval, _startAutoForge);
    });
    await save();
    notifyListeners();
  }

  void _startAutoForge() {
    _autoForge?.cancel();
    _autoForge = Timer.periodic(forgeInterval, (_) => spawnDagger());
  }

  bool spawnDagger({bool notify = true}) {
    final index = slots.indexWhere((slot) => slot == null);
    if (index < 0) return false;
    slots[index] = WeaponTier.dagger;
    if (notify) { notifyListeners(); unawaited(save()); }
    return true;
  }

  bool moveOrMerge(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= capacity || to >= capacity || slots[from] == null) return false;
    final source = slots[from]!;
    final target = slots[to];
    if (target == source) {
      if (source == WeaponTier.mythic) return false;
      slots[to] = source.next;
      slots[from] = null;
      totalMerges++;
    } else {
      slots[to] = source;
      slots[from] = target;
    }
    notifyListeners();
    unawaited(save());
    return true;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('forge.slots', jsonEncode(slots.map((e) => e?.index).toList()));
    await prefs.setInt('forge.merges', totalMerges);
    await prefs.setInt('forge.savedAt', DateTime.now().millisecondsSinceEpoch);
    lastSaved = DateTime.now();
  }

  @override
  void dispose() {
    _autoForge?.cancel();
    super.dispose();
  }
}
