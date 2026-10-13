import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import 'camera_controller.dart';
import 'gltf_loader.dart';
import 'math3d.dart';

/// One drawable: a model placed in the world.
class MeshInstance {
  MeshInstance({
    required this.model,
    Vector3? position,
    this.yaw = 0,
    this.scale = 1,
    this.tint = 0xFFFFFFFF,
    this.tintMix = 0,
    this.showShadow = true,
    this.shadowRadius = 0.5,
    this.visible = true,
    this.modelScale,
    this.yOffset = 0,
  }) : position = position ?? Vector3.zero();

  final Model3D model;
  final Vector3 position;

  /// Extra per-model scale (used to normalise imported models to a target
  /// height); set once when the instance is created.
  final double? modelScale;

  double yaw;

  double scale;

  /// Vertical offset so models placed on the ground sit on it.
  double yOffset;

  /// ARGB colour mixed into the lit result (selection rings, damage flashes).
  int tint;

  /// How strongly [tint] replaces the lit colour (0 = none, 1 = full).
  double tintMix;

  bool showShadow;
  double shadowRadius;
  bool visible;

  /// Effective world scale including the model normalisation factor.
  double get effectiveScale => scale * (modelScale ?? 1);

  /// Cached world transform, rebuilt by the renderer each frame.
  final Matrix4 transform = Matrix4.identity();

  /// World matrix: yaw about Y, uniform scale, then translation.
  ///
  /// Written straight into `Matrix4.storage` (column-major) so the pipeline
  /// does not depend on any deprecated or renamed vector_math helper.
  Matrix4 buildTransform() {
    final double s = effectiveScale;
    final double c = math.cos(yaw) * s;
    final double sn = math.sin(yaw) * s;
    final List<double> m = transform.storage;
    m[0] = c;
    m[1] = 0;
    m[2] = -sn;
    m[3] = 0;
    m[4] = 0;
    m[5] = s;
    m[6] = 0;
    m[7] = 0;
    m[8] = sn;
    m[9] = 0;
    m[10] = c;
    m[11] = 0;
    m[12] = position.x;
    m[13] = position.y + yOffset;
    m[14] = position.z;
    m[15] = 1;
    return transform;
  }
}

/// Software 3D renderer built on [Canvas.drawVertices].
///
/// Why not a GPU path: the published three_js stack now depends on the
/// experimental `flutter_gpu` library plus manual OpenGL ES setup, which cannot
/// be validated from a headless CI build. This renderer keeps the whole
/// pipeline in Dart - transform, cull, light, depth-sort, one batched draw call
/// - so it compiles anywhere Flutter runs and still produces real perspective
/// geometry with flat shading, distance fog and soft contact shadows.
class Renderer3D {
  Renderer3D({LightingRig? lighting, this.maxTriangles = 26000})
      : lighting = lighting ?? LightingRig();

  LightingRig lighting;

  /// Hard budget per frame; instances past the budget are skipped.
  final int maxTriangles;

  // Reusable per-frame buffers (grown on demand, never freed per frame).
  final List<double> _triDepth = <double>[];
  final List<double> _triScreen = <double>[];
  final List<int> _triColor = <int>[];
  final List<int> _order = <int>[];
  final Vector3 _viewPoint = Vector3.zero();
  final Vector3 _normal = Vector3.zero();

  int _lastTriangleCount = 0;
  int _lastInstanceCount = 0;

  /// Triangles submitted in the most recent frame (used by the debug overlay).
  int get lastTriangleCount => _lastTriangleCount;

  /// Instances drawn in the most recent frame.
  int get lastInstanceCount => _lastInstanceCount;

  /// Draws every visible instance into [canvas].
  void render(
    Canvas canvas,
    Size size,
    CameraController3D camera,
    List<MeshInstance> instances,
  ) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    camera.updateViewport(size.width, size.height);

    _triDepth.clear();
    _triScreen.clear();
    _triColor.clear();
    _order.clear();

    final List<double> view = camera.view.storage;
    final double focal = camera.focal;
    final double halfWidth = size.width / 2;
    final double halfHeight = size.height / 2;

    // A vertical-FOV perspective projection is isotropic in pixels, so both
    // axes share one scale factor.
    final double pixelScale = focal * halfHeight;

    int drawnInstances = 0;
    int triangles = 0;

    for (final MeshInstance instance in instances) {
      if (!instance.visible) {
        continue;
      }
      final Model3D model = instance.model;
      if (model.triangleCount == 0) {
        continue;
      }
      if (triangles + model.triangleCount > maxTriangles) {
        continue;
      }

      final Matrix4 modelMatrix = instance.buildTransform();
      final List<double> ms = modelMatrix.storage;
      final List<double> combined = _multiply(view, ms);

      // Bounding-sphere reject against the near/far planes.
      final Vector3 centre = model.bounds.center;
      _transformPoint(combined, centre.x, centre.y, centre.z, _viewPoint);
      final double radius = model.bounds.maxExtent * 0.5 * instance.effectiveScale + 0.4;
      final double centreDepth = -_viewPoint.z;
      if (centreDepth + radius < camera.near || centreDepth - radius > camera.far) {
        continue;
      }
      // Sub-pixel reject in real pixels: the projected radius is
      // `radius * focal * halfHeight / depth`, and anything smaller than a
      // pixel is invisible no matter how close the camera is.
      if (radius * pixelScale / (centreDepth - radius).clamp(0.001, 10000.0) < 0.75) {
        continue;
      }

      drawnInstances++;
      if (instance.showShadow) {
        _drawShadow(canvas, camera, instance, pixelScale);
      }

      final Float32List positions = model.positions;
      final Float32List normals = model.normals;
      final Int32List colors = model.colors;
      final Uint32List indices = model.indices;

      for (int t = 0; t + 2 < indices.length; t += 3) {
        final int i0 = indices[t];
        final int i1 = indices[t + 1];
        final int i2 = indices[t + 2];

        _transformPoint(combined, positions[i0 * 3], positions[i0 * 3 + 1], positions[i0 * 3 + 2], _viewPoint);
        final double z0 = -_viewPoint.z;
        if (z0 <= camera.near) {
          continue;
        }
        final double x0 = _viewPoint.x;
        final double y0 = _viewPoint.y;

        _transformPoint(combined, positions[i1 * 3], positions[i1 * 3 + 1], positions[i1 * 3 + 2], _viewPoint);
        final double z1 = -_viewPoint.z;
        if (z1 <= camera.near) {
          continue;
        }
        final double x1 = _viewPoint.x;
        final double y1 = _viewPoint.y;

        _transformPoint(combined, positions[i2 * 3], positions[i2 * 3 + 1], positions[i2 * 3 + 2], _viewPoint);
        final double z2 = -_viewPoint.z;
        if (z2 <= camera.near) {
          continue;
        }
        final double x2 = _viewPoint.x;
        final double y2 = _viewPoint.y;

        final double s0 = pixelScale / z0;
        final double s1 = pixelScale / z1;
        final double s2 = pixelScale / z2;
        final double sx0 = halfWidth + x0 * s0;
        final double sy0 = halfHeight - y0 * s0;
        final double sx1 = halfWidth + x1 * s1;
        final double sy1 = halfHeight - y1 * s1;
        final double sx2 = halfWidth + x2 * s2;
        final double sy2 = halfHeight - y2 * s2;

        // Reject triangles that sit entirely off-screen.
        if ((sx0 < -8 && sx1 < -8 && sx2 < -8) ||
            (sx0 > size.width + 8 && sx1 > size.width + 8 && sx2 > size.width + 8) ||
            (sy0 < -8 && sy1 < -8 && sy2 < -8) ||
            (sy0 > size.height + 8 && sy1 > size.height + 8 && sy2 > size.height + 8)) {
          continue;
        }

        // World-space face normal: the model matrix rotates the model-space
        // normal (any uniform scale is normalised away).
        final double nx = normals[i0 * 3] + normals[i1 * 3] + normals[i2 * 3];
        final double ny = normals[i0 * 3 + 1] + normals[i1 * 3 + 1] + normals[i2 * 3 + 1];
        final double nz = normals[i0 * 3 + 2] + normals[i1 * 3 + 2] + normals[i2 * 3 + 2];
        _normal.setValues(
          ms[0] * nx + ms[4] * ny + ms[8] * nz,
          ms[1] * nx + ms[5] * ny + ms[9] * nz,
          ms[2] * nx + ms[6] * ny + ms[10] * nz,
        );
        if (_normal.length2 > 0.000001) {
          _normal.normalize();
        } else {
          _normal.setValues(0, 1, 0);
        }

        final double lambert = lighting.lambert(_normal);
        final double depth = (z0 + z1 + z2) / 3;
        final double fog = lighting.fogFactor(depth);

        int base = colors[i0];
        if (instance.tintMix > 0) {
          base = LightingRig.tint(base, 1, mixWith: instance.tint, mix: instance.tintMix);
        }
        final int shaded = lighting.shade(base, lambert, fog);

        _triScreen.addAll(<double>[sx0, sy0, sx1, sy1, sx2, sy2]);
        _triColor.add(shaded);
        _triDepth.add(depth);
        _order.add(_triDepth.length - 1);
        triangles++;
      }
    }

    _lastTriangleCount = triangles;
    _lastInstanceCount = drawnInstances;
    if (triangles == 0) {
      return;
    }

    // Painter's algorithm: far triangles drawn first.
    _order.sort((int a, int b) => _triDepth[b].compareTo(_triDepth[a]));

    final Float32List outPositions = Float32List(triangles * 6);
    final Int32List outColors = Int32List(triangles * 3);
    int cursor = 0;
    int colorCursor = 0;
    for (final int index in _order) {
      final int s = index * 6;
      outPositions[cursor++] = _triScreen[s];
      outPositions[cursor++] = _triScreen[s + 1];
      outPositions[cursor++] = _triScreen[s + 2];
      outPositions[cursor++] = _triScreen[s + 3];
      outPositions[cursor++] = _triScreen[s + 4];
      outPositions[cursor++] = _triScreen[s + 5];
      final int color = _triColor[index];
      outColors[colorCursor++] = color;
      outColors[colorCursor++] = color;
      outColors[colorCursor++] = color;
    }

    canvas.drawVertices(
      Vertices(VertexMode.triangles, outPositions, colors: outColors),
      BlendMode.srcOver,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }

  /// Soft contact shadow: a squashed ellipse under the instance.
  void _drawShadow(
    Canvas canvas,
    CameraController3D camera,
    MeshInstance instance,
    double pixelScale,
  ) {
    final Offset? centre = camera.project(instance.position);
    if (centre == null) {
      return;
    }
    final double depth = camera.depthOf(instance.position);
    if (depth <= camera.near) {
      return;
    }
    final double radius = instance.shadowRadius * instance.effectiveScale;
    final double rx = radius * pixelScale / depth;
    final double ry = rx * 0.4;
    if (rx < 1.2 || ry < 0.8) {
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2),
      Paint()..color = const Color(0x1A000000),
    );
  }

  static void _transformPoint(List<double> s, double x, double y, double z, Vector3 out) {
    out.setValues(
      s[0] * x + s[4] * y + s[8] * z + s[12],
      s[1] * x + s[5] * y + s[9] * z + s[13],
      s[2] * x + s[6] * y + s[10] * z + s[14],
    );
  }

  /// Column-major 4x4 multiply (out = a * b).
  static List<double> _multiply(List<double> a, List<double> b) {
    final List<double> out = List<double>.filled(16, 0);
    for (int col = 0; col < 4; col++) {
      final int bc = col * 4;
      for (int row = 0; row < 4; row++) {
        out[bc + row] = a[row] * b[bc] +
            a[4 + row] * b[bc + 1] +
            a[8 + row] * b[bc + 2] +
            a[12 + row] * b[bc + 3];
      }
    }
    return out;
  }
}
