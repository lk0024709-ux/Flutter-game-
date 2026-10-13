import 'package:flutter/foundation.dart';

import 'gltf_loader.dart';
import 'procedural_meshes.dart';
import 'texture_loader.dart';

/// Where a model's geometry came from, shown on the asset report screen.
enum AssetOrigin {
  /// Loaded from a downloaded .glb file in `assets/models`.
  model,

  /// Built procedurally because the file was missing or unreadable.
  procedural,
}

/// One named slot in the model palette.
///
/// Slots are the contract between the engine and the art: a slot declares what
/// it wants (`assets/models/...glb`, normalised to `targetHeight` world units)
/// and how to survive without it ([fallback]).
class AssetSlot {
  AssetSlot({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.targetHeight,
    required this.source,
    this.fallback,
    this.note,
  });

  final String id;
  final String label;
  final String assetPath;

  /// World-space height the model is scaled to when drawn.
  final double targetHeight;

  /// Attribution recorded in assets/LICENSES.txt.
  final String source;

  /// Optional build-time description of the procedural stand-in.
  final String? note;

  /// Builds the stand-in model when the file cannot be loaded.
  final Model3D Function()? fallback;

  /// A slot that never loads a file (pure procedural geometry such as ground
  /// markers). The builder is used verbatim.
  AssetSlot.procedural({
    required this.id,
    required this.label,
    required Model3D Function() builder,
    this.source = 'Procedural (this project)',
    this.note,
  })  : assetPath = '',
        targetHeight = 1,
        fallback = builder;

  Model3D? model;
  AssetOrigin origin = AssetOrigin.procedural;
  String? warning;

  bool get isLoaded => model != null;
}

/// One decoded surface texture from `assets/textures`.
///
/// Textures are optional: every slot names the surface it dresses and what the
/// engine does with it, and the arena falls back to flat colours when the file
/// is absent.
class TextureSlot {
  const TextureSlot({
    required this.id,
    required this.label,
    required this.path,
    required this.usage,
    this.source = 'ambientCG (CC0 1.0) - https://ambientcg.com',
  });

  final String id;
  final String label;
  final String path;
  final String usage;
  final String source;

  BakedTexture? texture;
  String? warning;

  bool get isLoaded => texture != null;
}

/// Loads, caches and normalises every model the game uses.
///
/// Loading is lazy but reported eagerly: [loadAll] walks the whole catalogue,
/// returns a per-slot report and keeps everything in memory, so the first frame
/// of a battle never stutters while a .glb is parsed.
class AssetLoader {
  AssetLoader._();

  static final AssetLoader instance = AssetLoader._();

  final Map<String, Model3D?> _cache = <String, Model3D?>{};
  final Map<String, BakedTexture> _textures = <String, BakedTexture>{};
  final List<TextureSlot> _textureSlots = <TextureSlot>[];
  final List<AssetSlot> _slots = <AssetSlot>[];
  final List<String> _notes = <String>[];

  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<AssetSlot> get slots => List<AssetSlot>.unmodifiable(_slots);

  /// Notes collected during loading (missing textures, skipped primitives...).
  List<String> get notes => List<String>.unmodifiable(_notes);

  int get loadedModelCount => _slots.where((AssetSlot slot) => slot.origin == AssetOrigin.model).length;

  int get proceduralCount => _slots.where((AssetSlot slot) => slot.origin == AssetOrigin.procedural).length;

  /// Registered surface textures with their load state.
  List<TextureSlot> get textureSlots => List<TextureSlot>.unmodifiable(_textureSlots);

  /// Number of texture files that decoded successfully.
  int get loadedTextureCount =>
      _textureSlots.where((TextureSlot slot) => slot.isLoaded).length;

  /// A decoded texture, or null when the file is absent.
  BakedTexture? texture(String id) => _textures[id];

  /// Looks a slot up by id; returns the procedural fallback if it never loaded.
  Model3D model(String id) {
    for (final AssetSlot slot in _slots) {
      if (slot.id == id) {
        return slot.model ?? slot.fallback?.call() ?? ProceduralMeshes.placeholder(name: id);
      }
    }
    return ProceduralMeshes.placeholder(name: id);
  }

  /// Direct cache access for one-off loads.
  Future<Model3D?> load(String assetPath, {String? name}) async {
    final String key = assetPath;
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    final Model3D? model = await GltfLoader.loadAsset(
      assetPath,
      name: name,
      onWarn: _notes.add,
    );
    _cache[key] = model;
    return model;
  }

  /// Registers the standard palette. Safe to call more than once.
  void registerDefaultSlots() {
    if (_slots.isNotEmpty) {
      return;
    }
    _slots.addAll(_buildCatalog());
  }

  /// Loads every registered slot and returns the report.
  Future<List<AssetSlot>> loadAll() async {
    registerDefaultSlots();
    for (final AssetSlot slot in _slots) {
      if (slot.model != null) {
        continue;
      }
      if (slot.assetPath.isEmpty) {
        slot.origin = AssetOrigin.procedural;
        slot.model = slot.fallback?.call() ?? ProceduralMeshes.placeholder(name: slot.id);
        continue;
      }
      final Model3D? model = await load(slot.assetPath, name: slot.id);
      if (model != null && model.triangleCount > 0) {
        slot.model = model;
        slot.origin = AssetOrigin.model;
      } else {
        slot.origin = AssetOrigin.procedural;
        slot.warning = 'missing ${slot.assetPath} - procedural stand-in built';
        slot.model = slot.fallback?.call() ??
            ProceduralMeshes.placeholder(name: slot.id, color: 0xFFB45309);
      }
      if (slot.model != null && slot.targetHeight > 0 && slot.model!.bounds.height > 0.0001) {
        // Normalisation happens at draw time through [ModelInstance.scale], so
        // the slot only records the intent.
        _normalisationScales[slot.id] = slot.model!.bounds.scaleToHeight(slot.targetHeight);
      }
    }
    await _loadTextures();
    _loaded = true;
    return _slots;
  }

  /// Decodes every registered texture. Failures are recorded, never fatal.
  Future<void> _loadTextures() async {
    registerTextureSlots();
    await Future.wait(_textureSlots.map((TextureSlot slot) async {
      if (slot.texture != null) {
        return;
      }
      final BakedTexture? baked = await TextureLoader.loadAsset(
        slot.path,
        id: slot.id,
        label: slot.label,
        source: slot.source,
        onWarn: _notes.add,
      );
      if (baked == null) {
        slot.warning = 'missing ${slot.path} - flat colour used instead';
        return;
      }
      slot.texture = baked;
      _textures[slot.id] = baked;
    }));
  }

  /// Registers the surface textures shipped in `assets/textures`. Safe to call
  /// more than once.
  void registerTextureSlots() {
    if (_textureSlots.isNotEmpty) {
      return;
    }
    _textureSlots.addAll(const <TextureSlot>[
      TextureSlot(
        id: 'arena_floor',
        label: 'Paving stones',
        path: 'assets/textures/arena_floor.jpg',
        usage: 'Arena ground plate and safe-zone rings.',
      ),
      TextureSlot(
        id: 'temple_tiles',
        label: 'Temple tiles',
        path: 'assets/textures/temple_tiles.jpg',
        usage: 'Sanctum and rank-boss floors.',
      ),
      TextureSlot(
        id: 'arena_rock',
        label: 'Cliff rock',
        path: 'assets/textures/arena_rock.jpg',
        usage: 'Masonry ring, columns and obelisks.',
      ),
      TextureSlot(
        id: 'wilds_grass',
        label: 'Wild grass',
        path: 'assets/textures/wilds_grass.jpg',
        usage: 'Forest and grassland scenery clusters.',
      ),
      TextureSlot(
        id: 'gravel_pit',
        label: 'Gravel pit',
        path: 'assets/textures/gravel_pit.jpg',
        usage: 'Poison pools, ash fields and the storm ring.',
      ),
      TextureSlot(
        id: 'crate_planks',
        label: 'Crate planks',
        path: 'assets/textures/crate_planks.jpg',
        usage: 'Crates, banners and wooden barricades.',
      ),
      TextureSlot(
        id: 'arena_wall',
        label: 'Rammed earth wall',
        path: 'assets/textures/arena_wall.jpg',
        usage: 'Outer walls and ruins.',
      ),
      TextureSlot(
        id: 'frozen_peaks',
        label: 'Snow crust',
        path: 'assets/textures/frozen_peaks.jpg',
        usage: 'Frozen Peak arena variant.',
      ),
    ]);
  }

  final Map<String, double> _normalisationScales = <String, double>{};

  /// Pre-computed scale that makes a slot exactly `targetHeight` units tall.
  double normalisationScale(String id) => _normalisationScales[id] ?? 1;

  /// Full catalogue: characters, creatures, props and the Khronos models that
  /// prove the GLB pipeline handles a foreign file format too.
  List<AssetSlot> _buildCatalog() {
    const String kenneyArena = 'assets/models/kenney/mini-arena';
    const String kenneyForest = 'assets/models/kenney/mini-forest';
    const String kenneyPets = 'assets/models/kenney/cube-pets';
    const String kenneyGrave = 'assets/models/kenney/graveyard';

    AssetSlot kenney({
      required String id,
      required String label,
      required String kit,
      required String file,
      required double height,
      Model3D Function()? fallback,
      String? note,
    }) {
      return AssetSlot(
        id: id,
        label: label,
        assetPath: '$kit/$file.glb',
        targetHeight: height,
        source: 'Kenney (CC0 1.0) - https://kenney.nl/assets',
        fallback: fallback,
        note: note,
      );
    }

    return <AssetSlot>[
      // ------------------------------------------------------------ fighters
      kenney(
        id: 'fighter_warrior',
        label: 'Warrior (soldier)',
        kit: kenneyArena,
        file: 'character-soldier',
        height: 1.8,
        fallback: () => ProceduralMeshes.humanoid(name: 'warrior'),
        note: 'Bind pose only - the engine does not play skeletal animation.',
      ),
      kenney(
        id: 'fighter_archer',
        label: 'Skirmisher (archer)',
        kit: kenneyForest,
        file: 'character-archer',
        height: 1.8,
        fallback: () => ProceduralMeshes.humanoid(name: 'archer', cloth: 0xFF3F6212),
      ),
      // ----------------------------------------------------------- creatures
      kenney(
        id: 'creature_lion',
        label: 'Griffin (lion)',
        kit: kenneyPets,
        file: 'animal-lion',
        height: 1.25,
        fallback: () => ProceduralMeshes.quadruped(name: 'lion', wings: true),
        note: 'Stands in for the Griffin of the Dust Pit.',
      ),
      kenney(
        id: 'creature_tiger',
        label: 'Drake (tiger)',
        kit: kenneyPets,
        file: 'animal-tiger',
        height: 1.2,
        fallback: () => ProceduralMeshes.quadruped(name: 'tiger', body: 0xFFB45309, horned: true),
      ),
      kenney(
        id: 'creature_boar',
        label: 'Iron Boar (hog)',
        kit: kenneyPets,
        file: 'animal-hog',
        height: 1.0,
        fallback: () => ProceduralMeshes.quadruped(name: 'boar', body: 0xFF7C4A2D),
      ),
      kenney(
        id: 'creature_hawk',
        label: 'Skyhawk (parrot)',
        kit: kenneyPets,
        file: 'animal-parrot',
        height: 0.9,
        fallback: () => ProceduralMeshes.quadruped(name: 'hawk', body: 0xFF3F6212, wings: true),
      ),
      kenney(
        id: 'creature_fox',
        label: 'Fox (hunter)',
        kit: kenneyPets,
        file: 'animal-fox',
        height: 0.9,
        fallback: () => ProceduralMeshes.quadruped(name: 'fox', body: 0xFFC2410C),
      ),
      kenney(
        id: 'creature_venom',
        label: 'Venomtail (caterpillar)',
        kit: kenneyPets,
        file: 'animal-caterpillar',
        height: 0.7,
        fallback: () => ProceduralMeshes.quadruped(name: 'venom', body: 0xFF4D7C0F),
      ),
      kenney(
        id: 'creature_bee',
        label: 'Stingwing (bee)',
        kit: kenneyPets,
        file: 'animal-bee',
        height: 0.7,
        fallback: () => ProceduralMeshes.quadruped(name: 'sting', body: 0xFFD97706, wings: true),
      ),
      kenney(
        id: 'creature_heavy',
        label: 'Ravager (elephant)',
        kit: kenneyPets,
        file: 'animal-elephant',
        height: 1.8,
        fallback: () => ProceduralMeshes.quadruped(name: 'ravager', body: 0xFF78716C, scale: 1.4),
      ),
      // --------------------------------------------------------- elite bosses
      kenney(
        id: 'boss_skeleton',
        label: 'Skeleton captain',
        kit: kenneyGrave,
        file: 'character-skeleton',
        height: 1.9,
        fallback: () => ProceduralMeshes.humanoid(name: 'skeleton', skin: 0xFFE7E1D3, cloth: 0xFF44403C),
      ),
      kenney(
        id: 'boss_zombie',
        label: 'Rotwater brute',
        kit: kenneyGrave,
        file: 'character-zombie',
        height: 1.9,
        fallback: () => ProceduralMeshes.humanoid(name: 'brute', skin: 0xFF65A30D, cloth: 0xFF3F6212),
      ),
      kenney(
        id: 'boss_vampire',
        label: 'Basilisk lord',
        kit: kenneyGrave,
        file: 'character-vampire',
        height: 1.95,
        fallback: () => ProceduralMeshes.humanoid(name: 'lord', skin: 0xFFE7E1D3, cloth: 0xFF7C2D12),
      ),
      kenney(
        id: 'boss_ghost',
        label: 'Omega wraith',
        kit: kenneyGrave,
        file: 'character-ghost',
        height: 2.0,
        fallback: () => ProceduralMeshes.humanoid(name: 'wraith', skin: 0xFFE7E1D3, cloth: 0xFF0891B2),
      ),
      // ------------------------------------------------------------- weapons
      kenney(
        id: 'weapon_sword',
        label: 'Arena sword',
        kit: kenneyArena,
        file: 'weapon-sword',
        height: 1.3,
        fallback: () => ProceduralMeshes.sword(name: 'sword'),
      ),
      kenney(
        id: 'weapon_bow',
        label: 'Hunter bow',
        kit: kenneyForest,
        file: 'weapon-bow',
        height: 1.2,
        fallback: () => ProceduralMeshes.sword(name: 'bow', blade: 0xFF65A30D),
      ),
      // -------------------------------------------------------- arena masonry
      kenney(
        id: 'prop_floor',
        label: 'Arena floor tile',
        kit: kenneyArena,
        file: 'floor',
        height: 0.2,
        fallback: () => ProceduralMeshes.groundTile(name: 'floor'),
      ),
      kenney(
        id: 'prop_bricks',
        label: 'Brick block',
        kit: kenneyArena,
        file: 'bricks',
        height: 1.0,
        fallback: () => ProceduralMeshes.block(name: 'bricks'),
      ),
      kenney(
        id: 'prop_wall',
        label: 'Arena wall',
        kit: kenneyArena,
        file: 'wall',
        height: 1.6,
        fallback: () => ProceduralMeshes.block(name: 'wall', color: 0xFFB9B0A0),
      ),
      kenney(
        id: 'prop_column',
        label: 'Column',
        kit: kenneyArena,
        file: 'column',
        height: 3.2,
        fallback: () => ProceduralMeshes.column(name: 'column'),
      ),
      kenney(
        id: 'prop_column_broken',
        label: 'Broken column',
        kit: kenneyArena,
        file: 'column-damaged',
        height: 2.2,
        fallback: () => ProceduralMeshes.column(name: 'column_broken', height: 1.8),
      ),
      kenney(
        id: 'prop_statue',
        label: 'Statue',
        kit: kenneyArena,
        file: 'statue',
        height: 2.6,
        fallback: () => ProceduralMeshes.column(name: 'statue', color: 0xFFD6CFC0, height: 2.2),
      ),
      kenney(
        id: 'prop_trophy',
        label: 'Trophy',
        kit: kenneyArena,
        file: 'trophy',
        height: 1.4,
        fallback: () => ProceduralMeshes.placeholder(name: 'trophy', color: 0xFFD97706),
      ),
      kenney(
        id: 'prop_banner',
        label: 'Banner',
        kit: kenneyArena,
        file: 'banner',
        height: 2.4,
        fallback: () => ProceduralMeshes.plate(name: 'banner', color: 0xFF7C2D12, size: 1.2),
      ),
      // ---------------------------------------------------------- wilds props
      kenney(
        id: 'prop_tree',
        label: 'Tree',
        kit: kenneyForest,
        file: 'tree',
        height: 3.0,
        fallback: () => ProceduralMeshes.tree(name: 'tree'),
      ),
      kenney(
        id: 'prop_tree_tall',
        label: 'Tall tree',
        kit: kenneyForest,
        file: 'tree-high',
        height: 4.4,
        fallback: () => ProceduralMeshes.tree(name: 'tree_tall', foliage: 0xFF2F4F14),
      ),
      kenney(
        id: 'prop_pine',
        label: 'Pine',
        kit: kenneyGrave,
        file: 'pine',
        height: 4.0,
        fallback: () => ProceduralMeshes.tree(name: 'pine', foliage: 0xFF2F4F14),
      ),
      kenney(
        id: 'prop_rock',
        label: 'Boulder',
        kit: kenneyForest,
        file: 'rocks-high',
        height: 1.1,
        fallback: () => ProceduralMeshes.rock(name: 'rock'),
      ),
      kenney(
        id: 'prop_rock_small',
        label: 'Small rock',
        kit: kenneyForest,
        file: 'rocks-low',
        height: 0.6,
        fallback: () => ProceduralMeshes.rock(name: 'rock_small', radius: 0.32),
      ),
      kenney(
        id: 'prop_stones',
        label: 'Stone cluster',
        kit: kenneyForest,
        file: 'stones',
        height: 0.5,
        fallback: () => ProceduralMeshes.rock(name: 'stones', color: 0xFFA8A29E, radius: 0.36),
      ),
      kenney(
        id: 'prop_plant',
        label: 'Shrub',
        kit: kenneyForest,
        file: 'plant',
        height: 0.9,
        fallback: () => ProceduralMeshes.tree(name: 'shrub', foliage: 0xFF4D7C0F),
      ),
      kenney(
        id: 'prop_fence',
        label: 'Fence',
        kit: kenneyForest,
        file: 'fence',
        height: 1.2,
        fallback: () => ProceduralMeshes.block(name: 'fence', color: 0xFF8C6B4A),
      ),
      kenney(
        id: 'prop_tent',
        label: 'Tent',
        kit: kenneyForest,
        file: 'tent',
        height: 1.8,
        fallback: () => ProceduralMeshes.placeholder(name: 'tent', color: 0xFF3F6212),
      ),
      kenney(
        id: 'prop_flag',
        label: 'Flag',
        kit: kenneyForest,
        file: 'flag',
        height: 2.6,
        fallback: () => ProceduralMeshes.sword(name: 'flag', blade: 0xFF7C2D12),
      ),
      kenney(
        id: 'prop_target',
        label: 'Training target',
        kit: kenneyForest,
        file: 'target',
        height: 1.5,
        fallback: () => ProceduralMeshes.cylinderTarget(),
      ),
      kenney(
        id: 'prop_grass',
        label: 'Grass patch',
        kit: kenneyForest,
        file: 'patch-grass',
        height: 0.2,
        fallback: () => ProceduralMeshes.plate(name: 'grass', color: 0xFF65A30D, size: 2),
      ),
      kenney(
        id: 'prop_dirt',
        label: 'Dirt patch',
        kit: kenneyForest,
        file: 'patch-dirt',
        height: 0.2,
        fallback: () => ProceduralMeshes.plate(name: 'dirt', color: 0xFFA16207, size: 2),
      ),
      // ------------------------------------------------------ graveyard props
      kenney(
        id: 'prop_grave_cross',
        label: 'Gravestone (cross)',
        kit: kenneyGrave,
        file: 'gravestone-cross',
        height: 1.6,
        fallback: () => ProceduralMeshes.block(name: 'grave_cross', color: 0xFF9CA3AF),
      ),
      kenney(
        id: 'prop_grave_round',
        label: 'Gravestone (round)',
        kit: kenneyGrave,
        file: 'gravestone-round',
        height: 1.4,
        fallback: () => ProceduralMeshes.block(name: 'grave_round', color: 0xFF9CA3AF),
      ),
      kenney(
        id: 'prop_grave_broken',
        label: 'Broken gravestone',
        kit: kenneyGrave,
        file: 'gravestone-broken',
        height: 1.0,
        fallback: () => ProceduralMeshes.block(name: 'grave_broken', color: 0xFF78716C),
      ),
      kenney(
        id: 'prop_crypt',
        label: 'Crypt',
        kit: kenneyGrave,
        file: 'crypt',
        height: 3.2,
        fallback: () => ProceduralMeshes.block(name: 'crypt', color: 0xFF6B7280),
      ),
      kenney(
        id: 'prop_coffin',
        label: 'Coffin',
        kit: kenneyGrave,
        file: 'coffin',
        height: 0.9,
        fallback: () => ProceduralMeshes.block(name: 'coffin', color: 0xFF7C2D12),
      ),
      kenney(
        id: 'prop_pumpkin',
        label: 'Pumpkin',
        kit: kenneyGrave,
        file: 'pumpkin',
        height: 0.8,
        fallback: () => ProceduralMeshes.rock(name: 'pumpkin', color: 0xFFC2410C, radius: 0.4),
      ),
      kenney(
        id: 'prop_lantern',
        label: 'Lantern',
        kit: kenneyGrave,
        file: 'lantern-candle',
        height: 1.3,
        fallback: () => ProceduralMeshes.column(name: 'lantern', color: 0xFF44403C, height: 1.1),
      ),
      kenney(
        id: 'prop_iron_fence',
        label: 'Iron fence',
        kit: kenneyGrave,
        file: 'iron-fence',
        height: 1.4,
        fallback: () => ProceduralMeshes.block(name: 'iron_fence', color: 0xFF3F3F46),
      ),
      kenney(
        id: 'prop_obelisk',
        label: 'Obelisk',
        kit: kenneyGrave,
        file: 'pillar-obelisk',
        height: 3.6,
        fallback: () => ProceduralMeshes.column(name: 'obelisk', color: 0xFF78716C, height: 3),
      ),
      kenney(
        id: 'prop_urn',
        label: 'Urn',
        kit: kenneyGrave,
        file: 'urn-round',
        height: 0.9,
        fallback: () => ProceduralMeshes.column(name: 'urn', color: 0xFFB9B0A0, height: 0.7),
      ),
      // -------------------------------------------------- procedural markers
      AssetSlot.procedural(
        id: 'marker_ground',
        label: 'Ground ring marker',
        builder: () => ProceduralMeshes.plate(name: 'marker_ground', color: 0x33D97706, size: 2.4),
        note: 'Flat quad used for spawn rings, telegraphs and safe-zone edges.',
      ),
      AssetSlot.procedural(
        id: 'marker_danger',
        label: 'Danger ring marker',
        builder: () => ProceduralMeshes.plate(name: 'marker_danger', color: 0x44B91C1C, size: 2.0),
      ),
      // ------------------------------------------- Khronos reference models
      AssetSlot(
        id: 'khronos_fox',
        label: 'Khronos Fox (GLB)',
        assetPath: 'assets/models/creatures/fox.glb',
        targetHeight: 0.9,
        source: 'Khronos glTF Sample Assets - CC0-1.0 / CC-BY-4.0',
        fallback: () => ProceduralMeshes.quadruped(name: 'fox_proc', body: 0xFFC2410C),
        note: 'Proves the loader reads an arbitrary third-party GLB.',
      ),
      AssetSlot(
        id: 'khronos_warrior',
        label: 'Khronos Rigged Figure (GLB)',
        assetPath: 'assets/models/player/warrior.glb',
        targetHeight: 1.7,
        source: 'Khronos glTF Sample Assets - CC-BY-4.0',
        fallback: () => ProceduralMeshes.humanoid(name: 'warrior_proc'),
      ),
      AssetSlot(
        id: 'khronos_scout',
        label: 'Khronos Cesium Man (GLB)',
        assetPath: 'assets/models/player/scout.glb',
        targetHeight: 1.7,
        source: 'Khronos glTF Sample Assets - CC-BY-4.0',
        fallback: () => ProceduralMeshes.humanoid(name: 'scout_proc', cloth: 0xFF3F6212),
      ),
      AssetSlot(
        id: 'khronos_box',
        label: 'Khronos Box (GLB)',
        assetPath: 'assets/models/props/box.glb',
        targetHeight: 1.0,
        source: 'Khronos glTF Sample Assets - CC-BY-4.0',
        fallback: () => ProceduralMeshes.block(name: 'box', color: 0xFFD6CFC0),
      ),
      AssetSlot(
        id: 'khronos_crate',
        label: 'Khronos Textured Crate (GLB)',
        assetPath: 'assets/models/props/crate.glb',
        targetHeight: 1.0,
        source: 'Khronos glTF Sample Assets - CC-BY-4.0',
        fallback: () => ProceduralMeshes.block(name: 'crate', color: 0xFFA16207),
      ),
    ];
  }
}
