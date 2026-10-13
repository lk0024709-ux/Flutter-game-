import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show ByteData, rootBundle;

/// A decoded 8-bit RGBA image the software renderer can sample.
///
/// The engine has no GPU pipeline: surfaces are lit per triangle and coloured
/// per vertex, so a texture is consumed by sampling it while a mesh is built
/// (a tile of ground takes its colour from the stone or grass it represents).
/// The decoded [ui.Image] is kept so the UI can also draw the texture itself.
class BakedTexture {
  BakedTexture({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.pixels,
    required this.image,
    required this.source,
  });

  final String id;
  final String label;
  final int width;
  final int height;

  /// Raw RGBA bytes, `width * height * 4` of them.
  final Uint8List pixels;

  /// The decoded image, kept for previews.
  final ui.Image image;

  /// Attribution recorded in assets/LICENSES.txt.
  final String source;

  int get byteSize => pixels.length;

  String get sizeLabel =>
      '${width}x$height · ${(byteSize / 1024).toStringAsFixed(0)} KB';

  /// Nearest-neighbour sample in UV space; coordinates wrap, `v` runs from the
  /// top of the image so it matches the usual texture layout.
  int sampleArgb(double u, double v) {
    final double uu = u - u.floorToDouble();
    final double vv = v - v.floorToDouble();
    final int x = (uu * width).floor().clamp(0, width - 1);
    final int y = (vv * height).floor().clamp(0, height - 1);
    final int index = (y * width + x) * 4;
    return (pixels[index + 3] << 24) |
        (pixels[index] << 16) |
        (pixels[index + 1] << 8) |
        pixels[index + 2];
  }

  /// Samples on a coarse grid and mixes the results: cheap way to get a read of
  /// the whole texture without walking megapixels.
  int averageArgb({int steps = 8}) {
    int r = 0;
    int g = 0;
    int b = 0;
    int count = 0;
    for (int y = 0; y < steps; y++) {
      for (int x = 0; x < steps; x++) {
        final int argb = sampleArgb((x + 0.5) / steps, (y + 0.5) / steps);
        r += (argb >> 16) & 0xFF;
        g += (argb >> 8) & 0xFF;
        b += argb & 0xFF;
        count++;
      }
    }
    return 0xFF000000 |
        ((r ~/ count) << 16) |
        ((g ~/ count) << 8) |
        (b ~/ count);
  }
}

/// Decodes JPG/PNG files from `assets/` into [BakedTexture]s.
class TextureLoader {
  TextureLoader._();

  /// Decodes one asset. Never throws: a missing or corrupt file is reported
  /// through [onWarn] and returns null so the caller can keep a flat colour.
  static Future<BakedTexture?> loadAsset(
    String path, {
    required String id,
    String? label,
    String source = 'ambientCG (CC0 1.0) - https://ambientcg.com',
    void Function(String message)? onWarn,
  }) async {
    try {
      final ByteData data = await rootBundle.load(path);
      final Uint8List bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image image = frame.image;
      final ByteData? rgba =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) {
        onWarn?.call('$path decoded but produced no pixel data');
        return null;
      }
      return BakedTexture(
        id: id,
        label: label ?? id,
        width: image.width,
        height: image.height,
        pixels: rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
        image: image,
        source: source,
      );
    } catch (error) {
      onWarn?.call('texture $path unavailable ($error)');
      return null;
    }
  }
}
