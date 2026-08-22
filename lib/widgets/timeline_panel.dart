import 'dart:io';
import 'package:flutter/material.dart';
import '../models.dart';
import '../editor_controller.dart';

const double _labelWidth = 150;
const double _rowHeight = 46;
const double _rulerHeight = 24;

class TimelinePanel extends StatelessWidget {
  final EditorController controller;
  const TimelinePanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final project = controller.project;
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = math_max(constraints.maxWidth - _labelWidth, 50.0);
        final pxPerMs = trackWidth / project.durationMs;

        return Container(
          color: const Color(0xFF1B1B20),
          child: Column(
            children: [
              // Ruler + scrub area
              Row(
                children: [
                  SizedBox(width: _labelWidth, height: _rulerHeight),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _scrub(d.localPosition.dx, pxPerMs),
                      onPanUpdate: (d) => _scrub(d.localPosition.dx, pxPerMs),
                      child: SizedBox(
                        height: _rulerHeight,
                        width: trackWidth,
                        child: CustomPaint(
                          painter: _RulerPainter(durationMs: project.durationMs, pxPerMs: pxPerMs),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1, color: Colors.white12),
              // Layer rows
              Expanded(
                child: project.layers.isEmpty
                    ? const Center(
                        child: Text('Add a layer to see its timeline track',
                            style: TextStyle(color: Colors.white38)),
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: controller.layersBackToFront.length,
                        onReorder: (oldIndex, newIndex) {
                          // Displayed order is front-most first; reorderLayers
                          // expects back-to-front, so convert both ways.
                          final displayed = controller.layersBackToFront.reversed.toList();
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = displayed.removeAt(oldIndex);
                          displayed.insert(newIndex, item);
                          controller.reorderLayers(displayed.reversed.toList());
                        },
                        itemBuilder: (context, index) {
                          // Front-most first in the visual list.
                          final layer = controller.layersBackToFront.reversed.toList()[index];
                          return Container(
                            key: ValueKey(layer.id),
                            height: _rowHeight,
                            decoration: BoxDecoration(
                              color: layer.id == controller.selectedLayerId
                                  ? Colors.deepPurple.withOpacity(0.18)
                                  : Colors.transparent,
                              border: const Border(bottom: BorderSide(color: Colors.white10)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: _labelWidth,
                                  child: _LayerLabel(
                                    layer: layer,
                                    controller: controller,
                                    dragHandleIndex: index,
                                  ),
                                ),
                                Expanded(
                                  child: SizedBox(
                                    height: _rowHeight,
                                    width: trackWidth,
                                    child: _KeyframeTrack(
                                      layer: layer,
                                      controller: controller,
                                      pxPerMs: pxPerMs,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrub(double localX, double pxPerMs) {
    final ms = (localX / pxPerMs).round();
    controller.setPlayhead(ms);
  }
}

double math_max(double a, double b) => a > b ? a : b;

class _LayerLabel extends StatelessWidget {
  final LayerItem layer;
  final EditorController controller;
  final int dragHandleIndex;
  const _LayerLabel({required this.layer, required this.controller, required this.dragHandleIndex});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => controller.selectLayer(layer.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: dragHandleIndex,
              child: const Icon(Icons.drag_indicator, size: 16, color: Colors.white30),
            ),
            const SizedBox(width: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(layer.imagePath), width: 26, height: 26, fit: BoxFit.cover),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                layer.name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (layer.isEyeLayer)
              const Padding(
                padding: EdgeInsets.only(right: 2),
                child: Icon(Icons.remove_red_eye, size: 14, color: Colors.tealAccent),
              ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(layer.visible ? Icons.visibility : Icons.visibility_off,
                  size: 15, color: Colors.white54),
              onPressed: () => controller.toggleVisible(layer),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyframeTrack extends StatelessWidget {
  final LayerItem layer;
  final EditorController controller;
  final double pxPerMs;
  const _KeyframeTrack({required this.layer, required this.controller, required this.pxPerMs});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // connecting line
        Positioned(
          left: 0,
          right: 0,
          top: _rowHeight / 2,
          child: Container(height: 1, color: Colors.white12),
        ),
        for (final k in layer.keyframes)
          Positioned(
            left: (k.timeMs * pxPerMs) - 7,
            top: _rowHeight / 2 - 7,
            child: _KeyframeDot(
              keyframe: k,
              layer: layer,
              controller: controller,
              pxPerMs: pxPerMs,
            ),
          ),
      ],
    );
  }
}

class _KeyframeDot extends StatelessWidget {
  final Keyframe keyframe;
  final LayerItem layer;
  final EditorController controller;
  final double pxPerMs;
  const _KeyframeDot({
    required this.keyframe,
    required this.layer,
    required this.controller,
    required this.pxPerMs,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = keyframe.id == controller.selectedKeyframeId;
    return GestureDetector(
      onTap: () {
        controller.selectLayer(layer.id);
        controller.selectKeyframe(keyframe.id);
        controller.setPlayhead(keyframe.timeMs);
      },
      onPanUpdate: (d) {
        final newTime = keyframe.timeMs + (d.delta.dx / pxPerMs).round();
        controller.moveKeyframeTime(layer, keyframe.id, newTime);
      },
      onLongPress: () => _confirmDelete(context),
      child: Transform.rotate(
        angle: 0.785398, // 45deg -> diamond
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isSelected ? Colors.orangeAccent : Colors.deepPurpleAccent,
            border: Border.all(color: Colors.white, width: 1.2),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Delete keyframe?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              controller.deleteKeyframe(layer, keyframe.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final int durationMs;
  final double pxPerMs;
  _RulerPainter({required this.durationMs, required this.pxPerMs});

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()..color = Colors.white24;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const stepMs = 500;
    for (int t = 0; t <= durationMs; t += stepMs) {
      final x = t * pxPerMs;
      final isSecond = t % 1000 == 0;
      canvas.drawLine(
        Offset(x, isSecond ? 4 : 12),
        Offset(x, size.height),
        tickPaint,
      );
      if (isSecond) {
        textPainter.text = TextSpan(
          text: '${(t / 1000).toStringAsFixed(1)}s',
          style: const TextStyle(color: Colors.white38, fontSize: 9),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + 2, 0));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.durationMs != durationMs || oldDelegate.pxPerMs != pxPerMs;
}

/// Playhead overlay drawn above the timeline (used by EditorScreen so it can
/// span the ruler + all rows in one line).
class PlayheadOverlay extends StatelessWidget {
  final EditorController controller;
  const PlayheadOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final trackWidth = math_max(constraints.maxWidth - _labelWidth, 50.0);
      final pxPerMs = trackWidth / controller.project.durationMs;
      final x = _labelWidth + controller.playheadMs * pxPerMs;
      return IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: x - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: Colors.redAccent),
            ),
          ],
        ),
      );
    });
  }
}
