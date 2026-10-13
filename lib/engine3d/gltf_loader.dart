import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_math/vector_math_64.dart';

import 'math3d.dart';

/// A mesh that is ready to be drawn: flat triangle soup in model space with one
/// ARGB colour per vertex.
///
/// Colours are baked at load time instead of being sampled from a texture at
/// draw time. The engine draws with [ui.Canvas.drawVertices], which has no
/// perspective-correct texturing, so sampling each vertex out of the model's
/// palette texture once gives clean, correct-looking low-poly art at a fraction
/// of the cost - and it lets a whole model batch into a single draw call.
@immutable
class Model3D {
  const Model3D({
    required this.name,
    required this.source,
    required this.positions,
    required this.normals,
    required this.colors,
    required this.indices,
    required this.bounds,
    required this.textured,
  });

  /// Asset name or procedural id.
  final String name;

  /// Where the geometry came from (asset path, or `procedural:<name>`).
  final String source;

  /// xyz per vertex, model space.
  final Float32List positions;

  /// Unit normal per vertex.
  final Float32List normals;

  /// Packed ARGB colour per vertex.
  final Int32List colors;

  /// Triangle list.
  final Uint32List indices;

  final Bounds3 bounds;

  /// True when per-vertex colours were sampled from a texture atlas.
  final bool textured;

  int get vertexCount => colors.length;

  int get triangleCount => indices.length ~/ 3;

  /// Approximate memory footprint in bytes (used by the asset report screen).
  int get byteSize =>
      positions.lengthInBytes + normals.lengthInBytes + colors.lengthInBytes + indices.lengthInBytes;

  String get sizeLabel {
    final double kb = byteSize / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(0)} KB';
    }
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }
}

/// Decoded RGBA pixels for one texture atlas.
class _Texture {
  _Texture(this.width, this.height, this.pixels);

  final int width;
  final int height;
  final Uint8List pixels;

  /// Nearest-neighbour fetch with wrapping, matching glTF's default sampler.
  int argbAt(double u, double v) {
    double fu = u - u.floorToDouble();
    double fv = v - v.floorToDouble();
    int x = (fu * width).floor();
    int y = (fv * height).floor();
    x = x.clamp(0, width - 1);
    y = y.clamp(0, height - 1);
    final int i = (y * width + x) * 4;
    return (0xFF << 24) | (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
  }
}

/// Minimal glTF 2.0 / GLB reader.
///
/// Scope is deliberately narrow: it understands the parts of the format the
/// project actually ships - binary GLB containers, TRS node hierarchies,
/// indexed triangle primitives, per-vertex normals and UVs, external palette
/// textures, and material base colours. Skins, morph targets, animation
/// samplers and PBR extensions are ignored: the game renders meshes in their
/// bind pose, which is exactly what a top-down arena fighter needs.
class GltfLoader {
  GltfLoader._();

  static const int _magicGlb = 0x46546C67;
  static const int _chunkJson = 0x4E4F534A;
  static const int _chunkBin = 0x004E4942;

  /// Loads a model from an asset path. [onWarn] receives human readable notes
  /// for anything that was skipped (surfaced on the asset report screen).
  static Future<Model3D?> loadAsset(
    String assetPath, {
    String? name,
    void Function(String message)? onWarn,
  }) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      return await loadBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        assetPath: assetPath,
        name: name ?? assetPath.split('/').last.replaceAll('.glb', ''),
        onWarn: onWarn,
      );
    } catch (error) {
      onWarn?.call('could not read $assetPath ($error)');
      return null;
    }
  }

  /// Parses GLB bytes that were already read from disk or the bundle.
  static Future<Model3D?> loadBytes(
    Uint8List bytes, {
    required String assetPath,
    required String name,
    void Function(String message)? onWarn,
  }) async {
    final _Document? doc = _parse(bytes, onWarn);
    if (doc == null) {
      return null;
    }

    // ---- flatten the node hierarchy into world-space triangles -----------
    final List<_Piece> pieces = <_Piece>[];
    final List<int> sceneRoots = doc.sceneNodes;
    for (final int root in sceneRoots) {
      _walk(doc, root, Matrix4.identity(), pieces, onWarn);
    }
    if (pieces.isEmpty) {
      onWarn?.call('$name has no renderable meshes');
      return null;
    }

    // ---- bake colours (texture sample or material factor) ----------------
    final _PaletteCache palettes = _PaletteCache(assetPath, onWarn);
    int vertexTotal = 0;
    int indexTotal = 0;
    for (final _Piece piece in pieces) {
      vertexTotal += piece.positions.length ~/ 3;
      indexTotal += piece.indices.length;
    }

    final Float32List positions = Float32List(vertexTotal * 3);
    final Float32List normals = Float32List(vertexTotal * 3);
    final Int32List colors = Int32List(vertexTotal);
    final Uint32List indices = Uint32List(indexTotal);

    int vertexCursor = 0;
    int indexCursor = 0;
    bool anyTextured = false;

    for (final _Piece piece in pieces) {
      final int base = vertexCursor;
      final int verts = piece.positions.length ~/ 3;

      final _Texture? texture = await palettes.resolve(piece.textureUri);
      final bool textured = texture != null && piece.uvs != null;

      for (int i = 0; i < verts; i++) {
        final int p = (vertexCursor * 3);
        positions[p] = piece.positions[i * 3];
        positions[p + 1] = piece.positions[i * 3 + 1];
        positions[p + 2] = piece.positions[i * 3 + 2];
        normals[p] = piece.normals[i * 3];
        normals[p + 1] = piece.normals[i * 3 + 1];
        normals[p + 2] = piece.normals[i * 3 + 2];

        if (textured) {
          final Float32List uv = piece.uvs!;
          colors[vertexCursor] = texture.argbAt(uv[i * 2], uv[i * 2 + 1]);
          anyTextured = true;
        } else {
          colors[vertexCursor] = piece.fallbackColor;
        }
        vertexCursor++;
      }

      for (int i = 0; i < piece.indices.length; i++) {
        indices[indexCursor + i] = piece.indices[i] + base;
      }
      indexCursor += piece.indices.length;
    }

    final Bounds3 bounds = _boundsOf(positions);
    return Model3D(
      name: name,
      source: assetPath,
      positions: positions,
      normals: normals,
      colors: colors,
      indices: indices,
      bounds: bounds,
      textured: anyTextured,
    );
  }

  // ------------------------------------------------------------------ parsing

  static _Document? _parse(Uint8List bytes, void Function(String)? onWarn) {
    if (bytes.length < 20) {
      onWarn?.call('file is too small to be a GLB');
      return null;
    }
    final ByteData view = ByteData.sublistView(bytes);
    if (view.getUint32(0, Endian.little) != _magicGlb) {
      onWarn?.call('not a binary glTF container');
      return null;
    }

    Map<String, dynamic>? json;
    Uint8List? bin;
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final int chunkLength = view.getUint32(offset, Endian.little);
      final int chunkType = view.getUint32(offset + 4, Endian.little);
      final int start = offset + 8;
      final int end = start + chunkLength;
      if (end > bytes.length) {
        onWarn?.call('truncated chunk in GLB');
        break;
      }
      if (chunkType == _chunkJson) {
        try {
          final Object? decoded = jsonDecode(utf8.decode(bytes.sublist(start, end)));
          if (decoded is Map<String, dynamic>) {
            json = decoded;
          }
        } catch (error) {
          onWarn?.call('invalid glTF JSON ($error)');
        }
      } else if (chunkType == _chunkBin) {
        bin = bytes.sublist(start, end);
      }
      offset = end;
    }

    if (json == null) {
      onWarn?.call('no JSON chunk found');
      return null;
    }
    if (bin == null) {
      onWarn?.call('no binary chunk - external .bin buffers are not supported');
      return null;
    }
    return _Document(json, bin);
  }

  /// Depth-first node walk that accumulates transforms into [_Piece]s.
  static void _walk(
    _Document doc,
    int nodeIndex,
    Matrix4 parent,
    List<_Piece> out,
    void Function(String)? onWarn,
  ) {
    final List<dynamic> nodes = doc.nodes;
    if (nodeIndex < 0 || nodeIndex >= nodes.length) {
      return;
    }
    final Map<String, dynamic> node = nodes[nodeIndex] as Map<String, dynamic>;
    final Matrix4 local = doc.nodeMatrix(node);
    final Matrix4 world = parent.clone()..multiply(local);

    final Object? meshIndex = node['mesh'];
    if (meshIndex is int) {
      final Matrix4 normalMatrix = Matrix4.copy(world)..invert();
      normalMatrix.transpose();
      final List<Map<String, dynamic>> primitives = doc.primitivesOf(meshIndex);
      for (final Map<String, dynamic> primitive in primitives) {
        final _Piece? piece = doc.buildPiece(primitive, world, normalMatrix, onWarn);
        if (piece != null) {
          out.add(piece);
        }
      }
    }

    final Object? children = node['children'];
    if (children is List) {
      for (final Object? child in children) {
        if (child is int) {
          _walk(doc, child, world, out, onWarn);
        }
      }
    }
  }

  static Bounds3 _boundsOf(Float32List positions) {
    if (positions.isEmpty) {
      return Math3d.emptyBounds;
    }
    double minX = positions[0], minY = positions[1], minZ = positions[2];
    double maxX = minX, maxY = minY, maxZ = minZ;
    for (int i = 0; i + 2 < positions.length; i += 3) {
      final double x = positions[i];
      final double y = positions[i + 1];
      final double z = positions[i + 2];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (z < minZ) minZ = z;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      if (z > maxZ) maxZ = z;
    }
    return Bounds3(Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ));
  }
}

/// One primitive already transformed into the model's root space.
class _Piece {
  _Piece({
    required this.positions,
    required this.normals,
    required this.indices,
    required this.uvs,
    required this.textureUri,
    required this.fallbackColor,
  });

  final Float32List positions;
  final Float32List normals;
  final Uint32List indices;
  final Float32List? uvs;
  final String? textureUri;
  final int fallbackColor;
}

/// Loads and caches texture atlases, resolving `uri` values relative to the
/// folder the model was loaded from (Kenney kits reference
/// `Textures/colormap.png` next to the .glb).
class _PaletteCache {
  _PaletteCache(this.assetPath, this.onWarn);

  final String assetPath;
  final void Function(String)? onWarn;
  final Map<String, _Texture?> _cache = <String, _Texture?>{};

  Future<_Texture?> resolve(String? uri) async {
    if (uri == null || uri.isEmpty) {
      return null;
    }
    if (_cache.containsKey(uri)) {
      return _cache[uri];
    }
    _Texture? texture;
    final int baseSlash = assetPath.lastIndexOf('/');
    final String folder = baseSlash < 0 ? '' : assetPath.substring(0, baseSlash + 1);
    final String path = '$folder${uri.startsWith('/') ? uri.substring(1) : uri}';
    try {
      final ByteData bytes = await rootBundle.load(path);
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      final ByteData? rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba != null) {
        texture = _Texture(image.width, image.height, rgba.buffer.asUint8List());
      }
      image.dispose();
      codec.dispose();
    } catch (error) {
      onWarn?.call('texture $path missing ($error)');
      texture = null;
    }
    _cache[uri] = texture;
    return texture;
  }
}

/// Thin wrapper over the decoded glTF JSON with typed accessors.
class _Document {
  _Document(this.json, this.bin);

  final Map<String, dynamic> json;
  final Uint8List bin;

  List<dynamic> get nodes => (json['nodes'] as List<dynamic>?) ?? const <dynamic>[];

  List<dynamic> get _accessors => (json['accessors'] as List<dynamic>?) ?? const <dynamic>[];

  List<dynamic> get _bufferViews => (json['bufferViews'] as List<dynamic>?) ?? const <dynamic>[];

  int get _bufferViewCount => _bufferViews.length;

  /// Root nodes of the default scene.
  List<int> get sceneNodes {
    final List<dynamic> scenes = (json['scenes'] as List<dynamic>?) ?? const <dynamic>[];
    final int sceneIndex = (json['scene'] as int?) ?? 0;
    if (scenes.isEmpty || sceneIndex >= scenes.length) {
      return <int>[];
    }
    final Map<String, dynamic> scene = scenes[sceneIndex] as Map<String, dynamic>;
    final List<dynamic> roots = (scene['nodes'] as List<dynamic>?) ?? const <dynamic>[];
    return roots.whereType<int>().toList();
  }

  Matrix4 nodeMatrix(Map<String, dynamic> node) {
    final Object? matrix = node['matrix'];
    if (matrix is List && matrix.length == 16) {
      return Matrix4.fromList(matrix.cast<num>().map((num n) => n.toDouble()).toList());
    }
    final List<double> t = _vec3(node['translation'], 0, 0, 0);
    final List<double> s = _vec3(node['scale'], 1, 1, 1);
    final List<double> r = _vec4(node['rotation'], 0, 0, 0, 1);
    return Matrix4.compose(
      Vector3(t[0], t[1], t[2]),
      Quaternion(r[0], r[1], r[2], r[3]),
      Vector3(s[0], s[1], s[2]),
    );
  }

  /// Scratch vector reused while transforming whole vertex arrays.
  final Vector3 _scratch = Vector3.zero();

  /// Applies a full affine transform to a point (w = 1).
  ///
  /// Written out against `Matrix4.storage` instead of the vector_math helpers so
  /// the maths is explicit and does not depend on a particular helper name.
  static void _applyPoint(Matrix4 m, double x, double y, double z, Vector3 out) {
    final List<double> s = m.storage;
    out.setValues(
      s[0] * x + s[4] * y + s[8] * z + s[12],
      s[1] * x + s[5] * y + s[9] * z + s[13],
      s[2] * x + s[6] * y + s[10] * z + s[14],
    );
  }

  /// Applies the rotational part of a transform to a direction (w = 0).
  static void _applyDirection(Matrix4 m, double x, double y, double z, Vector3 out) {
    final List<double> s = m.storage;
    out.setValues(
      s[0] * x + s[4] * y + s[8] * z,
      s[1] * x + s[5] * y + s[9] * z,
      s[2] * x + s[6] * y + s[10] * z,
    );
  }

  static List<double> _vec3(Object? value, double dx, double dy, double dz) {
    if (value is List && value.length >= 3) {
      return <double>[
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
        (value[2] as num).toDouble(),
      ];
    }
    return <double>[dx, dy, dz];
  }

  static List<double> _vec4(Object? value, double dx, double dy, double dz, double dw) {
    if (value is List && value.length >= 4) {
      return <double>[
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble(),
        (value[2] as num).toDouble(),
        (value[3] as num).toDouble(),
      ];
    }
    return <double>[dx, dy, dz, dw];
  }

  List<Map<String, dynamic>> primitivesOf(int meshIndex) {
    final List<dynamic> meshes = (json['meshes'] as List<dynamic>?) ?? const <dynamic>[];
    if (meshIndex < 0 || meshIndex >= meshes.length) {
      return const <Map<String, dynamic>>[];
    }
    final Map<String, dynamic> mesh = meshes[meshIndex] as Map<String, dynamic>;
    final List<dynamic> primitives = (mesh['primitives'] as List<dynamic>?) ?? const <dynamic>[];
    return primitives.whereType<Map<String, dynamic>>().toList();
  }

  /// Reads one accessor as interleaved doubles.
  Float32List _readAccessor(int accessorIndex, int components) {
    if (accessorIndex < 0 || accessorIndex >= _accessors.length) {
      return Float32List(0);
    }
    final Map<String, dynamic> accessor = _accessors[accessorIndex] as Map<String, dynamic>;
    final int count = (accessor['count'] as int?) ?? 0;
    final int componentType = (accessor['componentType'] as int?) ?? 5126;
    final Object? bvIndex = accessor['bufferView'];
    if (bvIndex is! int || bvIndex < 0 || bvIndex >= _bufferViewCount) {
      return Float32List(0);
    }
    final Map<String, dynamic> bufferView = _bufferViews[bvIndex] as Map<String, dynamic>;
    final int viewOffset = (bufferView['byteOffset'] as int?) ?? 0;
    final int? byteStride = bufferView['byteStride'] as int?;
    final int accessorOffset = (accessor['byteOffset'] as int?) ?? 0;

    final int componentSize = _componentSize(componentType);
    final int elementSize = componentSize * components;
    final int stride = byteStride ?? elementSize;
    final Float32List out = Float32List(count * components);
    final ByteData data = ByteData.sublistView(bin);

    for (int i = 0; i < count; i++) {
      final int elementOffset = viewOffset + accessorOffset + i * stride;
      for (int c = 0; c < components; c++) {
        final int byteOffset = elementOffset + c * componentSize;
        double value;
        if (byteOffset + componentSize > bin.length) {
          value = 0;
        } else {
          switch (componentType) {
            case 5126: // FLOAT
              value = data.getFloat32(byteOffset, Endian.little);
              break;
            case 5123: // UNSIGNED_SHORT
              value = data.getUint16(byteOffset, Endian.little).toDouble();
              break;
            case 5125: // UNSIGNED_INT
              value = data.getUint32(byteOffset, Endian.little).toDouble();
              break;
            case 5122: // SHORT
              value = data.getInt16(byteOffset, Endian.little).toDouble();
              break;
            case 5121: // UNSIGNED_BYTE
              value = data.getUint8(byteOffset).toDouble();
              break;
            case 5120: // BYTE
              value = data.getInt8(byteOffset).toDouble();
              break;
            default:
              value = 0;
          }
        }
        out[i * components + c] = value;
      }
    }
    return out;
  }

  static int _componentSize(int componentType) {
    switch (componentType) {
      case 5126:
        return 4;
      case 5125:
        return 4;
      case 5123:
        return 2;
      case 5122:
        return 2;
      case 5121:
        return 1;
      case 5120:
        return 1;
      default:
        return 4;
    }
  }

  /// Builds a [_Piece] in root space from one glTF primitive.
  _Piece? buildPiece(
    Map<String, dynamic> primitive,
    Matrix4 transform,
    Matrix4 normalMatrix,
    void Function(String)? onWarn,
  ) {
    final Object? attributes = primitive['attributes'];
    if (attributes is! Map<String, dynamic>) {
      return null;
    }
    final Object? positionIndex = attributes['POSITION'];
    if (positionIndex is! int) {
      return null;
    }

    final Float32List rawPositions = _readAccessor(positionIndex, 3);
    final int verts = rawPositions.length ~/ 3;
    if (verts == 0) {
      return null;
    }

    final Float32List positions = Float32List(verts * 3);
    final Float32List normals = Float32List(verts * 3);
    for (int i = 0; i < verts; i++) {
      _applyPoint(
        transform,
        rawPositions[i * 3],
        rawPositions[i * 3 + 1],
        rawPositions[i * 3 + 2],
        _scratch,
      );
      positions[i * 3] = _scratch.x;
      positions[i * 3 + 1] = _scratch.y;
      positions[i * 3 + 2] = _scratch.z;
    }

    final Object? normalIndex = attributes['NORMAL'];
    if (normalIndex is int) {
      final Float32List raw = _readAccessor(normalIndex, 3);
      for (int i = 0; i < verts && i * 3 + 2 < raw.length; i++) {
        _applyDirection(
          normalMatrix,
          raw[i * 3],
          raw[i * 3 + 1],
          raw[i * 3 + 2],
          _scratch,
        );
        if (_scratch.length2 > 0.000001) {
          _scratch.normalize();
        } else {
          _scratch.setValues(0, 1, 0);
        }
        normals[i * 3] = _scratch.x;
        normals[i * 3 + 1] = _scratch.y;
        normals[i * 3 + 2] = _scratch.z;
      }
    } else {
      for (int i = 0; i < verts; i++) {
        normals[i * 3] = 0;
        normals[i * 3 + 1] = 1;
        normals[i * 3 + 2] = 0;
      }
    }

    Float32List? uvs;
    final Object? uvIndex = attributes['TEXCOORD_0'];
    if (uvIndex is int) {
      final Float32List raw = _readAccessor(uvIndex, 2);
      if (raw.length >= verts * 2) {
        uvs = raw;
      }
    }

    // Indices: always expanded to a triangle list.
    Uint32List indices;
    final Object? indexAccessor = primitive['indices'];
    if (indexAccessor is int) {
      final Float32List raw = _readAccessor(indexAccessor, 1);
      final int mode = (primitive['mode'] as int?) ?? 4;
      indices = _toTriangleList(raw, mode, verts, onWarn);
    } else {
      indices = Uint32List(verts);
      for (int i = 0; i < verts; i++) {
        indices[i] = i;
      }
    }
    if (indices.isEmpty) {
      return null;
    }

    final String? textureUri = _baseColorTextureUri(primitive);
    return _Piece(
      positions: positions,
      normals: normals,
      indices: indices,
      uvs: uvs,
      textureUri: textureUri,
      fallbackColor: _baseColorFactor(primitive),
    );
  }

  static Uint32List _toTriangleList(
    Float32List raw,
    int mode,
    int verts,
    void Function(String)? onWarn,
  ) {
    switch (mode) {
      case 4: // TRIANGLES
        final Uint32List out = Uint32List(raw.length);
        for (int i = 0; i < raw.length; i++) {
          out[i] = raw[i].toInt();
        }
        return out;
      case 5: // TRIANGLE_STRIP
        if (raw.length < 3) {
          return Uint32List(0);
        }
        final List<int> strip = <int>[];
        for (int i = 0; i + 2 < raw.length; i++) {
          final int a = raw[i].toInt();
          final int b = raw[i + 1].toInt();
          final int c = raw[i + 2].toInt();
          if (i.isEven) {
            strip.addAll(<int>[a, b, c]);
          } else {
            strip.addAll(<int>[b, a, c]);
          }
        }
        return Uint32List.fromList(strip);
      case 6: // TRIANGLE_FAN
        if (raw.length < 3) {
          return Uint32List(0);
        }
        final List<int> fan = <int>[];
        for (int i = 1; i + 1 < raw.length; i++) {
          fan.addAll(<int>[raw[0].toInt(), raw[i].toInt(), raw[i + 1].toInt()]);
        }
        return Uint32List.fromList(fan);
      default:
        onWarn?.call('primitive mode $mode is not a triangle list - skipped');
        return Uint32List(0);
    }
  }

  /// Resolves the base colour texture uri for a primitive, if it has one.
  String? _baseColorTextureUri(Map<String, dynamic> primitive) {
    final Object? materialIndex = primitive['material'];
    if (materialIndex is! int) {
      return null;
    }
    final List<dynamic> materials = (json['materials'] as List<dynamic>?) ?? const <dynamic>[];
    if (materialIndex < 0 || materialIndex >= materials.length) {
      return null;
    }
    final Map<String, dynamic> material = materials[materialIndex] as Map<String, dynamic>;
    final Object? pbr = material['pbrMetallicRoughness'];
    if (pbr is! Map<String, dynamic>) {
      return null;
    }
    final Object? baseColorTexture = pbr['baseColorTexture'];
    if (baseColorTexture is! Map<String, dynamic>) {
      return null;
    }
    final Object? textureIndex = baseColorTexture['index'];
    if (textureIndex is! int) {
      return null;
    }
    final List<dynamic> textures = (json['textures'] as List<dynamic>?) ?? const <dynamic>[];
    if (textureIndex < 0 || textureIndex >= textures.length) {
      return null;
    }
    final Map<String, dynamic> texture = textures[textureIndex] as Map<String, dynamic>;
    final Object? source = texture['source'];
    if (source is! int) {
      return null;
    }
    final List<dynamic> images = (json['images'] as List<dynamic>?) ?? const <dynamic>[];
    if (source < 0 || source >= images.length) {
      return null;
    }
    final Map<String, dynamic> image = images[source] as Map<String, dynamic>;
    final Object? uri = image['uri'];
    if (uri is String && !uri.startsWith('data:')) {
      return uri;
    }
    return null;
  }

  /// Material base colour, used when a primitive has no palette texture.
  int _baseColorFactor(Map<String, dynamic> primitive) {
    const int fallback = 0xFFB9B0A0;
    final Object? materialIndex = primitive['material'];
    if (materialIndex is! int) {
      return fallback;
    }
    final List<dynamic> materials = (json['materials'] as List<dynamic>?) ?? const <dynamic>[];
    if (materialIndex < 0 || materialIndex >= materials.length) {
      return fallback;
    }
    final Map<String, dynamic> material = materials[materialIndex] as Map<String, dynamic>;
    final Object? pbr = material['pbrMetallicRoughness'];
    if (pbr is! Map<String, dynamic>) {
      return fallback;
    }
    final Object? factor = pbr['baseColorFactor'];
    if (factor is! List || factor.length < 3) {
      return fallback;
    }
    double linearToSrgb(double value) {
      // glTF stores linear values; the Canvas expects sRGB bytes.
      final double c = value.clamp(0.0, 1.0);
      return c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
    }

    final int r = (linearToSrgb((factor[0] as num).toDouble()) * 255).round();
    final int g = (linearToSrgb((factor[1] as num).toDouble()) * 255).round();
    final int b = (linearToSrgb((factor[2] as num).toDouble()) * 255).round();
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }
}
