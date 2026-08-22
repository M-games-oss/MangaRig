import 'models.dart';

/// The fully-resolved transform of a layer at a given moment in time.
class Pose {
  final double x, y, rotationDeg, scaleX, scaleY, opacity;
  const Pose({
    required this.x,
    required this.y,
    this.rotationDeg = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
  });
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Computes the interpolated pose of [layer] at [timeMs] by finding the two
/// surrounding keyframes and blending them using the outgoing keyframe's
/// chosen easing curve.
Pose poseAt(LayerItem layer, int timeMs) {
  final kfs = layer.keyframes;
  if (kfs.isEmpty) {
    return const Pose(x: 0, y: 0);
  }
  if (kfs.length == 1 || timeMs <= kfs.first.timeMs) {
    final k = kfs.first;
    return Pose(
      x: k.x,
      y: k.y,
      rotationDeg: k.rotationDeg,
      scaleX: k.scaleX,
      scaleY: k.scaleY,
      opacity: k.opacity,
    );
  }
  if (timeMs >= kfs.last.timeMs) {
    final k = kfs.last;
    return Pose(
      x: k.x,
      y: k.y,
      rotationDeg: k.rotationDeg,
      scaleX: k.scaleX,
      scaleY: k.scaleY,
      opacity: k.opacity,
    );
  }

  Keyframe prev = kfs.first;
  Keyframe next = kfs.last;
  for (int i = 0; i < kfs.length - 1; i++) {
    if (timeMs >= kfs[i].timeMs && timeMs <= kfs[i + 1].timeMs) {
      prev = kfs[i];
      next = kfs[i + 1];
      break;
    }
  }

  final span = (next.timeMs - prev.timeMs).clamp(1, 1 << 30);
  final rawT = (timeMs - prev.timeMs) / span;
  final t = curveForEasing(prev.easingOut).transform(rawT.clamp(0.0, 1.0));

  return Pose(
    x: _lerp(prev.x, next.x, t),
    y: _lerp(prev.y, next.y, t),
    rotationDeg: _lerp(prev.rotationDeg, next.rotationDeg, t),
    scaleX: _lerp(prev.scaleX, next.scaleX, t),
    scaleY: _lerp(prev.scaleY, next.scaleY, t),
    opacity: _lerp(prev.opacity, next.opacity, t),
  );
}

/// Returns the keyframe that sits exactly at [timeMs], if any.
Keyframe? keyframeAtExactTime(LayerItem layer, int timeMs) {
  for (final k in layer.keyframes) {
    if (k.timeMs == timeMs) return k;
  }
  return null;
}
