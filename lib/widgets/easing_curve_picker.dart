import 'package:flutter/material.dart';
import '../models.dart';

/// A row of small graph previews -- the "simple graph system" the animator
/// can tap instead of hand-tweaking bezier math. Each thumbnail is drawn by
/// sampling the real Flutter Curve so what you see is what you get.
class EasingCurvePicker extends StatelessWidget {
  final EasingType selected;
  final ValueChanged<EasingType> onSelected;
  final List<EasingType> options;

  const EasingCurvePicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.options = const [
      EasingType.linear,
      EasingType.easeIn,
      EasingType.easeOut,
      EasingType.easeInOut,
      EasingType.bounce,
      EasingType.elastic,
    ],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = options[i];
          final isSelected = type == selected;
          return GestureDetector(
            onTap: () => onSelected(type),
            child: Container(
              width: 58,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.deepPurple.withOpacity(0.25) : Colors.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? Colors.deepPurpleAccent : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 44,
                    height: 34,
                    child: CustomPaint(painter: _CurvePainter(curveForEasing(type))),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    easingLabel(type),
                    style: const TextStyle(fontSize: 9, color: Colors.white70),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  final Curve curve;
  _CurvePainter(this.curve);

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);

    final path = Path();
    const steps = 24;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      double v;
      try {
        v = curve.transform(t);
      } catch (_) {
        v = t;
      }
      final px = t * size.width;
      final py = size.height - (v.clamp(-0.3, 1.3) * size.height);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    final linePaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _CurvePainter oldDelegate) => oldDelegate.curve != curve;
}
