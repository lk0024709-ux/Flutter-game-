import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../game/game_map.dart';

/// One prop placed in the arena.
class PropPlacement {
  const PropPlacement({
    required this.slotId,
    required this.position,
    required this.yaw,
    this.scale = 1,
    this.blocking = false,
  });

  /// Key into the model palette (AssetLoader).
  final String slotId;
  final Vector3 position;
  final double yaw;
  final double scale;

  /// Blocking props are kept out of the walkable centre ring.
  final bool blocking;
}

/// Deterministic arena layout.
///
/// The 3D arena reuses the same [GameMapDef] records as the 2D campaign, so a
/// rank's map (its palette, its twist flavour, its world size) drives the 3D
/// floor and prop mix too. Placement is seeded, which keeps a level's arena
/// identical between retries while still looking hand-scattered.
class ArenaLayout3D {
  ArenaLayout3D({
    required this.map,
    required this.floorColor,
    required this.accentColor,
    required this.halfExtent,
    required this.props,
  });

  final GameMapDef map;

  /// Packed ARGB floor colours (already converted from the map palette).
  final int floorColor;
  final int accentColor;

  /// Half the size of the square arena in world units.
  final double halfExtent;

  final List<PropPlacement> props;

  static ArenaLayout3D build({
    required GameMapDef map,
    int? seed,
    double halfExtent = 26,
  }) {
    final math.Random rng = math.Random(seed ?? map.id.hashCode);

    // Palette comes from the map itself: floors are the map's floor colour,
    // props sit one step darker so silhouettes read against the ground.
    final int floor = _shift(map.floorColor, 0.06);
    final int accent = _shift(map.decorColor, 0.0);

    final List<PropPlacement> props = <PropPlacement>[];

    // ---- border masonry ring -------------------------------------------
    const int ringCount = 26;
    final double ringRadius = halfExtent - 1.6;
    for (int i = 0; i < ringCount; i++) {
      final double angle = (i / ringCount) * math.pi * 2;
      final double x = math.cos(angle) * ringRadius;
      final double z = math.sin(angle) * ringRadius;
      final bool corner = i % 3 == 0;
      props.add(
        PropPlacement(
          slotId: corner ? 'prop_column' : 'prop_wall',
          position: Vector3(x, 0, z),
          yaw: -angle + math.pi / 2,
          scale: corner ? 0.95 : 1.15,
          blocking: true,
        ),
      );
      // Broken masonry and banners break up the ring.
      if (i % 5 == 2) {
        props.add(
          PropPlacement(
            slotId: 'prop_column_broken',
            position: Vector3(
              math.cos(angle + 0.11) * (ringRadius - 2.4),
              0,
              math.sin(angle + 0.11) * (ringRadius - 2.4),
            ),
            yaw: rng.nextDouble() * math.pi,
            scale: 0.85,
          ),
        );
      }
      if (i % 4 == 1) {
        final double bannerAngle = angle + 0.12;
        props.add(
          PropPlacement(
            slotId: 'prop_banner',
            position: Vector3(
              math.cos(bannerAngle) * (ringRadius + 0.6),
              0,
              math.sin(bannerAngle) * (ringRadius + 0.6),
            ),
            yaw: -bannerAngle + math.pi / 2,
            scale: 1.0,
          ),
        );
      }
    }

    // ---- scenery cluster inside the ring --------------------------------
    final List<String> soothing = <String>[
      'prop_tree',
      'prop_tree_tall',
      'prop_rock',
      'prop_rock_small',
      'prop_stones',
      'prop_plant',
      'prop_pine',
    ];
    final List<String> eerie = <String>[
      'prop_grave_cross',
      'prop_grave_round',
      'prop_grave_broken',
      'prop_coffin',
      'prop_pumpkin',
      'prop_lantern',
      'prop_urn',
    ];
    final bool grim = map.decorStyle == MapDecorStyle.storm || map.id.contains('void');

    final int clusterCount = 30 + rng.nextInt(10);
    for (int i = 0; i < clusterCount; i++) {
      final double angle = rng.nextDouble() * math.pi * 2;
      final double radius = 3.5 + rng.nextDouble() * (ringRadius - 6);
      final double x = math.cos(angle) * radius;
      final double z = math.sin(angle) * radius;
      final List<String> pool = grim || rng.nextDouble() < 0.34 ? eerie : soothing;
      final String slot = pool[rng.nextInt(pool.length)];
      props.add(
        PropPlacement(
          slotId: slot,
          position: Vector3(x, 0, z),
          yaw: rng.nextDouble() * math.pi * 2,
          scale: 0.75 + rng.nextDouble() * 0.6,
          blocking: slot.contains('tree') || slot.contains('crypt'),
        ),
      );
    }

    // ---- landmark pieces -------------------------------------------------
    props.add(
      PropPlacement(
        slotId: 'prop_statue',
        position: Vector3(0, 0, -halfExtent * 0.62),
        yaw: math.pi,
        scale: 1.2,
        blocking: true,
      ),
    );
    props.add(
      PropPlacement(
        slotId: 'prop_trophy',
        position: Vector3(0, 0, halfExtent * 0.62),
        yaw: 0,
        scale: 1.1,
      ),
    );
    for (final double side in <double>[-1, 1]) {
      props.add(
        PropPlacement(
          slotId: 'prop_target',
          position: Vector3(side * halfExtent * 0.55, 0, side * halfExtent * 0.2),
          yaw: side > 0 ? -math.pi / 2 : math.pi / 2,
          scale: 1.0,
        ),
      );
      props.add(
        PropPlacement(
          slotId: 'prop_fence',
          position: Vector3(side * halfExtent * 0.34, 0, -side * halfExtent * 0.52),
          yaw: 0,
          scale: 1.0,
          blocking: true,
        ),
      );
    }

    // ---- spawn markers ---------------------------------------------------
    // A circle of ground plates marks the eight fighter spawn points.
    for (int i = 0; i < 8; i++) {
      final double angle = (i / 8) * math.pi * 2;
      props.add(
        PropPlacement(
          slotId: 'marker_ground',
          position: Vector3(math.cos(angle) * (halfExtent * 0.42), 0, math.sin(angle) * (halfExtent * 0.42)),
          yaw: 0,
          scale: 1.0,
        ),
      );
    }

    return ArenaLayout3D(
      map: map,
      floorColor: floor,
      accentColor: accent,
      halfExtent: halfExtent,
      props: props,
    );
  }

  /// True when a point is inside the walkable ring.
  bool isInside(Vector3 point, {double margin = 0.6}) {
    final double limit = halfExtent - 1.9 - margin;
    return point.x > -limit && point.x < limit && point.z > -limit && point.z < limit;
  }

  /// Smallest distance from a point to a blocking prop.
  double clearanceAt(double x, double z) {
    double best = double.infinity;
    for (final PropPlacement prop in props) {
      if (!prop.blocking) {
        continue;
      }
      final double dx = prop.position.x - x;
      final double dz = prop.position.z - z;
      final double distance = math.sqrt(dx * dx + dz * dz);
      if (distance < best) {
        best = distance;
      }
    }
    return best;
  }

  /// Clamps a position so it stays inside the ring and out of blocking props.
  void resolve(Vector3 position) {
    final double limit = halfExtent - 2.6;
    position.x = position.x.clamp(-limit, limit);
    position.z = position.z.clamp(-limit, limit);
    for (final PropPlacement prop in props) {
      if (!prop.blocking) {
        continue;
      }
      final double dx = position.x - prop.position.x;
      final double dz = position.z - prop.position.z;
      final double distanceSq = dx * dx + dz * dz;
      const double radius = 1.5;
      if (distanceSq < radius * radius && distanceSq > 0.0001) {
        final double distance = math.sqrt(distanceSq);
        final double push = (radius - distance) / distance;
        position.x += dx * push;
        position.z += dz * push;
      }
    }
  }

  static int _shift(int argb, double amount) {
    int r = (argb >> 16) & 0xFF;
    int g = (argb >> 8) & 0xFF;
    int b = argb & 0xFF;
    if (amount >= 0) {
      r = (r + (255 - r) * amount).round();
      g = (g + (255 - g) * amount).round();
      b = (b + (255 - b) * amount).round();
    } else {
      final double f = 1 + amount;
      r = (r * f).round();
      g = (g * f).round();
      b = (b * f).round();
    }
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }
}
