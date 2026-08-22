import 'package:flutter/material.dart';
import '../models.dart';

/// Row of small live curve previews for each [EasingType]. Tapping one
/// applies it -- no manual bezier fiddling required.
class EasingCurvePicker extends StatelessWidget {
  final EasingType selected;
  final ValueChanged<EasingType> onSelected;
  const EasingCurvePicker({super.key, required this.selected, required this.onSelected});

  static const _presets = [
    EasingType.linear,
    EasingType.easeIn,
    EasingType.easeOut,
    EasingType.easeInOut,
    EasingType.bounce,
    EasingType.elastic,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _presets.map((e) {
          final isSelected = e == selected;
          return GestureDetector(
            onTap: () => onSelected(e),
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple.withOpacity(0.35) : Colors.white10,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? Colors.deepPurpleAccent : Colors.white12,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 40,
                    height: 24,
                    child: CustomPaint(painter: _CurvePainter(curveForEasing(e))),
                  ),
                  Text(
                    easingLabel(e),
                    style: const TextStyle(color: Colors.white60, fontSize: 8),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final Curve curve;
  _CurvePainter(this.curve);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurpleAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path();
    const steps = 24;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final y = curve.transform(t).clamp(0.0, 1.0);
      final point = Offset(t * size.width, size.height - y * size.height);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CurvePainter oldDelegate) => oldDelegate.curve != curve;
}
