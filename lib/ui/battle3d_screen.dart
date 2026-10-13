import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

import '../engine3d/arena3d.dart';
import '../engine3d/asset_loader.dart';
import '../engine3d/math3d.dart';
import '../engine3d/renderer3d.dart';
import '../engine3d/scene_manager.dart';
import '../game/game_map.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'widgets/pill.dart';
import 'widgets/primary_button.dart';
import 'widgets/surface_card.dart';

/// A creature wandering the arena.
class _Wanderer {
  _Wanderer({required this.instance, required this.speed, required this.target});

  final MeshInstance instance;
  final double speed;
  Vector3 target;
  double wait = 0;
  double yawTarget = 0;
  bool fleeing = false;
}

/// Playable 3D arena built on the custom software renderer.
///
/// This is the first playable slice of the 3D pivot: a real imported arena, a
/// real imported character, camera-relative movement, an orbiting camera and
/// creatures that wander, notice the player and run. Combat, progression and
/// the campaign wiring stay on the 2D engine until the 3D slice has proven
/// itself on device.
class Battle3DScreen extends StatefulWidget {
  const Battle3DScreen({super.key, required this.map, this.seed});

  final GameMapDef map;
  final int? seed;

  @override
  State<Battle3DScreen> createState() => _Battle3DScreenState();
}

class _Battle3DScreenState extends State<Battle3DScreen> with SingleTickerProviderStateMixin {
  static const String _playerSlot = 'fighter_warrior';

  /// Kenney characters are authored facing -Z; flip here if a model faces the
  /// other way round.
  static const double _facingOffset = math.pi;

  late final Ticker _ticker;
  final AssetLoader _assets = AssetLoader.instance;
  final math.Random _rng = math.Random(4242);

  SceneManager3D? _scene;
  MeshInstance? _playerInstance;
  MeshInstance? _swordInstance;
  final List<_Wanderer> _wanderers = <_Wanderer>[];

  final Vector3 _playerPosition = Vector3.zero();
  final Vector3 _playerVelocity = Vector3.zero();
  double _playerYaw = 0;
  double _bob = 0;

  /// Joystick state (x right, y down, normalised).
  Offset _stick = Offset.zero;
  bool _draggingStick = false;

  bool _ready = false;
  String _status = 'Preparing arena...';
  Duration _lastTick = Duration.zero;
  bool _showDebug = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _boot();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scene?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    // Runs from initState, before the first frame: assign the status directly
    // and only use setState once loading has actually yielded.
    _status = 'Loading models...';
    await _assets.loadAll();
    if (!mounted) {
      return;
    }
    setState(() => _status = 'Building arena...');
    final ArenaLayout3D layout = ArenaLayout3D.build(map: widget.map, seed: widget.seed);
    final SceneManager3D scene = SceneManager3D(layout: layout, assets: _assets);
    scene.buildArena();

    // Player.
    final Vector3 spawn = Vector3(0, 0, layout.halfExtent * 0.34);
    _playerPosition.setFrom(spawn);
    final MeshInstance player = scene.spawn(_playerSlot, _playerPosition, yaw: 0, actor: true);
    _swordInstance = scene.spawn('weapon_sword', spawn + Vector3(0.34, 0, 0.1), scale: 0.75, actor: true);

    // Wanderers: one of every creature slot, spread around the ring.
    const List<String> creatureSlots = <String>[
      'creature_lion',
      'creature_tiger',
      'creature_boar',
      'creature_hawk',
      'creature_fox',
      'creature_venom',
      'creature_bee',
      'creature_heavy',
    ];
    for (int i = 0; i < creatureSlots.length; i++) {
      final double angle = (i / creatureSlots.length) * math.pi * 2 + 0.4;
      final Vector3 position = Vector3(
        math.cos(angle) * layout.halfExtent * 0.55,
        0,
        math.sin(angle) * layout.halfExtent * 0.55,
      );
      final MeshInstance instance = scene.spawn(creatureSlots[i], position, yaw: -angle, actor: true);
      _wanderers.add(
        _Wanderer(
          instance: instance,
          speed: 1.6 + _rng.nextDouble() * 1.5,
          target: _randomPoint(layout),
        ),
      );
    }

    scene.camera
      ..focus.setFrom(spawn)
      ..distance = 13.5
      ..updateViewport(400, 800);

    setState(() {
      _scene = scene;
      _playerInstance = player;
      _ready = true;
      _status = '';
    });
  }

  Vector3 _randomPoint(ArenaLayout3D layout) {
    return Vector3(
      (_rng.nextDouble() * 2 - 1) * layout.halfExtent * 0.75,
      0,
      (_rng.nextDouble() * 2 - 1) * layout.halfExtent * 0.75,
    );
  }

  // ------------------------------------------------------------------- update
  void _onTick(Duration elapsed) {
    if (!_ready) {
      _lastTick = elapsed;
      return;
    }
    final double dt = _lastTick == Duration.zero
        ? 1 / 60
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;

    final SceneManager3D scene = _scene!;
    scene.advance(dt);

    _updatePlayer(dt, scene);
    _updateWanderers(dt, scene);
    scene.camera.follow(_playerPosition + Vector3(0, 0.9, 0), dt);
  }

  void _updatePlayer(double dt, SceneManager3D scene) {
    // Keyboard and joystick are summed so both input styles work at once.
    double inputX = _stick.dx;
    double inputY = _stick.dy;
    final Set<LogicalKeyboardKey> keys = HardwareKeyboard.instance.logicalKeysPressed;
    if (keys.contains(LogicalKeyboardKey.keyW) || keys.contains(LogicalKeyboardKey.arrowUp)) {
      inputY -= 1;
    }
    if (keys.contains(LogicalKeyboardKey.keyS) || keys.contains(LogicalKeyboardKey.arrowDown)) {
      inputY += 1;
    }
    if (keys.contains(LogicalKeyboardKey.keyA) || keys.contains(LogicalKeyboardKey.arrowLeft)) {
      inputX -= 1;
    }
    if (keys.contains(LogicalKeyboardKey.keyD) || keys.contains(LogicalKeyboardKey.arrowRight)) {
      inputX += 1;
    }

    // Movement is camera relative: pushing up always walks "into" the screen.
    final double yaw = scene.camera.yaw;
    final Vector3 screenForward = Vector3(-math.sin(yaw), 0, -math.cos(yaw));
    final Vector3 screenRight = Vector3(math.cos(yaw), 0, -math.sin(yaw));
    final Vector3 wish = screenForward.scaled(-inputY) + screenRight.scaled(inputX);
    if (wish.length2 > 1) {
      wish.normalize();
    }

    const double speed = 6.4;
    final Vector3 targetVelocity = wish.scaled(speed);
    final double blend = (dt * 10).clamp(0.0, 1.0);
    _playerVelocity.setValues(
      _playerVelocity.x + (targetVelocity.x - _playerVelocity.x) * blend,
      0,
      _playerVelocity.z + (targetVelocity.z - _playerVelocity.z) * blend,
    );

    _playerPosition.x += _playerVelocity.x * dt;
    _playerPosition.z += _playerVelocity.z * dt;
    scene.layout.resolve(_playerPosition);

    if (_playerVelocity.length2 > 0.4) {
      _playerYaw = math.atan2(_playerVelocity.x, _playerVelocity.z) + _facingOffset;
    }

    _bob += dt * (2 + _playerVelocity.length * 1.4);
    final MeshInstance? player = _playerInstance;
    if (player != null) {
      player.position.setFrom(_playerPosition);
      player.yaw = _playerYaw;
      player.yOffset = math.sin(_bob) * 0.045;
    }
    // The blade floats at the warrior's side, bobbing on the same clock.
    final MeshInstance? sword = _swordInstance;
    if (sword != null) {
      final double handYaw = _playerYaw + 0.5;
      sword.position.setValues(
        _playerPosition.x + math.sin(handYaw) * 0.42,
        0.35 + math.sin(_bob * 0.8) * 0.05,
        _playerPosition.z + math.cos(handYaw) * 0.42,
      );
      sword.yaw = _playerYaw + _bob * 0.35;
    }
  }

  void _updateWanderers(double dt, SceneManager3D scene) {
    for (final _Wanderer wanderer in _wanderers) {
      final MeshInstance instance = wanderer.instance;
      final Vector3 toPlayer = _playerPosition - instance.position;
      final double playerDistance = toPlayer.length;

      // Creatures notice the warrior and back away, which shows the camera and
      // the depth sort handling moving objects at close range.
      final bool shouldFlee = playerDistance < 4.2;
      if (shouldFlee != wanderer.fleeing) {
        wanderer.fleeing = shouldFlee;
        if (shouldFlee) {
          wanderer.target = instance.position + toPlayer.scaled(-1.4);
        }
      }

      if (wanderer.wait > 0) {
        wanderer.wait -= dt;
      } else {
        Vector3 direction = wanderer.target - instance.position;
        if (direction.length < 0.8) {
          if (wanderer.fleeing) {
            wanderer.target = instance.position + toPlayer.scaled(-2);
          } else {
            wanderer.wait = 0.6 + _rng.nextDouble() * 1.8;
            wanderer.target = _randomPoint(scene.layout);
          }
        } else {
          direction.normalize();
          final double speed = wanderer.fleeing ? wanderer.speed * 1.7 : wanderer.speed;
          instance.position.x += direction.x * speed * dt;
          instance.position.z += direction.z * speed * dt;
          scene.layout.resolve(instance.position);
          wanderer.yawTarget = math.atan2(direction.x, direction.z) + _facingOffset;
        }
      }

      instance.yaw = Math3d.approachAngle(instance.yaw, wanderer.yawTarget, dt * 4);
      instance.yOffset = math.sin(scene.clock * 3.2 + instance.position.x) * 0.05;
    }
  }

  // -------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final SceneManager3D? scene = _scene;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: scene == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) {},
                    onScaleUpdate: (ScaleUpdateDetails details) {
                      if (details.pointerCount > 1) {
                        scene.camera.zoom((details.scale - 1) * -6);
                      } else {
                        scene.camera.orbit(details.focalPointDelta.dx, details.focalPointDelta.dy);
                      }
                    },
                    child: SizedBox.expand(
                      child: CustomPaint(painter: _ScenePainter(scene)),
                    ),
                  ),
          ),
          if (!_ready) _loadingOverlay(),
          if (_ready) ...<Widget>[
            SafeArea(
              child: Column(
                children: <Widget>[
                  _topBar(scene!),
                  const Spacer(),
                  _bottomBar(scene),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingOverlay() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('⚔️', style: TextStyle(fontSize: 46)),
            const SizedBox(height: AppSpacing.lg),
            Text('Entering the arena', style: AppText.display(size: 24)),
            const SizedBox(height: AppSpacing.sm),
            Text(_status, style: AppText.body(size: 13, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: AppColors.surfaceAlt,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(SceneManager3D scene) {
    final int loaded = _assets.loadedModelCount;
    final int procedural = _assets.proceduralCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(238),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: <Widget>[
            RoundIconButton(
              icon: '🏠',
              size: 38,
              onTap: () => Navigator.of(context).maybePop(),
              tooltip: 'Back',
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${widget.map.emoji} ${widget.map.name}',
                    style: AppText.title(size: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.map.twistIcon} ${widget.map.twistName}',
                    style: AppText.label(size: 10.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Pill(
              label: '$loaded GLB',
              icon: '📦',
              color: AppColors.secondary,
              background: AppColors.surfaceAlt,
              fontSize: 10,
            ),
            const SizedBox(width: AppSpacing.xs),
            Pill(
              label: '$procedural built',
              icon: '🔧',
              color: AppColors.textMuted,
              background: AppColors.surfaceAlt,
              fontSize: 10,
            ),
            const SizedBox(width: AppSpacing.sm),
            RoundIconButton(
              icon: _showDebug ? '📊' : '📈',
              size: 38,
              onTap: () => setState(() => _showDebug = !_showDebug),
              tooltip: 'Toggle stats',
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(SceneManager3D scene) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_showDebug)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    _debugCell('FPS', scene.fps.toStringAsFixed(0)),
                    _debugCell('MS', scene.lastFrameMs.toStringAsFixed(1)),
                    _debugCell('TRIS', '${scene.renderer.lastTriangleCount}'),
                    _debugCell('DRAWN', '${scene.renderer.lastInstanceCount}'),
                    _debugCell('ACTORS', '${scene.actors.length}'),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _joystick(),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      RoundIconButton(
                        icon: '🔍➖',
                        size: 40,
                        background: AppColors.surface,
                        onTap: () => scene.camera.zoom(1.6),
                        tooltip: 'Zoom out',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      RoundIconButton(
                        icon: '🔍➕',
                        size: 40,
                        background: AppColors.surface,
                        onTap: () => scene.camera.zoom(-1.6),
                        tooltip: 'Zoom in',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Pill(
                    label: 'drag to orbit · WASD to move',
                    color: AppColors.textMuted,
                    background: AppColors.surface,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _debugCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppText.label(size: 9.5, weight: FontWeight.w800).copyWith(letterSpacing: 1.2)),
          Text(value, style: AppText.number(size: 13)),
        ],
      ),
    );
  }

  Widget _joystick() {
    return GestureDetector(
      onPanStart: (DragStartDetails details) => _setStick(details.localPosition),
      onPanUpdate: (DragUpdateDetails details) => _setStick(details.localPosition),
      onPanEnd: (_) => setState(() {
        _stick = Offset.zero;
        _draggingStick = false;
      }),
      child: Container(
        width: 132,
        height: 132,
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(190),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Text(
              _draggingStick ? 'moving' : 'move',
              style: AppText.label(size: 11),
            ),
            Transform.translate(
              offset: Offset(_stick.dx * 40, _stick.dy * 40),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setStick(Offset local) {
    const double radius = 46;
    final double dx = (local.dx - 66) / radius;
    final double dy = (local.dy - 66) / radius;
    final double length = math.sqrt(dx * dx + dy * dy);
    final double scale = length > 1 ? 1 / length : 1;
    setState(() {
      _stick = Offset(dx * scale, dy * scale);
      _draggingStick = true;
    });
  }
}

/// Paints the scene without rebuilding any widgets.
class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene) : super(repaint: scene.frame);

  final SceneManager3D scene;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    scene.render(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) => oldDelegate.scene != scene;
}
