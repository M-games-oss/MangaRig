import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models.dart';
import '../editor_controller.dart';
import '../interpolation.dart';

/// The live preview + rigging surface. One finger drags a part around its
/// pivot; two fingers pinch/rotate it in place, exactly like most touch
/// design apps. Every gesture writes (or updates) a keyframe at the current
/// playhead, so posing on the canvas IS keyframing -- no separate mode.
class CanvasStage extends StatelessWidget {
  final EditorController controller;
  final GlobalKey repaintKey;

  const CanvasStage({super.key, required this.controller, required this.repaintKey});

  @override
  Widget build(BuildContext context) {
    final project = controller.project;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: const Color(0xFF15151A),
          alignment: Alignment.center,
          child: RepaintBoundary(
            key: repaintKey,
            child: FittedBox(
              fit: BoxFit.contain,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.selectLayer(null),
                child: Container(
                  width: project.canvasWidth,
                  height: project.canvasHeight,
                  color: Colors.white,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (controller.onionSkin) _buildOnionSkin(),
                      for (final layer in controller.layersBackToFront)
                        if (layer.visible) _buildLayer(context, layer),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnionSkin() {
    final ghostTime = math.max(0, controller.playheadMs - 120);
    return IgnorePointer(
      child: Opacity(
        opacity: 0.28,
        child: Stack(
          children: [
            for (final layer in controller.layersBackToFront)
              if (layer.visible) _positionedLayer(layer, ghostTime, interactive: false),
          ],
        ),
      ),
    );
  }

  Widget _buildLayer(BuildContext context, LayerItem layer) {
    return _positionedLayer(layer, controller.playheadMs, interactive: true);
  }

  Widget _positionedLayer(LayerItem layer, int timeMs, {required bool interactive}) {
    final pose = poseAt(layer, timeMs);
    final isSelected = interactive && layer.id == controller.selectedLayerId;
    final left = pose.x - layer.pivotX * layer.width;
    final top = pose.y - layer.pivotY * layer.height;

    Widget image = Image.file(
      File(layer.imagePath),
      width: layer.width,
      height: layer.height,
      fit: BoxFit.fill,
      errorBuilder: (_, __, ___) => Container(
        width: layer.width,
        height: layer.height,
        color: Colors.pink.withOpacity(0.2),
      ),
    );

    Widget transformed = Transform(
      alignment: FractionalOffset(layer.pivotX, layer.pivotY),
      transform: Matrix4.identity()
        ..rotateZ(pose.rotationDeg * math.pi / 180)
        ..scale(pose.scaleX, pose.scaleY),
      child: Opacity(
        opacity: pose.opacity.clamp(0.0, 1.0),
        child: isSelected
            ? DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.deepPurpleAccent, width: 2),
                ),
                child: image,
              )
            : image,
      ),
    );

    if (!interactive || layer.locked) {
      return Positioned(left: left, top: top, child: transformed);
    }

    return Positioned(
      left: left,
      top: top,
      child: _DraggableLayer(
        layer: layer,
        controller: controller,
        child: transformed,
      ),
    );
  }
}

class _DraggableLayer extends StatefulWidget {
  final LayerItem layer;
  final EditorController controller;
  final Widget child;
  const _DraggableLayer({required this.layer, required this.controller, required this.child});

  @override
  State<_DraggableLayer> createState() => _DraggableLayerState();
}

class _DraggableLayerState extends State<_DraggableLayer> {
  Offset _startLocal = Offset.zero;
  late double _startX, _startY, _startRotation, _startScaleX, _startScaleY;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.controller.selectLayer(widget.layer.id),
      onScaleStart: (details) {
        widget.controller.selectLayer(widget.layer.id);
        final pose = poseAt(widget.layer, widget.controller.playheadMs);
        _startLocal = details.localFocalPoint;
        _startX = pose.x;
        _startY = pose.y;
        _startRotation = pose.rotationDeg;
        _startScaleX = pose.scaleX;
        _startScaleY = pose.scaleY;
      },
      onScaleUpdate: (details) {
        final delta = details.localFocalPoint - _startLocal;
        final newX = _startX + delta.dx;
        final newY = _startY + delta.dy;
        final newRotation = _startRotation + details.rotation * 180 / math.pi;
        final newScaleX = (_startScaleX * details.scale).clamp(0.05, 8.0);
        final newScaleY = (_startScaleY * details.scale).clamp(0.05, 8.0);
        widget.controller.applyLiveTransform(
          widget.layer,
          x: newX,
          y: newY,
          rotationDeg: newRotation,
          scaleX: newScaleX,
          scaleY: newScaleY,
        );
      },
      child: widget.child,
    );
  }
}
