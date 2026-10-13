import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart';

import '../game/audio_catalog.dart';
import '../engine3d/asset_loader.dart';
import '../engine3d/texture_loader.dart';
import '../engine3d/camera_controller.dart';
import '../engine3d/math3d.dart';
import '../engine3d/renderer3d.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'widgets/pill.dart';
import 'widgets/primary_button.dart';
import 'widgets/surface_card.dart';

/// Asset gallery and loader report.
///
/// Every model the engine can draw is listed here with where it came from, how
/// many triangles it costs and whether the file was actually present - so a
/// missing download is visible at a glance instead of showing up as a strange
/// looking arena.
class Models3DScreen extends StatefulWidget {
  const Models3DScreen({super.key});

  @override
  State<Models3DScreen> createState() => _Models3DScreenState();
}

class _Models3DScreenState extends State<Models3DScreen> with SingleTickerProviderStateMixin {
  final AssetLoader _assets = AssetLoader.instance;
  final Renderer3D _renderer = Renderer3D(
    lighting: LightingRig(fogStart: 6, fogEnd: 26, fogStrength: 0.4),
  );
  final CameraController3D _camera = CameraController3D(
    yaw: 0.55,
    pitch: 0.36,
    distance: 4.6,
    fovY: 0.82,
  );
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  late final Ticker _ticker;
  List<AssetSlot> _slots = const <AssetSlot>[];
  AssetSlot? _selected;
  double _spin = 0;
  bool _autoSpin = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _load();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final List<AssetSlot> slots = await _assets.loadAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _slots = slots;
      _selected = slots.isNotEmpty ? slots.first : null;
      _loading = false;
      _framePreview();
    });
  }

  void _onTick(Duration elapsed) {
    if (_autoSpin) {
      _spin += 0.35 * (1 / 60);
    }
    _frame.value++;
  }

  void _framePreview() {
    final AssetSlot? slot = _selected;
    if (slot == null || slot.model == null) {
      return;
    }
    // Frame the model: distance scales with its largest dimension.
    final double extent = slot.model!.bounds.maxExtent;
    _camera.distance = (extent * 1.7 + 1.4).clamp(2.2, 14.0);
    _camera.focus.setValues(0, slot.model!.bounds.center.y * 0.6, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('3D Model Arsenal', style: AppText.heading(size: 19)),
        actions: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Pill(
                label: '${_assets.loadedModelCount} GLB · ${_assets.proceduralCount} built',
                icon: '📦',
                color: AppColors.secondary,
                background: AppColors.surfaceAlt,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Reading model pack', style: AppText.title(size: 16)),
                  const SizedBox(height: AppSpacing.md),
                  const SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceAlt,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                _summaryCard(),
                const SizedBox(height: AppSpacing.lg),
                _previewCard(),
                if (_assets.notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _notesCard(),
                ],
                const SizedBox(height: AppSpacing.lg),
                _textureSection(),
                const SizedBox(height: AppSpacing.lg),
                _audioSection(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'SLOTS',
                  style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.4),
                ),
                const SizedBox(height: AppSpacing.md),
                ..._slots.map(_slotTile),
              ],
            ),
    );
  }

  Widget _summaryCard() {
    final int totalTriangles = _slots
        .where((AssetSlot slot) => slot.model != null)
        .fold(0, (int sum, AssetSlot slot) => sum + slot.model!.triangleCount);
    final int totalBytes = _slots
        .where((AssetSlot slot) => slot.origin == AssetOrigin.model && slot.model != null)
        .fold(0, (int sum, AssetSlot slot) => sum + slot.model!.byteSize);
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('🗿', style: TextStyle(fontSize: 28)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Model arsenal', style: AppText.heading(size: 19)),
                    const SizedBox(height: 2),
                    Text(
                      'Downloaded GLB files plus procedural stand-ins, loaded once and cached in memory.',
                      style: AppText.body(size: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              Pill(
                label: '${_slots.length} slots',
                icon: '🎯',
                color: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
              ),
              Pill(
                label: '${_assets.loadedModelCount} from GLB',
                icon: '📦',
                color: AppColors.secondary,
                background: AppColors.surfaceAlt,
              ),
              Pill(
                label: '${_assets.proceduralCount} procedural',
                icon: '🔧',
                color: AppColors.primaryDark,
                background: AppColors.surfaceAlt,
              ),
              Pill(
                label: '$totalTriangles tris',
                icon: '🔺',
                color: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
              ),
              Pill(
                label: '${(totalBytes / 1024 / 1024).toStringAsFixed(2)} MB geometry',
                icon: '💾',
                color: AppColors.textPrimary,
                background: AppColors.surfaceAlt,
              ),
              Pill(
                label: '${_assets.loadedTextureCount} textures',
                icon: '🎨',
                color: AppColors.accent,
                background: AppColors.surfaceAlt,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final AssetSlot? slot = _selected;
    if (slot == null || slot.model == null) {
      return const SizedBox.shrink();
    }
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails details) {
                  setState(() => _autoSpin = false);
                  _camera.orbit(details.delta.dx, details.delta.dy);
                },
                child: CustomPaint(
                  painter: _PreviewPainter(
                    renderer: _renderer,
                    camera: _camera,
                    frame: _frame,
                    slotId: slot.id,
                    spin: _spin,
                    assets: _assets,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(slot.label, style: AppText.title(size: 16)),
                    ),
                    Pill(
                      label: slot.origin == AssetOrigin.model ? 'GLB FILE' : 'PROCEDURAL',
                      icon: slot.origin == AssetOrigin.model ? '📦' : '🔧',
                      color: Colors.white,
                      background: slot.origin == AssetOrigin.model ? AppColors.secondary : AppColors.primaryDark,
                      fontSize: 10,
                      bold: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  slot.origin == AssetOrigin.model ? slot.assetPath : 'Built in code (no file required)',
                  style: AppText.label(size: 11),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    Pill(
                      label: '${slot.model!.triangleCount} tris',
                      color: AppColors.textPrimary,
                      background: AppColors.surfaceAlt,
                    ),
                    Pill(
                      label: '${slot.model!.vertexCount} verts',
                      color: AppColors.textPrimary,
                      background: AppColors.surfaceAlt,
                    ),
                    Pill(
                      label: slot.model!.sizeLabel,
                      color: AppColors.textPrimary,
                      background: AppColors.surfaceAlt,
                    ),
                    Pill(
                      label: 'h ${slot.model!.bounds.height.toStringAsFixed(2)}',
                      color: AppColors.textPrimary,
                      background: AppColors.surfaceAlt,
                    ),
                    if (slot.model!.textured)
                      const Pill(
                        label: 'palette sampled',
                        icon: '🎨',
                        color: Colors.white,
                        background: AppColors.accent,
                        fontSize: 10,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(slot.source, style: AppText.body(size: 11.5, color: AppColors.textMuted)),
                if (slot.note != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(slot.note!, style: AppText.body(size: 11.5, color: AppColors.textMuted)),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: GhostButton(
                        label: _autoSpin ? 'PAUSE SPIN' : 'AUTO SPIN',
                        icon: '🔄',
                        onPressed: () => setState(() => _autoSpin = !_autoSpin),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Decoded surface textures with a live thumbnail of the actual file.
  Widget _textureSection() {
    final List<TextureSlot> slots = _assets.textureSlots;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Surface textures',
            subtitle: 'CC0 scans decoded at startup and sampled onto the arena floor.',
            icon: '🎨',
            trailing: Pill(
              label: '${_assets.loadedTextureCount}/${slots.length}',
              color: AppColors.textPrimary,
              background: AppColors.surfaceAlt,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: slots.map(_textureTile).toList(),
          ),
        ],
      ),
    );
  }

  Widget _textureTile(TextureSlot slot) {
    final BakedTexture? texture = slot.texture;
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: SizedBox(
              width: 132,
              height: 78,
              child: texture == null
                  ? Container(
                      color: AppColors.surfaceAlt,
                      child: Center(
                        child: Text('no file', style: AppText.label(size: 10)),
                      ),
                    )
                  : CustomPaint(painter: _TextureThumbPainter(texture.image)),
            ),
          ),
          const SizedBox(height: 6),
          Text(slot.label, style: AppText.title(size: 12)),
          Text(
            texture == null ? 'flat colour fallback' : texture.sizeLabel,
            style: AppText.label(size: 10),
          ),
          Text(
            slot.usage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// The bundled sound cues. Names and paths only - playback arrives with the
  /// audio service, but the files themselves are already in the bundle.
  Widget _audioSection() {
    final List<AudioAsset> cues = AudioCatalog.all;
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'Sound cues',
            subtitle: 'CC0 Kenney packs, mapped to the moments they belong to.',
            icon: '🔔',
            trailing: Pill(
              label: '${AudioCatalog.sfx.length} sfx · ${AudioCatalog.music.length} stings',
              color: AppColors.textPrimary,
              background: AppColors.surfaceAlt,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...cues.map(
            (AudioAsset cue) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Text(cue.music ? '🎵' : '🔊', style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 108,
                    child: Text(cue.label, style: AppText.title(size: 11.5)),
                  ),
                  Expanded(
                    child: Text(
                      cue.usage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(size: 11, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesCard() {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'LOADER NOTES',
            style: AppText.label(size: 11, weight: FontWeight.w800).copyWith(letterSpacing: 2.2),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Everything the loader had to work around. Missing files fall back to procedural '
            'geometry, so the arena always renders - run scripts/download_assets.sh to replace '
            'the stand-ins with the full Kenney packs.',
            style: AppText.body(size: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._assets.notes.take(12).map(
                (String note) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• ', style: TextStyle(color: AppColors.textMuted)),
                      Expanded(
                        child: Text(
                          note,
                          style: AppText.label(size: 11, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _slotTile(AssetSlot slot) {
    final bool selected = _selected?.id == slot.id;
    final bool fromFile = slot.origin == AssetOrigin.model;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => setState(() {
          _selected = slot;
          _spin = 0;
          _framePreview();
        }),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card - 4),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: fromFile ? AppColors.secondary.withAlpha(28) : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Center(
                  child: Text(
                    _badgeFor(slot.id),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(slot.label, style: AppText.title(size: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      slot.model == null
                          ? 'not loaded'
                          : '${slot.model!.triangleCount} tris · ${slot.model!.sizeLabel}'
                              '${slot.model!.textured ? ' · palette' : ''}',
                      style: AppText.label(size: 11),
                    ),
                  ],
                ),
              ),
              Pill(
                label: fromFile ? 'GLB' : 'BUILT',
                color: fromFile ? AppColors.secondary : AppColors.textMuted,
                background: AppColors.surfaceAlt,
                fontSize: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _badgeFor(String id) {
    if (id.startsWith('fighter')) {
      return '🗡️';
    }
    if (id.startsWith('creature')) {
      return '🐾';
    }
    if (id.startsWith('boss')) {
      return '🐲';
    }
    if (id.startsWith('weapon')) {
      return '⚔️';
    }
    if (id.startsWith('marker')) {
      return '⭕';
    }
    if (id.startsWith('khronos')) {
      return '📦';
    }
    return '🏺';
  }
}

/// Draws a single slot on a turntable.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter({
    required this.renderer,
    required this.camera,
    required this.frame,
    required this.slotId,
    required this.spin,
    required this.assets,
  }) : super(repaint: frame);

  final Renderer3D renderer;
  final CameraController3D camera;
  final ValueNotifier<int> frame;
  final String slotId;
  final double spin;
  final AssetLoader assets;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, 0),
          Offset(0, size.height),
          const <Color>[Color(0xFFF1E9DA), Color(0xFFE3D8C4)],
        ),
    );

    final MeshInstance instance = MeshInstance(
      model: assets.model(slotId),
      position: Vector3(0, 0, 0),
      yaw: spin,
      scale: 1,
      modelScale: assets.normalisationScale(slotId),
      shadowRadius: math.max(0.35, assets.model(slotId).bounds.maxExtent * 0.4) * 0.6,
    );
    renderer.render(canvas, size, camera, <MeshInstance>[instance]);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreviewPainter oldDelegate) =>
      oldDelegate.slotId != slotId || oldDelegate.renderer != renderer;
}

/// Draws a decoded texture file as a thumbnail.
class _TextureThumbPainter extends CustomPainter {
  _TextureThumbPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final Rect dst = Offset.zero & size;
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_TextureThumbPainter oldDelegate) => oldDelegate.image != image;
}
