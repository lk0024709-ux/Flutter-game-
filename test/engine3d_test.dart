import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:blade_brawl/engine3d/arena3d.dart';
import 'package:blade_brawl/engine3d/asset_loader.dart';
import 'package:blade_brawl/engine3d/camera_controller.dart';
import 'package:blade_brawl/engine3d/gltf_loader.dart';
import 'package:blade_brawl/engine3d/math3d.dart';
import 'package:blade_brawl/engine3d/procedural_meshes.dart';
import 'package:blade_brawl/engine3d/renderer3d.dart';
import 'package:blade_brawl/engine3d/scene_manager.dart';
import 'package:blade_brawl/game/audio_catalog.dart';
import 'package:blade_brawl/game/game_map.dart';

/// Everything here runs without loading a single asset file: the 3D layer must
/// be correct geometry, correct maths and a complete palette even when every
/// download failed. Files are exercised by the game itself, not by the tests.
void main() {
  group('math helpers', () {
    test('angleDelta takes the short way around the circle', () {
      expect(Math3d.angleDelta(0, 1), closeTo(1, 1e-9));
      expect(Math3d.angleDelta(0, -1), closeTo(-1, 1e-9));
      // 350 degrees is 10 degrees to the left, not 350 to the right.
      expect(Math3d.angleDelta(0, 350 * 3.141592653589793 / 180), closeTo(-0.1745, 1e-3));
    });

    test('approachAngle never overshoots and lands exactly on target', () {
      expect(Math3d.approachAngle(0, 1, 0.25), closeTo(0.25, 1e-9));
      expect(Math3d.approachAngle(0, 1, 9), 1);
      expect(Math3d.approachAngle(3, -3, 0.1).abs(), lessThanOrEqualTo(3.1));
      // Walking a full turn back onto itself is stable, not spinning.
      double angle = 0;
      for (int i = 0; i < 40; i++) {
        angle = Math3d.approachAngle(angle, 0, 0.3);
      }
      expect(angle.abs(), lessThan(1e-9));
    });

    test('tint respects the alpha channel and clamps', () {
      expect(LightingRig.tint(0xFF808080, 2), 0xFFFFFFFF);
      expect(LightingRig.tint(0xFF000000, 1), 0xFF000000);
      final int mixed = LightingRig.tint(0xFF000000, 1, mixWith: 0xFFFFFFFF, mix: 0.5);
      expect((mixed >> 16) & 0xFF, closeTo(128, 1));
    });

    test('bounds normalise models to a target height', () {
      final Bounds3 bounds = Bounds3(
        Vector3(-1, 0, -1),
        Vector3(1, 4, 1),
      );
      expect(bounds.height, 4);
      expect(bounds.maxExtent, 4);
      expect(bounds.scaleToHeight(1.8), closeTo(0.45, 1e-9));
      expect(bounds.center.y, 2);
      // Degenerate boxes never divide by zero.
      expect(Math3d.emptyBounds.scaleToHeight(2), 1);
    });
  });

  group('procedural meshes', () {
    test('every primitive produces a triangle soup with matching arrays', () {
      final List<Model3D> models = <Model3D>[
        ProceduralMeshes.humanoid(),
        ProceduralMeshes.quadruped(),
        ProceduralMeshes.tree(),
        ProceduralMeshes.rock(),
        ProceduralMeshes.column(),
        ProceduralMeshes.block(),
        ProceduralMeshes.plate(color: 0xFFE7E1D3),
        ProceduralMeshes.placeholder(),
      ];
      for (final Model3D model in models) {
        expect(model.triangleCount, greaterThan(0), reason: model.name);
        expect(model.positions.length, model.vertexCount * 3);
        expect(model.normals.length, model.vertexCount * 3);
        expect(model.indices.length, model.triangleCount * 3);
        expect(model.bounds.maxExtent, greaterThan(0), reason: model.name);
        expect(model.byteSize, greaterThan(0));
      }
    });

    test('shapes are human-scaled so the arena reads correctly', () {
      final Model3D warrior = ProceduralMeshes.humanoid();
      expect(warrior.bounds.height, inInclusiveRange(1.4, 2.2));
      final Model3D beast = ProceduralMeshes.quadruped();
      expect(beast.bounds.height, lessThan(warrior.bounds.height));
      final Model3D tree = ProceduralMeshes.tree();
      expect(tree.bounds.height, greaterThan(warrior.bounds.height));
    });

    test('groundPlane samples its sampler across the grid', () {
      final Model3D flat = ProceduralMeshes.groundPlane(
        size: 40,
        baseColor: 0xFF8C8678,
        divisions: 8,
      );
      expect(flat.triangleCount, 8 * 8 * 2);

      final Model3D textured = ProceduralMeshes.groundPlane(
        size: 40,
        baseColor: 0xFF8C8678,
        divisions: 8,
        sampler: (double u, double v) => u < 0.5 ? 0xFF000000 : 0xFFFFFFFF,
        mix: 1,
      );
      final Set<int> colours = textured.colors.toSet();
      expect(colours.length, greaterThan(1),
          reason: 'a sampler must actually change the vertex colours');
      expect(textured.bounds.maxExtent, closeTo(40, 1e-6));
      expect(textured.bounds.height, closeTo(0, 1e-6));
    });

    test('jitter breaks up large surfaces without changing the palette', () {
      final Model3D plain = ProceduralMeshes.groundPlane(
        size: 20,
        baseColor: 0xFF8C8678,
        divisions: 6,
      );
      final Model3D noisy = ProceduralMeshes.groundPlane(
        size: 20,
        baseColor: 0xFF8C8678,
        divisions: 6,
        jitter: 0.2,
      );
      expect(noisy.colors.toSet().length, greaterThan(plain.colors.toSet().length));
      expect(noisy.triangleCount, plain.triangleCount);
    });
  });

  group('model palette', () {
    test('slots are unique, labelled and every id resolves to a mesh', () {
      final AssetLoader assets = AssetLoader.instance..registerDefaultSlots();
      final List<AssetSlot> slots = assets.slots;
      expect(slots.length, greaterThan(30));

      final Set<String> ids = <String>{};
      for (final AssetSlot slot in slots) {
        expect(ids.add(slot.id), isTrue, reason: 'duplicate slot id ${slot.id}');
        expect(slot.label, isNotEmpty);
        expect(slot.source, isNotEmpty);
        // Even with nothing downloaded, the palette must hand back geometry.
        expect(assets.model(slot.id).triangleCount, greaterThan(0), reason: slot.id);
      }
    });

    test('fighters, creatures, bosses and props are all covered', () {
      final AssetLoader assets = AssetLoader.instance..registerDefaultSlots();
      final Set<String> ids = assets.slots.map((AssetSlot slot) => slot.id).toSet();
      for (final String prefix in <String>['fighter_', 'creature_', 'boss_', 'prop_', 'arena_', 'marker_']) {
        expect(
          ids.any((String id) => id.startsWith(prefix)),
          isTrue,
          reason: 'no slot covers $prefix',
        );
      }
      expect(ids.contains('weapon_sword'), isTrue);
      expect(ids.contains('khronos_fox'), isTrue);
    });

    test('procedural slots carry no file path and default to unit scale', () {
      final AssetLoader assets = AssetLoader.instance..registerDefaultSlots();
      for (final AssetSlot slot in assets.slots) {
        if (slot.id.startsWith('marker_')) {
          expect(slot.assetPath, isEmpty);
          expect(slot.origin, AssetOrigin.procedural);
        }
        expect(assets.normalisationScale(slot.id), greaterThan(0));
      }
    });

    test('unknown ids fall back to a placeholder instead of throwing', () {
      final AssetLoader assets = AssetLoader.instance..registerDefaultSlots();
      final Model3D missing = assets.model('not_a_real_slot');
      expect(missing.triangleCount, greaterThan(0));
    });

    test('texture slots describe a real file each', () {
      final AssetLoader assets = AssetLoader.instance..registerTextureSlots();
      expect(assets.textureSlots.length, greaterThanOrEqualTo(5));
      final Set<String> ids = <String>{};
      for (final TextureSlot slot in assets.textureSlots) {
        expect(ids.add(slot.id), isTrue, reason: slot.id);
        expect(slot.path, startsWith('assets/textures/'));
        expect(slot.path, endsWith('.jpg'));
        expect(slot.usage, isNotEmpty);
        // Nothing has been decoded in a unit test, so this must be a clean null.
        expect(assets.texture(slot.id), isNull);
      }
    });
  });

  group('arena layout', () {
    test('the same seed builds the same arena twice', () {
      final ArenaLayout3D first = ArenaLayout3D.build(map: Maps.dustPit, seed: 1234);
      final ArenaLayout3D second = ArenaLayout3D.build(map: Maps.dustPit, seed: 1234);
      expect(first.props.length, second.props.length);
      for (int i = 0; i < first.props.length; i++) {
        expect(first.props[i].slotId, second.props[i].slotId);
        expect(first.props[i].position.x, closeTo(second.props[i].position.x, 1e-9));
        expect(first.props[i].position.z, closeTo(second.props[i].position.z, 1e-9));
      }
      final ArenaLayout3D other = ArenaLayout3D.build(map: Maps.dustPit, seed: 99);
      expect(other.props.length, first.props.length);
      expect(
        other.props.any((PropPlacement prop) =>
            (prop.position.x - first.props.first.position.x).abs() > 1e-6),
        isTrue,
        reason: 'a different seed should scatter props differently',
      );
    });

    test('every map produces a walkable ring with blocking props', () {
      for (final GameMapDef map in Maps.all) {
        final ArenaLayout3D layout = ArenaLayout3D.build(map: map, seed: map.id.length);
        expect(layout.props.length, greaterThan(20), reason: map.id);
        expect(layout.props.any((PropPlacement prop) => prop.blocking), isTrue, reason: map.id);
        expect(layout.halfExtent, greaterThan(10), reason: map.id);
        expect(layout.isInside(Vector3.zero()), isTrue, reason: map.id);
        expect(layout.isInside(Vector3(500, 0, 0)), isFalse, reason: map.id);
      }
    });

    test('resolve keeps actors in bounds and pushes them out of props', () {
      final ArenaLayout3D layout = ArenaLayout3D.build(map: Maps.emberForge, seed: 7);
      final Vector3 far = layout.resolve(Vector3(400, 0, -400));
      expect(layout.isInside(far), isTrue);

      final PropPlacement blocker =
          layout.props.firstWhere((PropPlacement prop) => prop.blocking);
      final Vector3 pushed = layout.resolve(blocker.position.clone());
      final double dx = pushed.x - blocker.position.x;
      final double dz = pushed.z - blocker.position.z;
      expect(dx * dx + dz * dz, greaterThan(0.01),
          reason: 'standing inside a pillar must be corrected');
      expect(layout.clearanceAt(blocker.position.x, blocker.position.z), closeTo(0, 1e-6));
    });
  });

  group('camera', () {
    test('projects in front of the camera and rejects what is behind it', () {
      final CameraController3D camera = CameraController3D(distance: 12, focus: Vector3.zero());
      camera.updateViewport(400, 800);
      final ui.Offset? centre = camera.project(Vector3.zero());
      expect(centre, isNotNull);
      expect(centre!.dx, closeTo(200, 1));
      expect(camera.depthOf(Vector3.zero()), greaterThan(0));
      // A point far behind the eye is culled.
      final Vector3 behind = camera.eye + (camera.eye - Vector3.zero()).normalized().scaled(50);
      expect(camera.project(behind), isNull);
      expect(camera.depthOf(behind), lessThan(camera.near));
    });

    test('zoom and orbit stay inside their limits', () {
      final CameraController3D camera = CameraController3D();
      camera.updateViewport(360, 640);
      camera.zoom(500);
      expect(camera.distance, camera.minDistance);
      camera.zoom(-500);
      expect(camera.distance, camera.maxDistance);
      for (int i = 0; i < 200; i++) {
        camera.orbit(50, 50);
      }
      expect(camera.pitch, lessThanOrEqualTo(1.35));
      for (int i = 0; i < 200; i++) {
        camera.orbit(-50, -50);
      }
      expect(camera.pitch, greaterThanOrEqualTo(0.25));
    });

    test('follow eases towards the target and can snap', () {
      final CameraController3D camera = CameraController3D(focus: Vector3.zero());
      camera.follow(Vector3(10, 0, 0), 0.016);
      expect(camera.focus.x, greaterThan(0));
      expect(camera.focus.x, lessThan(10));
      camera.follow(Vector3(10, 2, 0), 0.016, snap: true);
      expect(camera.focus.x, 10);
      expect(camera.focus.y, 2);
    });
  });

  group('renderer', () {
    test('instance transform combines yaw, scale and ground offset', () {
      final Model3D block = ProceduralMeshes.block();
      final MeshInstance instance = MeshInstance(
        model: block,
        position: Vector3(3, 0, -2),
        yaw: 0,
        scale: 2,
        modelScale: 0.5,
        yOffset: 0.25,
      );
      expect(instance.effectiveScale, closeTo(1, 1e-9));
      final Matrix4 transform = instance.buildTransform();
      expect(transform.storage[12], closeTo(3, 1e-6));
      expect(transform.storage[13], closeTo(0.25, 1e-6));
      expect(transform.storage[14], closeTo(-2, 1e-6));
      expect(transform.storage[0], closeTo(1, 1e-6));
    });

    test('draws a batched frame into a picture and reports its stats', () {
      final CameraController3D camera = CameraController3D(distance: 18);
      camera.updateViewport(360, 640);
      final Renderer3D renderer = Renderer3D(lighting: LightingRig(fogEnd: 60));
      final List<MeshInstance> instances = <MeshInstance>[
        MeshInstance(model: ProceduralMeshes.humanoid()),
        MeshInstance(
          model: ProceduralMeshes.quadruped(),
          position: Vector3(2, 0, 1),
          modelScale: 1.4,
        ),
        MeshInstance(model: ProceduralMeshes.column(), position: Vector3(-3, 0, 2)),
        // Invisible instances must not be counted.
        MeshInstance(model: ProceduralMeshes.block(), visible: false),
      ];
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      renderer.render(canvas, const ui.Size(360, 640), camera, instances);
      final ui.Picture picture = recorder.endRecording();
      picture.dispose();

      expect(renderer.lastInstanceCount, 3);
      expect(renderer.lastTriangleCount, greaterThan(0));
      expect(renderer.lastTriangleCount, lessThanOrEqualTo(renderer.maxTriangles));
    });

    test('an empty scene is drawn without touching the triangle budget', () {
      final CameraController3D camera = CameraController3D();
      final Renderer3D renderer = Renderer3D();
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      renderer.render(
        ui.Canvas(recorder),
        const ui.Size(320, 480),
        camera,
        const <MeshInstance>[],
      );
      recorder.endRecording().dispose();
      expect(renderer.lastInstanceCount, 0);
      expect(renderer.lastTriangleCount, 0);
    });
  });

  group('scene manager', () {
    test('builds an arena and spawns palette models with ground snapping', () {
      final AssetLoader assets = AssetLoader.instance..registerDefaultSlots();
      final ArenaLayout3D layout = ArenaLayout3D.build(map: Maps.jadeTemple, seed: 3);
      final SceneManager3D scene = SceneManager3D(layout: layout, assets: assets);

      scene.buildArena();
      expect(scene.scenery.length, greaterThanOrEqualTo(layout.props.length));

      final MeshInstance actor = scene.spawn('fighter_warrior', Vector3(2, 0, 2), actor: true);
      expect(scene.actors.length, 1);
      expect(actor.yOffset, lessThanOrEqualTo(0));
      expect(actor.effectiveScale, greaterThan(0));

      // Frame bookkeeping: the notifier ticks once per advance.
      int ticks = 0;
      void listener() => ticks++;
      scene.frame.addListener(listener);
      scene.advance(1 / 60);
      scene.advance(1 / 60);
      expect(ticks, 2);
      expect(scene.clock, closeTo(2 / 60, 1e-9));
      expect(scene.fps, greaterThanOrEqualTo(0));
      scene.frame.removeListener(listener);
      scene.dispose();
    });

    test('an arena renders to a picture, scenery included', () {
      final AssetLoader assets = AssetLoader.instance..registerDefaultSlots();
      final ArenaLayout3D layout = ArenaLayout3D.build(map: Maps.dustPit, seed: 5, halfExtent: 16);
      final SceneManager3D scene = SceneManager3D(layout: layout, assets: assets);
      scene.buildArena();
      scene.spawn('fighter_warrior', Vector3.zero());
      scene.camera.distance = 14;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      scene.render(ui.Canvas(recorder), const ui.Size(400, 700));
      recorder.endRecording().dispose();
      expect(scene.renderer.lastInstanceCount, greaterThan(5));
      expect(scene.renderer.lastTriangleCount, greaterThan(0));
      scene.dispose();
    });
  });

  group('audio catalogue', () {
    test('lists the bundled cues with unique ids and real paths', () {
      expect(AudioCatalog.sfx.length, greaterThanOrEqualTo(8));
      expect(AudioCatalog.music.length, greaterThanOrEqualTo(4));
      final Set<String> ids = <String>{};
      for (final AudioAsset asset in AudioCatalog.all) {
        expect(ids.add(asset.id), isTrue, reason: asset.id);
        expect(asset.path, startsWith('assets/audio/'));
        expect(asset.path, endsWith('.ogg'));
        expect(asset.usage, isNotEmpty);
        expect(AudioCatalog.byId(asset.id), same(asset));
      }
      expect(AudioCatalog.all.length, AudioCatalog.sfx.length + AudioCatalog.music.length);
      expect(AudioCatalog.byId('nope'), isNull);
      for (final AudioAsset asset in AudioCatalog.music) {
        expect(asset.music, isTrue);
      }
    });
  });
}
