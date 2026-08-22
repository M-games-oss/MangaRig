import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'models.dart';

/// The fully-resolved LOCAL transform of a layer at a given moment in time
/// (i.e. relative to its own parent, not yet composed up the hierarchy).
class Pose {
  final double x, y, rotationDeg, rotationX, rotationY, scaleX, scaleY, opacity;
  const Pose({
    required this.x,
    required this.y,
    this.rotationDeg = 0,
    this.rotationX = 0,
    this.rotationY = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
  });
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Computes the interpolated LOCAL pose of [layer] at [timeMs] by finding
/// the two surrounding keyframes and blending them using the outgoing
/// keyframe's chosen easing curve.
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
      rotationX: k.rotationX,
      rotationY: k.rotationY,
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
      rotationX: k.rotationX,
      rotationY: k.rotationY,
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
    rotationX: _lerp(prev.rotationX, next.rotationX, t),
    rotationY: _lerp(prev.rotationY, next.rotationY, t),
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

/// Builds the LOCAL transform matrix for one layer's pose: translate to the
/// pose position, apply 3D tilt + Z rotation (around the layer's own pivot),
/// then scale.
Matrix4 _localMatrix(LayerItem layer, Pose pose) {
  final m = Matrix4.identity();
  m.translate(pose.x, pose.y);

  // Perspective: without this term, rotateX/rotateY just squash the layer
  // flat instead of looking like it's tilting away from the viewer.
  if (pose.rotationX != 0 || pose.rotationY != 0) {
    m.setEntry(3, 2, 0.0018);
  }
  m.rotateZ(pose.rotationDeg * math.pi / 180);
  m.rotateX(pose.rotationX * math.pi / 180);
  m.rotateY(pose.rotationY * math.pi / 180);
  m.scale(pose.scaleX, pose.scaleY);

  // Shift so the layer's own pivot (not its top-left corner) is the origin
  // we just positioned/rotated/scaled around.
  final pivotOffsetX = -layer.pivotX * layer.width;
  final pivotOffsetY = -layer.pivotY * layer.height;
  m.translate(pivotOffsetX, pivotOffsetY);
  return m;
}

/// Composes [layer]'s world transform by walking up through every
/// group/bone ancestor. This is the core of both grouping (move the group,
/// children move with it) and the skeleton system (rotate a bone, every
/// child bone/part parented under it swings with it -- forward kinematics).
Matrix4 worldMatrixAt(Project project, LayerItem layer, int timeMs) {
  final chain = <LayerItem>[layer];
  String? pid = layer.parentId;
  final seen = <String>{layer.id};
  while (pid != null) {
    final parent = project.byId(pid);
    if (parent == null || seen.contains(parent.id)) break; // guard against cycles
    chain.add(parent);
    seen.add(parent.id);
    pid = parent.parentId;
  }

  var world = Matrix4.identity();
  // Walk from the root ancestor down to the layer itself so each child's
  // local matrix is applied inside its parent's space.
  for (final node in chain.reversed) {
    world = world * _localMatrix(node, poseAt(node, timeMs));
  }
  return world;
}

/// Combined opacity down the chain (a hidden/faded group fades its
/// children too), used by the canvas when compositing.
double worldOpacityAt(Project project, LayerItem layer, int timeMs) {
  double opacity = 1;
  LayerItem? node = layer;
  final seen = <String>{};
  while (node != null && !seen.contains(node.id)) {
    seen.add(node.id);
    opacity *= poseAt(node, timeMs).opacity;
    node = project.byId(node.parentId);
  }
  return opacity;
}
