import 'package:flutter/material.dart';
import '../models.dart';
import '../editor_controller.dart';

/// Compact per-layer timeline: a scrubbable ruler up top, then one row per
/// layer showing its keyframes as diamonds. Tap a diamond to select it,
/// drag to retime it, long-press to delete it. Tap/drag the ruler to move
/// the playhead.
class TimelinePanel extends StatelessWidget {
  final EditorController controller;
  const TimelinePanel({super.key, required this.controller});

  static const double pxPerMs = 0.12;
  static const double rowHeight = 34;
  static const double labelWidth = 108;

  @override
  Widget build(BuildContext context) {
    final project = controller.project;
    final layers = controller.layersBackToFront.where((l) => !l.isGroup).toList();
    final totalWidth = project.durationMs * pxPerMs;

    return Container(
      color: const Color(0xFF141418),
      child: Column(
        children: [
          _buildRuler(context, totalWidth),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: layers.map((l) => _buildRow(context, l, totalWidth)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuler(BuildContext context, double totalWidth) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: labelWidth),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => _scrubFromLocalX(d.localPosition.dx),
                onTapDown: (d) => _scrubFromLocalX(d.localPosition.dx),
                child: SizedBox(
                  width: totalWidth + 40,
                  child: CustomPaint(
                    painter: _RulerPainter(
                      durationMs: controller.project.durationMs,
                      pxPerMs: pxPerMs,
                      playheadMs: controller.playheadMs,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrubFromLocalX(double localX) {
    final ms = (localX / pxPerMs).round();
    controller.setPlayhead(ms);
  }

  Widget _buildRow(BuildContext context, LayerItem layer, double totalWidth) {
    IconData icon;
    if (layer.isBone) {
      icon = Icons.accessibility_new;
    } else if (layer.isEyeLayer) {
      icon = Icons.remove_red_eye;
    } else {
      icon = Icons.image_outlined;
    }
    return SizedBox(
      height: rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: GestureDetector(
              onTap: () => controller.selectLayer(layer.id),
              child: Container(
                color: controller.selectedLayerId == layer.id
                    ? Colors.deepPurple.withOpacity(0.25)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(icon, size: 13, color: Colors.white54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        layer.name,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth + 40,
                height: rowHeight,
                child: Stack(
                  children: [
                    ...layer.keyframes.map((k) => _buildDiamond(context, layer, k)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiamond(BuildContext context, LayerItem layer, Keyframe k) {
    final selected = controller.selectedKeyframeId == k.id;
    return Positioned(
      left: k.timeMs * pxPerMs - 6,
      top: rowHeight / 2 - 6,
      child: GestureDetector(
        onTap: () => controller.selectKeyframe(k.id),
        onLongPress: () => controller.deleteKeyframe(layer, k.id),
        onPanUpdate: (d) {
          final newMs = (k.timeMs + d.delta.dx / pxPerMs).round();
          controller.moveKeyframeTime(layer, k.id, newMs);
        },
        child: Transform.rotate(
          angle: 0.785398, // 45deg
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: selected ? Colors.orangeAccent : Colors.deepPurpleAccent,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final int durationMs;
  final double pxPerMs;
  final int playheadMs;
  _RulerPainter({required this.durationMs, required this.pxPerMs, required this.playheadMs});

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()..color = Colors.white24;
    final textStyle = const TextStyle(color: Colors.white38, fontSize: 9);
    const stepMs = 500;
    for (int t = 0; t <= durationMs; t += stepMs) {
      final x = t * pxPerMs;
      canvas.drawLine(Offset(x, 18), Offset(x, 28), tickPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${(t / 1000).toStringAsFixed(1)}s', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 2, 4));
    }
    final playheadX = playheadMs * pxPerMs;
    canvas.drawLine(
      Offset(playheadX, 0),
      Offset(playheadX, 28),
      Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) =>
      oldDelegate.playheadMs != playheadMs || oldDelegate.durationMs != durationMs;
}
