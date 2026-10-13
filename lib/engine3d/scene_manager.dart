import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import '../theme/app_colors.dart';
import 'arena3d.dart';
import 'asset_loader.dart';
import 'camera_controller.dart';
import 'gltf_loader.dart';
import 'math3d.dart';
import 'procedural_meshes.dart';
import 'renderer3d.dart';
import 'texture_loader.dart';

/// Everything one 3D frame needs: the arena, the camera, the draw list and the
/// frame statistics.
///
/// The manager is deliberately dumb - it owns instances and draws them - while
/// gameplay (who moves where, what gets spawned) lives in the screen that owns
/// it. That keeps the engine reusable for the gallery screen.
class SceneManager3D {
  SceneManager3D({
    required this.layout,
    required AssetLoader assets,
    LightingRig? lighting,
  })  : assets = assets,
        renderer = Renderer3D(lighting: lighting),
        camera = CameraController3D();

  final ArenaLayout3D layout;
  final AssetLoader assets;
  final Renderer3D renderer;
  final CameraController3D camera;

  /// Static scenery, built once per arena.
  final List<MeshInstance> scenery = <MeshInstance>[];

  /// Dynamic objects (fighters, creatures, pickups), rebuilt by the screen.
  final List<MeshInstance> actors = <MeshInstance>[];

  /// Combined draw list handed to the renderer (scenery + actors).
  final List<MeshInstance> _drawList = <MeshInstance>[];

  /// Bumped once per frame so a [CustomPaint] can repaint without rebuilding
  /// the widget tree.
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  double _clock = 0;
  double _fpsAccumulator = 0;
  int _fpsFrames = 0;
  double fps = 0;

  /// Seconds since the scene was created (drives idle animation).
  double get clock => _clock;

  double get lastFrameMs => fps <= 0 ? 0 : 1000 / fps;

  /// Builds the static arena: ground plate, border ring and scenery props.
  void buildArena() {
    scenery.clear();

    // The floor is a subdivided plate: when a surface texture decoded, each
    // cell takes its colour from a sample of that texture, so downloaded stone
    // or grass reads on screen without a GPU sampler.
    final int floorColor = layout.floorColor;
    final BakedTexture? floorTexture = assets.texture('arena_floor');
    final Model3D ground = ProceduralMeshes.groundPlane(
      name: 'arena_floor',
      size: layout.halfExtent * 2,
      baseColor: floorColor,
      divisions: layout.halfExtent > 20 ? 26 : 18,
      sampler: floorTexture == null ? null : floorTexture.sampleArgb,
      mix: 0.6,
      jitter: 0.1,
    );
    scenery.add(
      MeshInstance(
        model: ground,
        position: Vector3(0, -0.06, 0),
        showShadow: false,
      ),
    );

    // A slightly inset accent plate reads as a worked stone border.
    scenery.add(
      MeshInstance(
        model: ProceduralMeshes.plate(
          name: 'arena_border',
          color: layout.accentColor,
          size: layout.halfExtent * 1.86,
        ),
        position: Vector3(0, -0.02, 0),
        showShadow: false,
      ),
    );

    // A third, warm centre plate gives the arena a focal point.
    scenery.add(
      MeshInstance(
        model: ProceduralMeshes.plate(
          name: 'arena_centre',
          color: layout.floorColor,
          size: layout.halfExtent * 0.9,
        ),
        position: Vector3(0, 0.005, 0),
        showShadow: false,
      ),
    );

    for (final PropPlacement prop in layout.props) {
      scenery.add(spawn(prop.slotId, prop.position, yaw: prop.yaw, scale: prop.scale));
    }
  }

  /// Creates an instance for a palette slot scaled to its target height.
  MeshInstance spawn(
    String slotId,
    Vector3 position, {
    double yaw = 0,
    double scale = 1,
    bool actor = false,
    int tint = 0xFFFFFFFF,
    double tintMix = 0,
  }) {
    final Model3D model = assets.model(slotId);
    final double normalisation = assets.normalisationScale(slotId);
    final MeshInstance instance = MeshInstance(
      model: model,
      position: position,
      yaw: yaw,
      scale: scale,
      modelScale: normalisation == 0 ? 1 : normalisation,
      tint: tint,
      tintMix: tintMix,
      shadowRadius: math.max(0.35, model.bounds.maxExtent * 0.4),
    );
    // Imported models are authored around their own origin; lift them so the
    // lowest vertex rests on the ground plane.
    instance.yOffset = -model.bounds.min.y * instance.effectiveScale;
    if (actor) {
      actors.add(instance);
    }
    return instance;
  }

  /// Builds an ad-hoc instance (palette lookups skipped).
  MeshInstance addModel(
    Model3D model,
    Vector3 position, {
    double yaw = 0,
    double scale = 1,
    double normaliseTo = 0,
    bool actor = true,
    int tint = 0xFFFFFFFF,
    double tintMix = 0,
  }) {
    final double normalisation = normaliseTo > 0 && model.bounds.height > 0.0001
        ? model.bounds.scaleToHeight(normaliseTo)
        : 1;
    final MeshInstance instance = MeshInstance(
      model: model,
      position: position,
      yaw: yaw,
      scale: scale,
      modelScale: normalisation,
      tint: tint,
      tintMix: tintMix,
      shadowRadius: math.max(0.35, model.bounds.maxExtent * 0.4),
    );
    instance.yOffset = -model.bounds.min.y * instance.effectiveScale;
    if (actor) {
      actors.add(instance);
    }
    return instance;
  }

  void advance(double dt) {
    _clock += dt;
    _fpsAccumulator += dt;
    _fpsFrames++;
    if (_fpsAccumulator >= 0.5) {
      fps = _fpsFrames / _fpsAccumulator;
      _fpsAccumulator = 0;
      _fpsFrames = 0;
    }
    frame.value++;
  }

  /// Draws background, arena and actors.
  void render(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    _drawList
      ..clear()
      ..addAll(scenery)
      ..addAll(actors);
    renderer.render(canvas, size, camera, _drawList);
  }

  void dispose() {
    frame.dispose();
  }

  void _drawBackground(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, -size.height * 0.35),
          Offset(0, size.height * 0.75),
          const <Color>[Color(0xFFEFE6D6), AppColors.background, Color(0xFFE3D8C4)],
        ),
    );
    // Warm horizon haze so the arena reads as a lit stage rather than a void.
    canvas.drawRect(
      Rect.fromLTRB(0, size.height * 0.42, size.width, size.height),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, size.height * 0.42),
          Offset(0, size.height),
          <Color>[const Color(0x00FFFFFF), const Color(0x22B45309)],
        ),
    );
  }
}
