import 'dart:math' as math;
import 'dart:ui';

import 'chimera.dart';

/// Procedural art for the fusion bosses.
///
/// No image assets: every chimera is a stack of polygons drawn around a body
/// ellipse, and the traits come from the fusion (wings for the bird halves,
/// paws and mane for the feline halves, tails and stingers for the serpent
/// halves). The renderer is called from [Fighter.renderBody], so the canvas is
/// already translated to the body centre and rotated to face +X.
class ChimeraRenderer {
  const ChimeraRenderer._();

  /// Draws one chimera in local space (origin = centre, facing +X).
  static void renderBody(Canvas canvas, Chimera chimera) {
    final double r = chimera.radius;
    final ChimeraType type = chimera.type;
    final bool dodging = chimera.dodgeFlashTimer > 0;

    canvas.save();
    if (chimera.rollSpin != 0) {
      canvas.rotate(chimera.rollSpin);
    }

    _phaseAura(canvas, chimera, r);

    // Trail while dashing or rolling.
    if (chimera.isDashing) {
      for (int i = 3; i >= 1; i--) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-r * 0.5 * i, 0),
            width: r * 1.9,
            height: r * 1.3,
          ),
          Paint()..color = type.color.withAlpha(38 * (4 - i)),
        );
      }
    }

    _tail(canvas, chimera, r);
    _wings(canvas, chimera, r);
    _legs(canvas, chimera, r);

    final Color bodyBase = dodging
        ? Color.lerp(type.color, const Color(0xFFF5F1EA), 0.55)!
        : type.color;
    final Color bodyDark = _shade(bodyBase, -0.28);
    final Color bodyLight = _shade(bodyBase, 0.22);

    // Torso: one broad ellipse with a lighter belly plate.
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2.15, height: r * 1.45),
      Paint()..color = bodyBase,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r * 0.1, r * 0.34), width: r * 1.6, height: r * 0.6),
      Paint()..color = bodyLight.withAlpha(150),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.15, -r * 0.1), width: r * 1.9, height: r * 1.1),
      Paint()
        ..color = bodyDark.withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06,
    );

    _backSpikes(canvas, chimera, r);
    _mane(canvas, chimera, r);
    _head(canvas, chimera, r);

    // Winding up: a sweeping arc that fills as the attack charges.
    if (chimera.isWindingUp) {
      _windupArc(canvas, chimera, r);
    }

    // Energy shield bubble.
    if (chimera.shieldActive) {
      final double pulse = 0.6 + 0.4 * math.sin(chimera.age * 6);
      canvas.drawCircle(
        Offset.zero,
        r * 1.4,
        Paint()..color = const Color(0xFF0891B2).withAlpha((30 * pulse).round()),
      );
      canvas.drawCircle(
        Offset.zero,
        r * 1.4,
        Paint()
          ..color = const Color(0xFF0891B2).withAlpha((170 * pulse).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    canvas.restore();
  }

  // ------------------------------------------------------------------- pieces

  /// Concentric aura rings: one per phase reached.
  static void _phaseAura(Canvas canvas, Chimera chimera, double r) {
    final Color aura = _phaseColor(chimera.phaseState.index);
    final double pulse = 0.5 + 0.5 * math.sin(chimera.enragePulse * 2.4);
    final int rings = chimera.phaseState.index + 1;
    for (int i = 0; i < rings; i++) {
      canvas.drawCircle(
        Offset.zero,
        r * (1.22 + i * 0.16) + pulse * 3,
        Paint()
          ..color = aura.withAlpha((60 - i * 14).clamp(18, 60).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  static Color _phaseColor(int phaseIndex) {
    switch (phaseIndex) {
      case 0:
        return const Color(0xFF3F6212);
      case 1:
        return const Color(0xFFD97706);
      default:
        return const Color(0xFFB91C1C);
    }
  }

  /// Segmented tail that sways with the enrage clock; venomous types get a
  /// stinger, others a club tip.
  static void _tail(Canvas canvas, Chimera chimera, double r) {
    final double sway = math.sin(chimera.enragePulse * 2.1) * 0.22;
    final Color tailColor = _shade(chimera.type.color, -0.18);
    const int segments = 5;
    for (int i = 0; i < segments; i++) {
      final double t = i / (segments - 1);
      final double x = -r * (0.9 + t * 1.15);
      final double y = sway * r * t;
      canvas.drawCircle(
        Offset(x, y),
        r * (0.30 - t * 0.20),
        Paint()..color = tailColor,
      );
    }
    final bool venomous = chimera.type == ChimeraType.basilisk || chimera.type == ChimeraType.deathroll;
    final double tipX = -r * 2.05;
    final double tipY = sway * r;
    if (venomous) {
      final Path stinger = Path()
        ..moveTo(tipX, tipY)
        ..lineTo(tipX - r * 0.3, tipY - r * 0.16)
        ..lineTo(tipX - r * 0.3, tipY + r * 0.16)
        ..close();
      canvas.drawPath(stinger, Paint()..color = const Color(0xFF3F6212));
    } else {
      canvas.drawCircle(Offset(tipX, tipY), r * 0.16, Paint()..color = _shade(tailColor, -0.3));
    }
  }

  /// Wings for the aerial halves - a slow flap that speeds up when enraged.
  static void _wings(Canvas canvas, Chimera chimera, double r) {
    final ChimeraType type = chimera.type;
    final bool winged = type == ChimeraType.gryphonPrime ||
        type == ChimeraType.wyvern ||
        type == ChimeraType.omegaChimera;
    if (!winged) {
      return;
    }
    final double flap = math.sin(chimera.enragePulse * (2.2 + chimera.phaseState.index * 0.6)) * 0.35;
    final Color membrane = _shade(type.color, -0.12);
    final Color edge = _shade(type.color, 0.3);

    for (final double side in <double>[-1, 1]) {
      final Path wing = Path()
        ..moveTo(-r * 0.35, side * r * 0.35)
        ..quadraticBezierTo(
          -r * 0.5,
          side * r * (1.5 + flap),
          -r * 1.6,
          side * r * (1.75 + flap * 1.4),
        )
        ..lineTo(-r * 1.05, side * r * 0.55)
        ..close();
      canvas.drawPath(wing, Paint()..color = membrane.withAlpha(220));
      canvas.drawPath(
        wing,
        Paint()
          ..color = edge.withAlpha(160)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  /// Four paws, tucked under the torso.
  static void _legs(Canvas canvas, Chimera chimera, double r) {
    final Paint paint = Paint()..color = _shade(chimera.type.color, -0.35);
    final Paint claw = Paint()..color = const Color(0xFFEDE7DB);
    for (final double x in <double>[r * 0.55, -r * 0.45]) {
      for (final double y in <double>[-0.66, 0.66]) {
        final Rect leg = Rect.fromCenter(
          center: Offset(x, y * r),
          width: r * 0.5,
          height: r * 0.44,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(leg, Radius.circular(r * 0.16)), paint);
        for (int c = -1; c <= 1; c++) {
          final double dx = x + c * r * 0.13;
          final Path clawPath = Path()
            ..moveTo(dx, y * r + y.sign * r * 0.2)
            ..lineTo(dx + r * 0.06, y * r + y.sign * r * 0.34)
            ..lineTo(dx - r * 0.06, y * r + y.sign * r * 0.34)
            ..close();
          canvas.drawPath(clawPath, claw);
        }
      }
    }
  }

  /// Bone spikes along the spine - denser for the heavy fusions.
  static void _backSpikes(Canvas canvas, Chimera chimera, double r) {
    final int count = chimera.type.speedRating >= 4.5 ? 6 : 4;
    final Paint paint = Paint()..color = _shade(chimera.type.color, 0.42);
    for (int i = 0; i < count; i++) {
      final double t = i / (count - 1);
      final double x = r * (0.75 - t * 1.5);
      final double lift = math.sin(chimera.enragePulse * 1.6 + t * 2) * r * 0.03;
      final double height = r * (0.34 - t * 0.16);
      final Path spike = Path()
        ..moveTo(x - r * 0.1, -r * 0.6)
        ..lineTo(x, -r * 0.6 - height - lift)
        ..lineTo(x + r * 0.1, -r * 0.6)
        ..close();
      canvas.drawPath(spike, paint);
    }
  }

  /// Manes for the feline halves.
  static void _mane(Canvas canvas, Chimera chimera, double r) {
    final ChimeraType type = chimera.type;
    final bool maned = type == ChimeraType.gryphonPrime ||
        type == ChimeraType.ravager ||
        type == ChimeraType.deathroll ||
        type == ChimeraType.omegaChimera;
    if (!maned) {
      return;
    }
    final Paint paint = Paint()..color = _shade(type.color, -0.4);
    const int spikes = 12;
    for (int i = 0; i < spikes; i++) {
      final double angle = (i / spikes) * math.pi * 2;
      final double inner = r * 0.55;
      final double outer = r * (0.98 + math.sin(chimera.enragePulse * 3 + i) * 0.06);
      final Path blade = Path()
        ..moveTo(
          r * 0.72 + math.cos(angle - 0.16) * inner,
          math.sin(angle - 0.16) * inner,
        )
        ..lineTo(r * 0.72 + math.cos(angle) * outer, math.sin(angle) * outer)
        ..lineTo(
          r * 0.72 + math.cos(angle + 0.16) * inner,
          math.sin(angle + 0.16) * inner,
        )
        ..close();
      canvas.drawPath(blade, paint);
    }
  }

  /// Head, horns, eyes and fangs; the jaw opens while a melee attack charges.
  static void _head(Canvas canvas, Chimera chimera, double r) {
    final ChimeraType type = chimera.type;
    final bool horned = type == ChimeraType.gryphonPrime ||
        type == ChimeraType.wyvern ||
        type == ChimeraType.omegaChimera ||
        type == ChimeraType.ravager;
    final Color headColor = _shade(type.color, 0.08);
    final Color dark = _shade(type.color, -0.45);
    final bool enraged = chimera.phaseState.index >= 2;
    final double jaw = chimera.isWindingUp ? 0.2 * chimera.windupProgress : 0.0;

    // Neck wedge.
    final Path neck = Path()
      ..moveTo(r * 0.4, -r * 0.42)
      ..lineTo(r * 1.0, -r * 0.3)
      ..lineTo(r * 1.0, r * 0.3)
      ..lineTo(r * 0.4, r * 0.42)
      ..close();
    canvas.drawPath(neck, Paint()..color = headColor);

    // Skull.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(r * 1.2, 0), width: r * 1.0, height: r * 0.82),
      Paint()..color = headColor,
    );

    // Muzzle (opens with the jaw).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r * (1.58 + jaw * 0.2), 0),
        width: r * (0.5 + jaw * 0.3),
        height: r * (0.34 + jaw * 0.5),
      ),
      Paint()..color = _shade(type.color, -0.12),
    );

    // Fangs.
    final Paint fang = Paint()..color = const Color(0xFFF5F1EA);
    for (final double side in <double>[-1, 1]) {
      final Path tooth = Path()
        ..moveTo(r * 1.66, side * r * (0.1 + jaw * 0.24))
        ..lineTo(r * 1.86, side * r * (0.16 + jaw * 0.2))
        ..lineTo(r * 1.68, side * r * (0.02 + jaw * 0.34))
        ..close();
      canvas.drawPath(tooth, fang);
    }

    // Horns.
    if (horned) {
      final Path horn = Path()..moveTo(r * 1.02, -r * 0.36);
      horn
        ..lineTo(r * 0.86, -r * 1.02)
        ..lineTo(r * 1.18, -r * 0.42)
        ..close();
      canvas.drawPath(horn, Paint()..color = _shade(type.color, 0.35));
      final Path horn2 = Path()..moveTo(r * 1.02, r * 0.36);
      horn2
        ..lineTo(r * 0.86, r * 1.02)
        ..lineTo(r * 1.18, r * 0.42)
        ..close();
      canvas.drawPath(horn2, Paint()..color = _shade(type.color, 0.35));
    }

    // Eyes: cold amber, burning red when enraged, dark while dodging.
    final Color eyeColor = chimera.dodgeFlashTimer > 0
        ? dark
        : (enraged ? const Color(0xFFB91C1C) : const Color(0xFFD97706));
    for (final double side in <double>[-1, 1]) {
      canvas.drawCircle(
        Offset(r * 1.24, side * r * 0.2),
        r * 0.09,
        Paint()..color = eyeColor,
      );
      canvas.drawCircle(
        Offset(r * 1.27, side * r * 0.2),
        r * 0.035,
        Paint()..color = dark,
      );
    }
  }

  /// Telegraph: a ring that closes in plus a sweep that fills with the wind-up.
  static void _windupArc(Canvas canvas, Chimera chimera, double r) {
    final double progress = chimera.windupProgress;
    final Color warn = _phaseColor(chimera.phaseState.index);
    final double outer = r * (2.1 - progress * 0.7);

    canvas.drawCircle(
      Offset.zero,
      outer,
      Paint()
        ..color = warn.withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 1.55),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = warn.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Lightens (positive) or darkens (negative) a colour.
  static Color _shade(Color base, double amount) {
    final Color target = amount >= 0 ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    return Color.lerp(base, target, amount.abs().clamp(0.0, 1.0))!;
  }
}
