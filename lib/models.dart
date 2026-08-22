import 'package:uuid/uuid.dart';
import 'package:flutter/animation.dart';

const _uuid = Uuid();

/// Presets for the easing "graph" system. Each maps to a built-in Flutter
/// curve so we get smooth, good-looking motion without writing custom math.
enum EasingType {
  linear,
  easeIn,
  easeOut,
  easeInOut,
  bounce,
  elastic,
  blinkClose,
  blinkOpen,
}

Curve curveForEasing(EasingType e) {
  switch (e) {
    case EasingType.linear:
      return Curves.linear;
    case EasingType.easeIn:
      return Curves.easeIn;
    case EasingType.easeOut:
      return Curves.easeOut;
    case EasingType.easeInOut:
      return Curves.easeInOut;
    case EasingType.bounce:
      return Curves.bounceOut;
    case EasingType.elastic:
      return Curves.elasticOut;
    case EasingType.blinkClose:
      return Curves.easeInExpo;
    case EasingType.blinkOpen:
      return Curves.easeOutCubic;
  }
}

String easingLabel(EasingType e) {
  switch (e) {
    case EasingType.linear:
      return 'Linear';
    case EasingType.easeIn:
      return 'Ease In';
    case EasingType.easeOut:
      return 'Ease Out';
    case EasingType.easeInOut:
      return 'Ease In-Out';
    case EasingType.bounce:
      return 'Bounce';
    case EasingType.elastic:
      return 'Elastic';
    case EasingType.blinkClose:
      return 'Blink Close';
    case EasingType.blinkOpen:
      return 'Blink Open';
  }
}

/// A single pose snapshot in time for a layer. All transform properties
/// live together on one keyframe so beginners only ever think about
/// "where is this part at this moment" instead of juggling separate tracks.
///
/// [rotationDeg] is the in-plane (Z axis) rotation, same as the MVP.
/// [rotationX] / [rotationY] are new: a 3D tilt around the horizontal and
/// vertical axes, applied as a perspective transform at render time.
class Keyframe {
  String id;
  int timeMs;
  double x;
  double y;
  double rotationDeg;
  double rotationX;
  double rotationY;
  double scaleX;
  double scaleY;
  double opacity;

  /// Easing used for the segment leading FROM this keyframe TO the next one.
  EasingType easingOut;

  Keyframe({
    String? id,
    required this.timeMs,
    required this.x,
    required this.y,
    this.rotationDeg = 0,
    this.rotationX = 0,
    this.rotationY = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
    this.easingOut = EasingType.easeInOut,
  }) : id = id ?? _uuid.v4();

  Keyframe copy() => Keyframe(
        timeMs: timeMs,
        x: x,
        y: y,
        rotationDeg: rotationDeg,
        rotationX: rotationX,
        rotationY: rotationY,
        scaleX: scaleX,
        scaleY: scaleY,
        opacity: opacity,
        easingOut: easingOut,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timeMs': timeMs,
        'x': x,
        'y': y,
        'rotationDeg': rotationDeg,
        'rotationX': rotationX,
        'rotationY': rotationY,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'opacity': opacity,
        'easingOut': easingOut.name,
      };

  factory Keyframe.fromJson(Map<String, dynamic> j) => Keyframe(
        id: j['id'],
        timeMs: j['timeMs'],
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        rotationDeg: (j['rotationDeg'] as num?)?.toDouble() ?? 0,
        rotationX: (j['rotationX'] as num?)?.toDouble() ?? 0,
        rotationY: (j['rotationY'] as num?)?.toDouble() ?? 0,
        scaleX: (j['scaleX'] as num).toDouble(),
        scaleY: (j['scaleY'] as num).toDouble(),
        opacity: (j['opacity'] as num).toDouble(),
        easingOut: EasingType.values.firstWhere(
          (e) => e.name == j['easingOut'],
          orElse: () => EasingType.easeInOut,
        ),
      );
}

/// One node in the rig. This single class now covers three roles that used
/// to be separate concepts, because they all boil down to "a node with a
/// transform that can have children":
///
/// - A normal **image part** (imagePath set, isGroup/isBone false).
/// - A **group** (isGroup true, no image) -- purely organizational, lets you
///   move/rotate several parts together by moving the group.
/// - A **bone** (isBone true, no image) -- renders as a stick from its pivot
///   out to [boneLength] at its current rotation, and (like a group) drives
///   any children parented to it. Chaining bones together is how the
///   skeleton/FK rig works: rotate a shoulder bone and everything parented
///   under it -- forearm bone, hand, sleeve art -- swings with it.
///
/// [parentId] is what makes hierarchy possible: a layer's final on-canvas
/// transform is its parent's transform composed with its own local one
/// (see `interpolation.dart` -> `worldMatrixAt`).
class LayerItem {
  String id;
  String name;

  /// Null for groups and bones -- they have no image of their own.
  String? imagePath;

  String? parentId;
  bool isGroup;
  bool isBone;

  /// Length in canvas px of the bone stick, only meaningful when [isBone].
  double boneLength;

  /// Pivot point as a 0..1 fraction of the image's own width/height.
  /// For bones/groups this is unused (they pivot at their own x/y).
  double pivotX;
  double pivotY;

  double width;
  double height;
  int zIndex;
  bool isEyeLayer;
  bool locked;
  bool visible;
  List<Keyframe> keyframes;

  /// Eye-rig references. Set on whichever layer you invoke "Blink" from
  /// (typically a group wrapping the three parts). Once set they're reused
  /// every time you re-open the Blink Helper for this layer.
  String? upperLidId;
  String? lowerLidId;
  String? eyeballId;

  LayerItem({
    String? id,
    required this.name,
    this.imagePath,
    this.parentId,
    this.isGroup = false,
    this.isBone = false,
    this.boneLength = 120,
    this.pivotX = 0.5,
    this.pivotY = 0.5,
    this.width = 0,
    this.height = 0,
    this.zIndex = 0,
    this.isEyeLayer = false,
    this.locked = false,
    this.visible = true,
    List<Keyframe>? keyframes,
    this.upperLidId,
    this.lowerLidId,
    this.eyeballId,
  })  : id = id ?? _uuid.v4(),
        keyframes = keyframes ?? [];

  bool get hasEyeRig => upperLidId != null && lowerLidId != null && eyeballId != null;

  void sortKeyframes() => keyframes.sort((a, b) => a.timeMs.compareTo(b.timeMs));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'parentId': parentId,
        'isGroup': isGroup,
        'isBone': isBone,
        'boneLength': boneLength,
        'pivotX': pivotX,
        'pivotY': pivotY,
        'width': width,
        'height': height,
        'zIndex': zIndex,
        'isEyeLayer': isEyeLayer,
        'locked': locked,
        'visible': visible,
        'keyframes': keyframes.map((k) => k.toJson()).toList(),
        'upperLidId': upperLidId,
        'lowerLidId': lowerLidId,
        'eyeballId': eyeballId,
      };

  factory LayerItem.fromJson(Map<String, dynamic> j) => LayerItem(
        id: j['id'],
        name: j['name'],
        imagePath: j['imagePath'],
        parentId: j['parentId'],
        isGroup: j['isGroup'] ?? false,
        isBone: j['isBone'] ?? false,
        boneLength: (j['boneLength'] as num?)?.toDouble() ?? 120,
        pivotX: (j['pivotX'] as num).toDouble(),
        pivotY: (j['pivotY'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        height: (j['height'] as num).toDouble(),
        zIndex: j['zIndex'] ?? 0,
        isEyeLayer: j['isEyeLayer'] ?? false,
        locked: j['locked'] ?? false,
        visible: j['visible'] ?? true,
        keyframes: (j['keyframes'] as List)
            .map((k) => Keyframe.fromJson(k as Map<String, dynamic>))
            .toList(),
        upperLidId: j['upperLidId'],
        lowerLidId: j['lowerLidId'],
        eyeballId: j['eyeballId'],
      );
}

class Project {
  String id;
  String name;
  int durationMs;
  int fps;
  double canvasWidth;
  double canvasHeight;
  List<LayerItem> layers;

  Project({
    String? id,
    required this.name,
    this.durationMs = 3000,
    this.fps = 24,
    this.canvasWidth = 800,
    this.canvasHeight = 1000,
    List<LayerItem>? layers,
  })  : id = id ?? _uuid.v4(),
        layers = layers ?? [];

  LayerItem? byId(String? id) {
    if (id == null) return null;
    for (final l in layers) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// All descendants of [parentId] (direct + nested), used when deleting or
  /// moving a group/bone so its children come along.
  List<LayerItem> descendantsOf(String parentId) {
    final result = <LayerItem>[];
    void collect(String pid) {
      for (final l in layers) {
        if (l.parentId == pid) {
          result.add(l);
          collect(l.id);
        }
      }
    }

    collect(parentId);
    return result;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'durationMs': durationMs,
        'fps': fps,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'layers': layers.map((l) => l.toJson()).toList(),
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'],
        name: j['name'],
        durationMs: j['durationMs'] ?? 3000,
        fps: j['fps'] ?? 24,
        canvasWidth: (j['canvasWidth'] as num?)?.toDouble() ?? 800,
        canvasHeight: (j['canvasHeight'] as num?)?.toDouble() ?? 1000,
        layers: (j['layers'] as List)
            .map((l) => LayerItem.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}
