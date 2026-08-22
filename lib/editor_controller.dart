import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'models.dart';
import 'storage.dart';
import 'interpolation.dart';

class EditorController extends ChangeNotifier {
  Project project;
  String? selectedLayerId;
  String? selectedKeyframeId;
  int playheadMs = 0;
  bool isPlaying = false;
  bool onionSkin = false;
  bool loop = true;
  Timer? _ticker;

  EditorController(this.project);

  LayerItem? get selectedLayer {
    if (selectedLayerId == null) return null;
    for (final l in project.layers) {
      if (l.id == selectedLayerId) return l;
    }
    return null;
  }

  List<LayerItem> get layersBackToFront {
    final list = [...project.layers];
    list.sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return list;
  }

  void selectLayer(String? id) {
    selectedLayerId = id;
    selectedKeyframeId = null;
    notifyListeners();
  }

  void selectKeyframe(String? id) {
    selectedKeyframeId = id;
    notifyListeners();
  }

  void setPlayhead(int ms) {
    playheadMs = ms.clamp(0, project.durationMs);
    notifyListeners();
  }

  void togglePlay() {
    isPlaying = !isPlaying;
    if (isPlaying) {
      _startTicking();
    } else {
      _ticker?.cancel();
    }
    notifyListeners();
  }

  void _startTicking() {
    const frameRate = Duration(milliseconds: 16);
    _ticker?.cancel();
    _ticker = Timer.periodic(frameRate, (_) {
      int next = playheadMs + 16;
      if (next >= project.durationMs) {
        if (loop) {
          next = 0;
        } else {
          next = project.durationMs;
          isPlaying = false;
          _ticker?.cancel();
        }
      }
      playheadMs = next;
      notifyListeners();
    });
  }

  void stopPlayback() {
    isPlaying = false;
    _ticker?.cancel();
  }

  Future<String> importImage(File file) => ProjectStorage.importImage(project.id, file);

  void addLayer(LayerItem layer) {
    project.layers.add(layer);
    selectedLayerId = layer.id;
    save();
    notifyListeners();
  }

  void removeLayer(String id) {
    project.layers.removeWhere((l) => l.id == id);
    if (selectedLayerId == id) {
      selectedLayerId = null;
      selectedKeyframeId = null;
    }
    save();
    notifyListeners();
  }

  void toggleVisible(LayerItem layer) {
    layer.visible = !layer.visible;
    save();
    notifyListeners();
  }

  void toggleLocked(LayerItem layer) {
    layer.locked = !layer.locked;
    save();
    notifyListeners();
  }

  void toggleEyeLayer(LayerItem layer) {
    layer.isEyeLayer = !layer.isEyeLayer;
    save();
    notifyListeners();
  }

  void renameLayer(LayerItem layer, String newName) {
    layer.name = newName;
    save();
    notifyListeners();
  }

  void setPivot(LayerItem layer, double px, double py) {
    layer.pivotX = px.clamp(0.0, 1.0);
    layer.pivotY = py.clamp(0.0, 1.0);
    save();
    notifyListeners();
  }

  /// Moves a layer to the front (top of the list = highest zIndex).
  void reorderLayers(List<LayerItem> newOrderBackToFront) {
    for (int i = 0; i < newOrderBackToFront.length; i++) {
      newOrderBackToFront[i].zIndex = i;
    }
    save();
    notifyListeners();
  }

  /// Adds a new keyframe at [timeMs], or updates one that's already there.
  Keyframe upsertKeyframe(
    LayerItem layer,
    int timeMs, {
    required double x,
    required double y,
    double rotationDeg = 0,
    double scaleX = 1,
    double scaleY = 1,
    double opacity = 1,
    EasingType? easing,
  }) {
    Keyframe? existing = keyframeAtExactTime(layer, timeMs);
    if (existing != null) {
      existing.x = x;
      existing.y = y;
      existing.rotationDeg = rotationDeg;
      existing.scaleX = scaleX;
      existing.scaleY = scaleY;
      existing.opacity = opacity;
      if (easing != null) existing.easingOut = easing;
    } else {
      existing = Keyframe(
        timeMs: timeMs,
        x: x,
        y: y,
        rotationDeg: rotationDeg,
        scaleX: scaleX,
        scaleY: scaleY,
        opacity: opacity,
        easingOut: easing ?? EasingType.easeInOut,
      );
      layer.keyframes.add(existing);
    }
    layer.sortKeyframes();
    selectedKeyframeId = existing.id;
    save();
    notifyListeners();
    return existing;
  }

  /// Convenience used by the canvas drag/pinch gesture: nudges (or creates)
  /// the keyframe at the current playhead relative to its current pose.
  void applyLiveTransform(
    LayerItem layer, {
    required double x,
    required double y,
    required double rotationDeg,
    required double scaleX,
    required double scaleY,
  }) {
    final pose = poseAt(layer, playheadMs);
    upsertKeyframe(
      layer,
      playheadMs,
      x: x,
      y: y,
      rotationDeg: rotationDeg,
      scaleX: scaleX,
      scaleY: scaleY,
      opacity: pose.opacity,
    );
  }

  /// Freezes the layer's current interpolated pose into a real keyframe at
  /// the playhead -- the "+" keyframe button beginners use most.
  void addKeyframeAtPlayhead(LayerItem layer) {
    final pose = poseAt(layer, playheadMs);
    upsertKeyframe(
      layer,
      playheadMs,
      x: pose.x,
      y: pose.y,
      rotationDeg: pose.rotationDeg,
      scaleX: pose.scaleX,
      scaleY: pose.scaleY,
      opacity: pose.opacity,
    );
  }

  void deleteKeyframe(LayerItem layer, String keyframeId) {
    layer.keyframes.removeWhere((k) => k.id == keyframeId);
    if (selectedKeyframeId == keyframeId) selectedKeyframeId = null;
    save();
    notifyListeners();
  }

  void moveKeyframeTime(LayerItem layer, String keyframeId, int newTimeMs) {
    Keyframe? k;
    for (final kf in layer.keyframes) {
      if (kf.id == keyframeId) k = kf;
    }
    if (k == null) return;
    k.timeMs = newTimeMs.clamp(0, project.durationMs);
    layer.sortKeyframes();
    save();
    notifyListeners();
  }

  void setKeyframeEasing(LayerItem layer, String keyframeId, EasingType easing) {
    Keyframe? k;
    for (final kf in layer.keyframes) {
      if (kf.id == keyframeId) k = kf;
    }
    if (k == null) return;
    k.easingOut = easing;
    save();
    notifyListeners();
  }

  /// The "easy blink" helper: inserts an open -> closed -> open sequence of
  /// keyframes centered on the current playhead. Uses fast-close / slower
  /// open easing presets so it reads as a natural blink automatically.
  void addBlink(LayerItem layer, {int halfDurationMs = 90}) {
    final center = playheadMs;
    final startT = (center - halfDurationMs).clamp(0, project.durationMs);
    final endT = (center + halfDurationMs).clamp(0, project.durationMs);
    final base = poseAt(layer, center);

    upsertKeyframe(
      layer,
      startT,
      x: base.x,
      y: base.y,
      rotationDeg: base.rotationDeg,
      scaleX: base.scaleX,
      scaleY: base.scaleY,
      opacity: base.opacity,
      easing: EasingType.blinkClose,
    );
    upsertKeyframe(
      layer,
      center,
      x: base.x,
      y: base.y,
      rotationDeg: base.rotationDeg,
      scaleX: base.scaleX,
      scaleY: 0.05,
      opacity: base.opacity,
      easing: EasingType.blinkOpen,
    );
    upsertKeyframe(
      layer,
      endT,
      x: base.x,
      y: base.y,
      rotationDeg: base.rotationDeg,
      scaleX: base.scaleX,
      scaleY: base.scaleY,
      opacity: base.opacity,
      easing: EasingType.easeInOut,
    );
  }

  Future<void> save() async {
    await ProjectStorage.saveProject(project);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
