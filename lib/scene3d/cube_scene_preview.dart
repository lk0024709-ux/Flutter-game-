import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A small, real Flutter Scene view used in the Forge hero while the 3D arena
/// is assembled. SceneView owns the frame ticker and camera updates.
class CubeScenePreview extends StatefulWidget {
  const CubeScenePreview({super.key});

  @override
  State<CubeScenePreview> createState() => _CubeScenePreviewState();
}

class _CubeScenePreviewState extends State<CubeScenePreview> {
  late final Scene _scene;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scene = Scene();
    _prepareScene();
  }

  Future<void> _prepareScene() async {
    try {
      await Scene.initializeStaticResources();
      final platform = Node(
        name: 'forge-preview-platform',
        mesh: Mesh(
          PlaneGeometry(width: 3.8, depth: 3.8),
          _material(const Color(0xFFBDA47C), roughness: 0.94),
        ),
      );
      final cube = Node(
        name: 'procedural-preview-cube',
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(1.25, 1.25, 1.25)),
          _material(const Color(0xFFD79543), metallic: 0.08, roughness: 0.72),
        ),
      )..position = vm.Vector3(0, 0.865, 0);
      final plinth = Node(
        name: 'stone-plinth',
        mesh: Mesh(
          CuboidGeometry(vm.Vector3(1.8, 0.24, 1.8)),
          _material(const Color(0xFF5E4A38), roughness: 0.92),
        ),
      )..position = vm.Vector3(0, 0.12, 0);

      _scene.addAll([platform, plinth, cube]);
      if (!mounted) return;
      setState(() => _ready = true);
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  PhysicallyBasedMaterial _material(
    Color color, {
    double metallic = 0,
    double roughness = 0.86,
  }) {
    return PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(
        color.r,
        color.g,
        color.b,
        1,
      )
      ..metallicFactor = metallic
      ..roughnessFactor = roughness;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Icon(Icons.view_in_ar_rounded, color: Color(0xFFE9C99C), size: 48),
      );
    }
    if (!_ready) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFE9C99C),
          ),
        ),
      );
    }

    return SceneView(
      _scene,
      pixelRatio: 0.85,
      cameraBuilder: (elapsed) {
        final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
        final angle = seconds * 0.24;
        return PerspectiveCamera(
          position: vm.Vector3(math.sin(angle) * 4.5, 3.3, math.cos(angle) * 4.5),
          target: vm.Vector3(0, 0.865, 0),
        );
      },
    );
  }
}
