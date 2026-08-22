import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;
import '../models.dart';
import '../editor_controller.dart';
import '../interpolation.dart';

/// The main pose/rig canvas: draws every visible layer at its current
/// interpolated world pose, draws bone sticks when the skeleton overlay is
/// on, and turns single-finger drag / two-finger pinch+rotate into pose
/// changes on the selected layer.
class CanvasStage extends StatefulWidget {
  final EditorController controller;
  final GlobalKey repaintKey;
  const CanvasStage({super.key, required this.controller, required this.repaintKey});

  @override
  State<CanvasStage> createState() => _CanvasStageState();
}

class _CanvasStageState extends State<CanvasStage> {
  // Gesture start snapshot for the layer currently being manipulated.
  Pose? _gestureStartPose;
  Matrix4? _parentInverseAtGestureStart;

  EditorController get controller => widget.controller;
  Project get project => controller.project;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / project.canvasWidth,
          constraints.maxHeight / project.canvasHeight,
        );
        return Center(
          child: RepaintBoundary(
            key: widget.repaintKey,
            child: SizedBox(
              width: project.canvasWidth * scale,
              height: project.canvasHeight * scale,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: project.canvasWidth,
                  height: project.canvasHeight,
                  child: Container(
                    color: const Color(0xFF1A1A1F),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ..._buildOnionSkin(),
                        ..._buildLayers(),
                        if (controller.showSkeleton) ..._buildBoneSticks(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildOnionSkin() {
    if (!controller.onionSkin) return [];
    final prevMs = (controller.playheadMs - 120).clamp(0, project.durationMs);
    return controller.layersBackToFront
        .where((l) => l.visible && !l.isGroup && !l.isBone && l.imagePath != null)
        .map((layer) => Opacity(
              opacity: 0.25,
              child: _positionedLayer(layer, prevMs, tint: Colors.blueAccent),
            ))
        .toList();
  }

  List<Widget> _buildLayers() {
    return controller.layersBackToFront
        .where((l) => l.visible && !l.isGroup && !l.isBone && l.imagePath != null)
        .map((layer) => _positionedLayer(layer, controller.playheadMs))
        .toList();
  }

  /// Draws a simple stick (line + joint dot) for every bone so the rig is
  /// visible even when no art is attached yet.
  List<Widget> _buildBoneSticks() {
    final bones = project.layers.where((l) => l.isBone).toList();
    return bones.map((bone) {
      final world = worldMatrixAt(project, bone, controller.playheadMs);
      final origin = world.transform3(Vector3(0, 0, 0));
      final tip = world.transform3(Vector3(bone.boneLength, 0, 0));
      final selected = controller.selectedLayerId == bone.id;
      return Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _BonePainter(
              origin: Offset(origin.x, origin.y),
              tip: Offset(tip.x, tip.y),
              selected: selected,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _positionedLayer(LayerItem layer, int timeMs, {Color? tint}) {
    final world = worldMatrixAt(project, layer, timeMs);
    final opacity = worldOpacityAt(project, layer, timeMs);
    final selected = controller.selectedLayerId == layer.id;

    return Positioned(
      left: 0,
      top: 0,
      child: Transform(
        transform: world,
        alignment: Alignment.topLeft,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: layer.locked ? null : () => controller.selectLayer(layer.id),
            onScaleStart: layer.locked ? null : (d) => _onScaleStart(layer),
            onScaleUpdate: layer.locked ? null : (d) => _onScaleUpdate(layer, d),
            child: Container(
              width: layer.width,
              height: layer.height,
              decoration: selected
                  ? BoxDecoration(border: Border.all(color: Colors.deepPurpleAccent, width: 2))
                  : null,
              child: Image.file(File(layer.imagePath!), fit: BoxFit.fill,
                  color: tint, colorBlendMode: tint != null ? BlendMode.modulate : null),
            ),
          ),
        ),
      ),
    );
  }

  void _onScaleStart(LayerItem layer) {
    controller.selectLayer(layer.id);
    _gestureStartPose = poseAt(layer, controller.playheadMs);

    // Convert future screen-space drag deltas into this layer's
    // PARENT-local space by inverting the parent's world matrix. Without
    // this, dragging a part that's nested inside a rotated group would
    // move in the wrong direction on screen.
    final parent = project.byId(layer.parentId);
    final parentWorld = parent == null
        ? Matrix4.identity()
        : worldMatrixAt(project, parent, controller.playheadMs);
    _parentInverseAtGestureStart = Matrix4.inverted(parentWorld);
  }

  void _onScaleUpdate(LayerItem layer, ScaleUpdateDetails d) {
    final start = _gestureStartPose;
    final parentInv = _parentInverseAtGestureStart;
    if (start == null || parentInv == null) return;

    // d.focalPointDelta is a per-frame screen delta; project it into the
    // parent's local space (ignoring translation, direction only).
    final localDelta = parentInv.transform3(Vector3(d.focalPointDelta.dx, d.focalPointDelta.dy, 0)) -
        parentInv.transform3(Vector3.zero());

    final pose = poseAt(layer, controller.playheadMs);
    controller.applyLiveTransform(
      layer,
      x: pose.x + localDelta.x,
      y: pose.y + localDelta.y,
      rotationDeg: start.rotationDeg + (d.rotation * 180 / math.pi),
      scaleX: (start.scaleX * d.scale).clamp(0.05, 20.0),
      scaleY: (start.scaleY * d.scale).clamp(0.05, 20.0),
    );
  }
}

class _BonePainter extends CustomPainter {
  final Offset origin;
  final Offset tip;
  final bool selected;
  _BonePainter({required this.origin, required this.tip, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = selected ? Colors.orangeAccent : Colors.tealAccent.withOpacity(0.85)
      ..strokeWidth = selected ? 3 : 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(origin, tip, paint);
    canvas.drawCircle(origin, 5, Paint()..color = paint.color);
    canvas.drawCircle(tip, 3, Paint()..color = paint.color.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(covariant _BonePainter oldDelegate) =>
      oldDelegate.origin != origin || oldDelegate.tip != tip || oldDelegate.selected != selected;
}

