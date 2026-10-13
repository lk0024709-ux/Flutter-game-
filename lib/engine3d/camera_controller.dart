import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

/// Orbit camera for the arena.
///
/// Battles are read top-down with a slight tilt: high enough to see the whole
/// fight, low enough that the imported models read as 3D objects instead of
/// flat sprites. The camera follows the player smoothly and can be pushed
/// around by dragging.
class CameraController3D {
  CameraController3D({
    Vector3? focus,
    this.yaw = -0.62,
    this.pitch = 0.82,
    this.distance = 13.5,
    this.fovY = 0.86,
    this.near = 0.6,
    this.far = 260,
  }) : focus = focus ?? Vector3.zero();

  /// World point the camera looks at (usually the player, slightly lifted).
  final Vector3 focus;

  /// Rotation around Y in radians.
  double yaw;

  /// Elevation above the horizon in radians (clamped to 0.25..1.35).
  double pitch;

  /// Distance from [focus].
  double distance;

  /// Vertical field of view in radians.
  double fovY;

  final double near;
  final double far;

  double minDistance = 7;
  double maxDistance = 26;

  /// View matrix, rebuilt by [updateViewport]. Read-only for the renderer.
  final Matrix4 view = Matrix4.identity();

  final Vector3 _eye = Vector3.zero();

  double _parallelScale = 1;
  double _viewportWidth = 1;
  double _viewportHeight = 1;

  /// World-space position of the camera.
  Vector3 get eye => _eye;

  /// `1 / tan(fovY / 2)` for the current viewport.
  double get focal => _parallelScale;

  /// Rebuilds the view matrix for the current viewport.
  void updateViewport(double viewportWidth, double viewportHeight) {
    _viewportWidth = math.max(1.0, viewportWidth);
    _viewportHeight = math.max(1.0, viewportHeight);
    _parallelScale = 1 / math.tan(fovY / 2);

    final double cosPitch = math.cos(pitch);
    final Vector3 offset = Vector3(
      math.sin(yaw) * cosPitch,
      math.sin(pitch),
      math.cos(yaw) * cosPitch,
    ).scaled(distance);
    _eye.setFrom(focus + offset);

    // A slight lift on the look-at point keeps the horizon above the middle of
    // the screen, which reads much better for a top-down arena.
    final Vector3 target = focus + Vector3(0, 0.9, 0);
    setViewMatrix(view, _eye, target, Vector3(0, 1, 0));
  }

  /// Rotates the camera by a drag delta in logical pixels.
  void orbit(double dx, double dy) {
    yaw -= dx * 0.0075;
    pitch = (pitch + dy * 0.0055).clamp(0.25, 1.35);
  }

  /// Zooms by a drag/scroll delta in logical pixels.
  void zoom(double delta) {
    distance = (distance - delta).clamp(minDistance, maxDistance);
  }

  /// Eases the focus towards a world point.
  void follow(Vector3 target, double dt, {double speed = 6, bool snap = false}) {
    if (snap) {
      focus.setFrom(target);
      return;
    }
    final double t = (dt * speed).clamp(0.0, 1.0);
    focus.setValues(
      focus.x + (target.x - focus.x) * t,
      focus.y + (target.y - focus.y) * t,
      focus.z + (target.z - focus.z) * t,
    );
  }

  /// Screen position of a world point. Returns null when it is behind the
  /// camera, which callers use to hide off-screen markers.
  Offset? project(Vector3 world) {
    final List<double> m = view.storage;
    final double vx = m[0] * world.x + m[4] * world.y + m[8] * world.z + m[12];
    final double vy = m[1] * world.x + m[5] * world.y + m[9] * world.z + m[13];
    final double vz = m[2] * world.x + m[6] * world.y + m[10] * world.z + m[14];
    final double depth = -vz;
    if (depth <= near) {
      return null;
    }
    final double aspect = _viewportWidth / _viewportHeight;
    final double sx = (vx * _parallelScale / aspect / depth * 0.5 + 0.5) * _viewportWidth;
    final double sy = (0.5 - vy * _parallelScale / depth * 0.5) * _viewportHeight;
    return Offset(sx, sy);
  }

  /// Depth of a world point along the view direction (positive in front).
  double depthOf(Vector3 world) {
    final List<double> m = view.storage;
    return -(m[2] * world.x + m[6] * world.y + m[10] * world.z + m[14]);
  }
}
