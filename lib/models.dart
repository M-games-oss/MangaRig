import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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
/// (position, rotation, scale, opacity) live together on one keyframe so
/// beginners only ever think about "where is this limb at this moment"
/// instead of juggling separate tracks per property.
class Keyframe {
  String id;
  int timeMs;
  double x;
  double y;
  double rotationDeg;
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
    this.scaleX = 1,
    this.scaleY = 1,
    this.opacity = 1,
    this.easingOut = EasingType.easeInOut,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'timeMs': timeMs,
        'x': x,
        'y': y,
        'rotationDeg': rotationDeg,
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
        rotationDeg: (j['rotationDeg'] as num).toDouble(),
        scaleX: (j['scaleX'] as num).toDouble(),
        scaleY: (j['scaleY'] as num).toDouble(),
        opacity: (j['opacity'] as num).toDouble(),
        easingOut: EasingType.values.firstWhere(
          (e) => e.name == j['easingOut'],
          orElse: () => EasingType.easeInOut,
        ),
      );
}

/// One image "part" (a limb, eye, head, torso cut-out, etc). Has a pivot
/// point so it can be rigged/rotated naturally around a joint.
class LayerItem {
  String id;
  String name;
  String imagePath;

  /// Pivot point as a 0..1 fraction of the image's own width/height.
  double pivotX;
  double pivotY;

  double width;
  double height;
  int zIndex;
  bool isEyeLayer;
  bool locked;
  bool visible;
  List<Keyframe> keyframes;

  LayerItem({
    String? id,
    required this.name,
    required this.imagePath,
    this.pivotX = 0.5,
    this.pivotY = 0.5,
    required this.width,
    required this.height,
    this.zIndex = 0,
    this.isEyeLayer = false,
    this.locked = false,
    this.visible = true,
    List<Keyframe>? keyframes,
  })  : id = id ?? _uuid.v4(),
        keyframes = keyframes ?? [];

  void sortKeyframes() => keyframes.sort((a, b) => a.timeMs.compareTo(b.timeMs));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'pivotX': pivotX,
        'pivotY': pivotY,
        'width': width,
        'height': height,
        'zIndex': zIndex,
        'isEyeLayer': isEyeLayer,
        'locked': locked,
        'visible': visible,
        'keyframes': keyframes.map((k) => k.toJson()).toList(),
      };

  factory LayerItem.fromJson(Map<String, dynamic> j) => LayerItem(
        id: j['id'],
        name: j['name'],
        imagePath: j['imagePath'],
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
