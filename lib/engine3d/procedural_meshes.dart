import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import 'gltf_loader.dart';
import 'math3d.dart';

/// Accumulates flat-shaded triangles and hands back an immutable [Model3D].
///
/// Everything the engine draws is a triangle soup with one colour per vertex,
/// so every primitive here emits its own vertices (no sharing) with the exact
/// face normal. That keeps the shading crisp and the code simple.
class MeshBuilder {
  MeshBuilder();

  final List<double> _positions = <double>[];
  final List<double> _normals = <double>[];
  final List<int> _colors = <int>[];
  final List<int> _indices = <int>[];

  int get vertexCount => _colors.length;

  int get triangleCount => _indices.length ~/ 3;

  int _vertex(Vector3 position, Vector3 normal, int color) {
    _positions.addAll(<double>[position.x, position.y, position.z]);
    _normals.addAll(<double>[normal.x, normal.y, normal.z]);
    _colors.add(color);
    return _colors.length - 1;
  }

  /// Adds one flat triangle, computing the face normal when [normal] is null.
  void addTriangle(Vector3 a, Vector3 b, Vector3 c, int color, {Vector3? normal}) {
    final Vector3 n = normal ?? _faceNormal(a, b, c);
    final int i0 = _vertex(a, n, color);
    final int i1 = _vertex(b, n, color);
    final int i2 = _vertex(c, n, color);
    _indices.addAll(<int>[i0, i1, i2]);
  }

  /// Adds a quad as two triangles, wound a-b-c-d.
  void addQuad(Vector3 a, Vector3 b, Vector3 c, Vector3 d, int color, {Vector3? normal}) {
    final Vector3 n = normal ?? _faceNormal(a, b, c);
    final int i0 = _vertex(a, n, color);
    final int i1 = _vertex(b, n, color);
    final int i2 = _vertex(c, n, color);
    final int i3 = _vertex(d, n, color);
    _indices.addAll(<int>[i0, i1, i2, i0, i2, i3]);
  }

  /// Axis-aligned box, optionally transformed. `center` is in local space.
  void addBox({
    required Vector3 center,
    required Vector3 size,
    required int color,
    Matrix4? transform,
    int? topColor,
  }) {
    final double hx = size.x / 2;
    final double hy = size.y / 2;
    final double hz = size.z / 2;

    void face(Vector3 a, Vector3 b, Vector3 c, Vector3 d, Vector3 normal, int faceColor) {
      if (transform != null) {
        // Points are rebuilt relative to the centre so the matrix acts on the
        // box as a whole rather than on absolute coordinates.
        final Matrix4 m = transform;
        a = _apply(m, center, a);
        b = _apply(m, center, b);
        c = _apply(m, center, c);
        d = _apply(m, center, d);
        final Vector3 rotated = normal.clone();
        m.applyToVector3(rotated);
        normal = rotated.normalized();
      }
      addQuad(a, b, c, d, faceColor, normal: normal);
    }

    // +X / -X
    face(center + Vector3(hx, -hy, hz), center + Vector3(hx, -hy, -hz),
        center + Vector3(hx, hy, -hz), center + Vector3(hx, hy, hz),
        Vector3(1, 0, 0), color);
    face(center + Vector3(-hx, -hy, -hz), center + Vector3(-hx, -hy, hz),
        center + Vector3(-hx, hy, hz), center + Vector3(-hx, hy, -hz),
        Vector3(-1, 0, 0), color);
    // +Y (top) / -Y (bottom)
    face(center + Vector3(-hx, hy, hz), center + Vector3(hx, hy, hz),
        center + Vector3(hx, hy, -hz), center + Vector3(-hx, hy, -hz),
        Vector3(0, 1, 0), topColor ?? color);
    face(center + Vector3(-hx, -hy, -hz), center + Vector3(hx, -hy, -hz),
        center + Vector3(hx, -hy, hz), center + Vector3(-hx, -hy, hz),
        Vector3(0, -1, 0), color);
    // +Z / -Z
    face(center + Vector3(-hx, -hy, hz), center + Vector3(hx, -hy, hz),
        center + Vector3(hx, hy, hz), center + Vector3(-hx, hy, hz),
        Vector3(0, 0, 1), color);
    face(center + Vector3(hx, -hy, -hz), center + Vector3(-hx, -hy, -hz),
        center + Vector3(-hx, hy, -hz), center + Vector3(hx, hy, -hz),
        Vector3(0, 0, -1), color);
  }

  static Vector3 _apply(Matrix4 m, Vector3 center, Vector3 point) {
    final Vector3 local = point - center;
    m.applyToVector3(local);
    return local + center;
  }

  /// Vertical cylinder or cone (set [topRadius] to 0 for a cone).
  void addCylinder({
    required Vector3 base,
    required double bottomRadius,
    required double topRadius,
    required double height,
    required int color,
    int segments = 10,
    int? topColor,
    Vector3? tilt,
  }) {
    final Vector3 axis = (tilt ?? Vector3(0, 1, 0)).normalized();
    Vector3 right = axis.cross(Vector3(0, 0, 1));
    if (right.length2 < 0.0001) {
      right = axis.cross(Vector3(1, 0, 0));
    }
    right.normalize();
    final Vector3 forward = axis.cross(right).normalized();

    Vector3 ring(double radius, double h, double angle) {
      return base +
          axis.scaled(h) +
          right.scaled(math.cos(angle) * radius) +
          forward.scaled(math.sin(angle) * radius);
    }

    final int bodyColor = color;
    for (int i = 0; i < segments; i++) {
      final double a0 = (i / segments) * math.pi * 2;
      final double a1 = ((i + 1) / segments) * math.pi * 2;
      final Vector3 b0 = ring(bottomRadius, 0, a0);
      final Vector3 b1 = ring(bottomRadius, 0, a1);
      final Vector3 t0 = ring(topRadius, height, a0);
      final Vector3 t1 = ring(topRadius, height, a1);
      if (topRadius <= 0.0001) {
        addTriangle(b0, t0, b1, bodyColor);
      } else {
        addQuad(b0, b1, t1, t0, bodyColor);
      }
    }
    // Caps.
    final Vector3 bottomCenter = base;
    for (int i = 0; i < segments; i++) {
      final double a0 = (i / segments) * math.pi * 2;
      final double a1 = ((i + 1) / segments) * math.pi * 2;
      addTriangle(
        bottomCenter,
        ring(bottomRadius, 0, a1),
        ring(bottomRadius, 0, a0),
        topColor ?? bodyColor,
        normal: axis.scaled(-1),
      );
      if (topRadius > 0.0001) {
        addTriangle(
          base + axis.scaled(height),
          ring(topRadius, height, a0),
          ring(topRadius, height, a1),
          topColor ?? bodyColor,
          normal: axis,
        );
      }
    }
  }

  /// Low-poly sphere (latitude/longitude bands, flat shaded).
  void addSphere({
    required Vector3 center,
    required double radius,
    required int color,
    int longitude = 10,
    int latitude = 6,
    double squashY = 1,
  }) {
    for (int lat = 0; lat < latitude; lat++) {
      final double p0 = math.pi * (lat / latitude) - math.pi / 2;
      final double p1 = math.pi * ((lat + 1) / latitude) - math.pi / 2;
      for (int lon = 0; lon < longitude; lon++) {
        final double t0 = math.pi * 2 * (lon / longitude);
        final double t1 = math.pi * 2 * ((lon + 1) / longitude);
        Vector3 point(double phi, double theta) {
          final double c = math.cos(phi);
          return center +
              Vector3(c * math.cos(theta) * radius, math.sin(phi) * radius * squashY, c * math.sin(theta) * radius);
        }

        final Vector3 a = point(p0, t0);
        final Vector3 b = point(p0, t1);
        final Vector3 c = point(p1, t1);
        final Vector3 d = point(p1, t0);
        if (lat == 0) {
          addTriangle(a, d, c, color);
        } else if (lat == latitude - 1) {
          addTriangle(a, d, b, color);
        } else {
          addQuad(a, d, c, b, color);
        }
      }
    }
  }

  Model3D build({required String name, String? source}) {
    final Float32List positions = Float32List.fromList(_positions);
    final Float32List normals = Float32List.fromList(_normals);
    final Int32List colors = Int32List.fromList(_colors);
    final Uint32List indices = Uint32List.fromList(_indices);
    return Model3D(
      name: name,
      source: source ?? 'procedural:$name',
      positions: positions,
      normals: normals,
      colors: colors,
      indices: indices,
      bounds: _bounds(positions),
      textured: false,
    );
  }

  static Bounds3 _bounds(Float32List positions) {
    if (positions.isEmpty) {
      return Math3d.emptyBounds;
    }
    double minX = positions[0], minY = positions[1], minZ = positions[2];
    double maxX = minX, maxY = minY, maxZ = minZ;
    for (int i = 0; i + 2 < positions.length; i += 3) {
      final double x = positions[i], y = positions[i + 1], z = positions[i + 2];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }
    return Bounds3(Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ));
  }

  static Vector3 _faceNormal(Vector3 a, Vector3 b, Vector3 c) {
    final Vector3 n = (b - a).cross(c - a);
    if (n.length2 < 0.0000001) {
      return Vector3(0, 1, 0);
    }
    return n.normalized();
  }
}

/// Procedural stand-ins.
///
/// The arena never depends on a download: if a model file is missing the engine
/// swaps in one of these builders, so the game is playable from a bare checkout
/// and still looks deliberate rather than broken.
class ProceduralMeshes {
  const ProceduralMeshes._();

  /// Humanoid warrior built from boxes, used when no character model loads.
  static Model3D humanoid({String name = 'warrior', int skin = 0xFFD8B48C, int cloth = 0xFF7C2D12}) {
    final MeshBuilder b = MeshBuilder();
    b.addBox(center: Vector3(0, 0.55, 0), size: Vector3(0.34, 0.62, 0.24), color: cloth);
    b.addBox(center: Vector3(0, 0.72, 0.02), size: Vector3(0.42, 0.22, 0.3), color: 0xFFB45309);
    b.addBox(center: Vector3(0, 1.05, 0), size: Vector3(0.3, 0.3, 0.28), color: skin);
    b.addBox(center: Vector3(0, 1.28, 0), size: Vector3(0.34, 0.12, 0.32), color: 0xFF3F6212);
    b.addBox(center: Vector3(0.24, 0.62, 0.06), size: Vector3(0.12, 0.5, 0.12), color: skin);
    b.addBox(center: Vector3(-0.24, 0.62, 0.06), size: Vector3(0.12, 0.5, 0.12), color: skin);
    b.addBox(center: Vector3(0.11, 0.12, 0), size: Vector3(0.14, 0.5, 0.16), color: 0xFF44403C);
    b.addBox(center: Vector3(-0.11, 0.12, 0), size: Vector3(0.14, 0.5, 0.16), color: 0xFF44403C);
    return b.build(name: name);
  }

  /// Four-legged creature with a head, tail and (optionally) wings.
  static Model3D quadruped({
    String name = 'beast',
    int body = 0xFF8A6A3B,
    int accent = 0xFF5A3E1B,
    double scale = 1,
    bool wings = false,
    bool horned = false,
  }) {
    final MeshBuilder b = MeshBuilder();
    b.addSphere(center: Vector3(0, 0.42 * scale, 0), radius: 0.36 * scale, color: body, squashY: 0.8);
    b.addSphere(center: Vector3(0.42 * scale, 0.56 * scale, 0), radius: 0.2 * scale, color: body);
    b.addCylinder(
      base: Vector3(0.62 * scale, 0.54 * scale, 0),
      bottomRadius: 0.1 * scale,
      topRadius: 0.06 * scale,
      height: 0.16 * scale,
      color: accent,
      tilt: Vector3(1, 0.2, 0),
    );
    for (final double dx in <double>[0.24, -0.24]) {
      for (final double dz in <double>[0.2, -0.2]) {
        b.addBox(
          center: Vector3(dx * scale, 0.14 * scale, dz * scale),
          size: Vector3(0.11 * scale, 0.3 * scale, 0.11 * scale),
          color: accent,
        );
      }
    }
    b.addCylinder(
      base: Vector3(-0.34 * scale, 0.5 * scale, 0),
      bottomRadius: 0.06 * scale,
      topRadius: 0.02 * scale,
      height: 0.42 * scale,
      color: accent,
      tilt: Vector3(-1, 0.5, 0),
    );
    if (horned) {
      b.addCylinder(
        base: Vector3(0.5 * scale, 0.72 * scale, 0),
        bottomRadius: 0.05 * scale,
        topRadius: 0,
        height: 0.24 * scale,
        color: 0xFFF5F1EA,
      );
    }
    if (wings) {
      for (final double side in <double>[-1, 1]) {
        b.addQuad(
          Vector3(0, 0.5 * scale, side * 0.2 * scale),
          Vector3(-0.3 * scale, 0.5 * scale, side * 0.2 * scale),
          Vector3(-0.16 * scale, 0.86 * scale, side * 0.78 * scale),
          Vector3(0.16 * scale, 0.78 * scale, side * 0.5 * scale),
          accent,
        );
      }
    }
    return b.build(name: name);
  }

  /// Simple tree (trunk + two canopies).
  static Model3D tree({String name = 'tree', int foliage = 0xFF3F6212}) {
    final MeshBuilder b = MeshBuilder();
    b.addCylinder(base: Vector3.zero(), bottomRadius: 0.18, topRadius: 0.12, height: 1.2, color: 0xFF5A3E1B);
    b.addSphere(center: Vector3(0, 1.5, 0), radius: 0.66, color: foliage, squashY: 0.92);
    b.addSphere(center: Vector3(0.18, 2.0, 0.1), radius: 0.46, color: foliage);
    return b.build(name: name);
  }

  /// Rocky boulder.
  static Model3D rock({String name = 'rock', int color = 0xFF8C8678, double radius = 0.5}) {
    final MeshBuilder b = MeshBuilder();
    b.addSphere(center: Vector3(0, radius * 0.7, 0), radius: radius, color: color, squashY: 0.78, longitude: 8, latitude: 4);
    b.addSphere(center: Vector3(radius * 0.5, radius * 0.4, radius * 0.4), radius: radius * 0.5, color: color, longitude: 6, latitude: 3);
    return b.build(name: name);
  }

  /// Stone column, used for the arena ring and ruined scenery.
  static Model3D column({String name = 'column', int color = 0xFFD6CFC0, double height = 2.6}) {
    final MeshBuilder b = MeshBuilder();
    b.addBox(center: Vector3(0, height * 0.05, 0), size: Vector3(0.8, 0.14, 0.8), color: color);
    b.addCylinder(
      base: Vector3(0, 0.12, 0),
      bottomRadius: 0.28,
      topRadius: 0.24,
      height: height * 0.86,
      color: color,
      segments: 8,
    );
    b.addBox(center: Vector3(0, height * 0.94, 0), size: Vector3(0.8, 0.16, 0.8), color: color);
    return b.build(name: name);
  }

  /// Flat ground plate with a subtle border lip.
  static Model3D groundTile({String name = 'ground', int color = 0xFFE3D8BF, double size = 2}) {
    final MeshBuilder b = MeshBuilder();
    b.addBox(
      center: Vector3(0, -0.05, 0),
      size: Vector3(size, 0.1, size),
      color: color,
      topColor: color,
    );
    return b.build(name: name);
  }

  /// Square stone block used for arena walls and stairs.
  static Model3D block({String name = 'block', int color = 0xFFC9BFA8}) {
    final MeshBuilder b = MeshBuilder();
    b.addBox(center: Vector3(0, 0.5, 0), size: Vector3(1, 1, 1), color: color);
    return b.build(name: name);
  }

  /// Fallback for any named slot: a tinted capsule-ish blob.
  static Model3D placeholder({String name = 'placeholder', int color = 0xFFB45309}) {
    final MeshBuilder b = MeshBuilder();
    b.addSphere(center: Vector3(0, 0.5, 0), radius: 0.42, color: color);
    b.addBox(center: Vector3(0, 0.12, 0), size: Vector3(0.5, 0.24, 0.5), color: color);
    return b.build(name: name);
  }

  /// Straw training target: post, body and two painted rings.
  static Model3D cylinderTarget({String name = 'target'}) {
    final MeshBuilder b = MeshBuilder();
    b.addCylinder(base: Vector3.zero(), bottomRadius: 0.12, topRadius: 0.12, height: 0.6, color: 0xFF5A3E1B);
    b.addCylinder(
      base: Vector3(0, 0.55, 0),
      bottomRadius: 0.34,
      topRadius: 0.34,
      height: 0.9,
      color: 0xFFC9A227,
      segments: 10,
    );
    b.addCylinder(
      base: Vector3(0, 0.85, 0),
      bottomRadius: 0.345,
      topRadius: 0.345,
      height: 0.14,
      color: 0xFFB91C1C,
      segments: 10,
    );
    b.addCylinder(
      base: Vector3(0, 1.12, 0),
      bottomRadius: 0.345,
      topRadius: 0.345,
      height: 0.14,
      color: 0xFFB91C1C,
      segments: 10,
    );
    return b.build(name: name);
  }

  /// Sword prop (blade + guard + grip).
  static Model3D sword({String name = 'sword', int blade = 0xFFD6D3D1, int hilt = 0xFF7C2D12}) {
    final MeshBuilder b = MeshBuilder();
    b.addBox(center: Vector3(0, 0.9, 0), size: Vector3(0.08, 1.0, 0.22), color: blade);
    b.addBox(center: Vector3(0, 0.36, 0), size: Vector3(0.34, 0.08, 0.1), color: hilt);
    b.addBox(center: Vector3(0, 0.22, 0), size: Vector3(0.09, 0.26, 0.09), color: 0xFF44403C);
    return b.build(name: name);
  }

  /// Plain colour plate, used for shadows and hazard telegraphs.
  /// A large ground quad subdivided into a grid.
  ///
  /// Each cell asks [sampler] for the colour at its centre - `u` and `v` run
  /// over 0..1 - and is blended with [baseColor] by [mix]. Without a sampler the
  /// whole plate is [baseColor]. This is how a downloaded surface texture ends
  /// up on screen without a GPU sampler.
  static Model3D groundPlane({
    String name = 'ground_plane',
    required double size,
    required int baseColor,
    int divisions = 24,
    int Function(double u, double v)? sampler,
    double mix = 0.55,
    double jitter = 0,
    int seed = 7,
  }) {
    final MeshBuilder b = MeshBuilder();
    final double step = size / divisions;
    final double half = size / 2;
    double random = seed * 0.61803398875;
    for (int z = 0; z < divisions; z++) {
      for (int x = 0; x < divisions; x++) {
        final double x0 = -half + x * step;
        final double z0 = -half + z * step;
        final double u = (x + 0.5) / divisions;
        final double v = (z + 0.5) / divisions;
        int cell = baseColor;
        if (sampler != null) {
          cell = Math3d.tint(baseColor, 1, mixWith: sampler(u, v), mix: mix);
        }
        if (jitter > 0) {
          random = (random * 9301 + 49297) % 233280;
          final double delta = (random / 233280 - 0.5) * jitter;
          cell = Math3d.tint(cell, 1 + delta);
        }
        b.addQuad(
          Vector3(x0, 0, z0 + step),
          Vector3(x0 + step, 0, z0 + step),
          Vector3(x0 + step, 0, z0),
          Vector3(x0, 0, z0),
          cell,
          normal: Vector3(0, 1, 0),
        );
      }
    }
    return b.build(name: name);
  }

  static Model3D plate({String name = 'plate', required int color, double size = 1}) {
    final MeshBuilder b = MeshBuilder();
    b.addQuad(
      Vector3(-size / 2, 0, size / 2),
      Vector3(size / 2, 0, size / 2),
      Vector3(size / 2, 0, -size / 2),
      Vector3(-size / 2, 0, -size / 2),
      color,
      normal: Vector3(0, 1, 0),
    );
    return b.build(name: name);
  }

  /// Convenience wrapper so a [Color] can be passed straight through.
  static int argb(Color color) {
    return (0xFF << 24) |
        ((color.r * 255).round() << 16) |
        ((color.g * 255).round() << 8) |
        (color.b * 255).round();
  }
}
