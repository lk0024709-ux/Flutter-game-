import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

/// Small numeric helpers shared by the 3D layer.
///
/// Everything visual in Blade Brawl is authored with the warm palette from
/// [AppColors], so the maths here stays deliberately plain: no HDR, no colour
/// spaces, just enough to light a low-poly mesh convincingly on a Canvas.
class Math3d {
  const Math3d._();

  /// Axis-aligned box in model space, used to scale and centre loaded models.
  static const Bounds3 emptyBounds = Bounds3._empty();

  /// Linear interpolation that also accepts an extrapolation-free factor.
  static double lerp(double a, double b, double t) => a + (b - a) * t;

  /// Shortest signed angle from [from] to [to] in radians.
  static double angleDelta(double from, double to) {
    double delta = (to - from) % (math.pi * 2);
    if (delta > math.pi) {
      delta -= math.pi * 2;
    }
    if (delta < -math.pi) {
      delta += math.pi * 2;
    }
    return delta;
  }

  /// Turns `current` towards `target` by at most `maxStep` radians.
  static double approachAngle(double current, double target, double maxStep) {
    final double delta = angleDelta(current, target);
    if (delta.abs() <= maxStep) {
      return target;
    }
    return current + delta.sign * maxStep;
  }
}

/// Immutable model-space bounding box.
class Bounds3 {
  const Bounds3(this.min, this.max);

  const Bounds3._empty()
      : min = const Vector3(0, 0, 0),
        max = const Vector3(0, 0, 0);

  final Vector3 min;
  final Vector3 max;

  Vector3 get center => (min + max).scaled(0.5);

  Vector3 get size => max - min;

  /// Largest axis, handy for normalising imported models to a target height.
  double get maxExtent => math.max(size.x, math.max(size.y, size.z));

  double get height => size.y;

  /// Scale factor that makes the model exactly [target] units tall.
  double scaleToHeight(double target) {
    final double h = size.y;
    if (h <= 0.0001) {
      return 1;
    }
    return target / h;
  }
}

/// A single directional light plus ambient fill and distance fog.
///
/// The engine keeps one rig per scene. Values are intentionally gentle: the
/// premium look depends on soft, believable shading rather than strong contrast.
class LightingRig {
  LightingRig({
    Vector3? direction,
    this.ambient = 0.55,
    this.diffuse = 0.65,
    this.fogColor = const Color(0xFFF5F1EA),
    this.fogStart = 14,
    this.fogEnd = 46,
    this.fogStrength = 0.85,
    this.groundBounce = 0.12,
  }) : direction = (direction ?? Vector3(-0.45, -1, -0.35)).normalized();

  /// Direction the light travels, in world space (points away from the sun).
  final Vector3 direction;

  /// Minimum brightness of a surface facing away from the light.
  final double ambient;

  /// Extra brightness for a surface facing the light head-on.
  final double diffuse;

  final Color fogColor;
  final double fogStart;
  final double fogEnd;

  /// How strongly distance fades towards [fogColor] (0 disables the fog).
  final double fogStrength;

  /// A touch of upward fill so tops of objects never read as pure black.
  final double groundBounce;

  /// Lambert term for a world-space normal, in the 0..1 range.
  double lambert(Vector3 normal) {
    final double d = -normal.dot(direction);
    return d.clamp(0.0, 1.0);
  }

  /// 0..1 fog factor for a view-space depth.
  double fogFactor(double depth) {
    if (fogStrength <= 0 || depth <= fogStart) {
      return 0;
    }
    final double t = ((depth - fogStart) / (fogEnd - fogStart)).clamp(0.0, 1.0);
    return t * fogStrength;
  }

  /// Shades an ARGB colour for a triangle, returning a packed ARGB value.
  int shade(int argb, double lambertTerm, double fogFactor) {
    final int a = (argb >> 24) & 0xFF;
    int r = (argb >> 16) & 0xFF;
    int g = (argb >> 8) & 0xFF;
    int b = argb & 0xFF;

    final double light = ambient + diffuse * lambertTerm + groundBounce * (1 - lambertTerm);
    double rr = r * light;
    double gg = g * light;
    double bb = b * light;

    if (fogFactor > 0) {
      final int fr = (fogColor.r * 255).round();
      final int fg = (fogColor.g * 255).round();
      final int fb = (fogColor.b * 255).round();
      rr = rr + (fr - rr) * fogFactor;
      gg = gg + (fg - gg) * fogFactor;
      bb = bb + (fb - bb) * fogFactor;
    }

    r = rr.clamp(0, 255).round();
    g = gg.clamp(0, 255).round();
    b = bb.clamp(0, 255).round();
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Multiplies a packed ARGB colour by a flat factor (used for selection tints
  /// and damage flashes).
  static int tint(int argb, double factor, {int? mixWith, double mix = 0}) {
    int r = (argb >> 16) & 0xFF;
    int g = (argb >> 8) & 0xFF;
    int b = argb & 0xFF;
    r = (r * factor).clamp(0, 255).round();
    g = (g * factor).clamp(0, 255).round();
    b = (b * factor).clamp(0, 255).round();
    if (mixWith != null && mix > 0) {
      final int mr = (mixWith >> 16) & 0xFF;
      final int mg = (mixWith >> 8) & 0xFF;
      final int mb = mixWith & 0xFF;
      r = (r + (mr - r) * mix).clamp(0, 255).round();
      g = (g + (mg - g) * mix).clamp(0, 255).round();
      b = (b + (mb - b) * mix).clamp(0, 255).round();
    }
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }
}
