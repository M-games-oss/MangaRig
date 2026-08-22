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
  bool showSkeleton = true;
  Timer? _ticker;

  EditorController(this.project);

  LayerItem? get selectedLayer => project.byId(selectedLayerId);

  /// Render/interaction order: parents-before-children so a group/bone's
  /// world matrix is always available before its children need it, and
  /// within that, back-to-front by zIndex.
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

  /// Removes a layer AND everything parented under it (its group/bone
  /// children), so deleting a bone doesn't leave orphaned art floating
  /// with a dangling parentId.
  void removeLayer(String id) {
    final toRemove = {id, ...project.descendantsOf(id).map((l) => l.id)};
    project.layers.removeWhere((l) => toRemove.contains(l.id));
    if (toRemove.contains(selectedLayerId)) {
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

  // ---------------------------------------------------------------------
  // Grouping
  // ---------------------------------------------------------------------

  /// Wraps the given layers under a new invisible group node positioned at
  /// their combined center, so moving/rotating/scaling the group carries
  /// all of them together. Returns the new group.
  LayerItem groupLayers(List<LayerItem> members) {
    if (members.isEmpty) {
      throw ArgumentError('groupLayers needs at least one layer');
    }
    double cx = 0, cy = 0;
    for (final m in members) {
      final p = poseAt(m, playheadMs);
      cx += p.x;
      cy += p.y;
    }
    cx /= members.length;
    cy /= members.length;

    final maxZ = project.layers.isEmpty
        ? 0
        : project.layers.map((l) => l.zIndex).reduce((a, b) => a > b ? a : b) + 1;

    final group = LayerItem(
      name: 'Group ${project.layers.where((l) => l.isGroup).length + 1}',
      isGroup: true,
      width: 0,
      height: 0,
      zIndex: maxZ,
      keyframes: [Keyframe(timeMs: 0, x: cx, y: cy)],
    );
    project.layers.add(group);
    for (final m in members) {
      m.parentId = group.id;
    }
    selectedLayerId = group.id;
    save();
    notifyListeners();
    return group;
  }

  /// Reparents a group's children up to the group's own parent (or to the
  /// root if none), then deletes the now-empty group.
  void ungroup(LayerItem group) {
    if (!group.isGroup) return;
    for (final child in project.layers.where((l) => l.parentId == group.id)) {
      child.parentId = group.parentId;
    }
    project.layers.removeWhere((l) => l.id == group.id);
    if (selectedLayerId == group.id) selectedLayerId = null;
    save();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Skeleton / bones
  // ---------------------------------------------------------------------

  /// Adds a new bone. If [parentBoneId] is given, the new bone is attached
  /// at the tip of that bone (so chaining "Add Bone" calls builds a limb
  /// automatically) -- otherwise it's a new root bone at the canvas center.
  LayerItem addBone({String? parentBoneId, String? name}) {
    final parent = project.byId(parentBoneId);
    double x = project.canvasWidth / 2;
    double y = project.canvasHeight / 2;
    if (parent != null && parent.isBone) {
      // Place the new bone's root at the parent bone's tip.
      x = parent.boneLength;
      y = 0;
    }
    final maxZ = project.layers.isEmpty
        ? 0
        : project.layers.map((l) => l.zIndex).reduce((a, b) => a > b ? a : b) + 1;
    final bone = LayerItem(
      name: name ?? 'Bone ${project.layers.where((l) => l.isBone).length + 1}',
      isBone: true,
      parentId: parent?.id,
      boneLength: 120,
      zIndex: maxZ,
      keyframes: [Keyframe(timeMs: 0, x: x, y: y)],
    );
    project.layers.add(bone);
    selectedLayerId = bone.id;
    save();
    notifyListeners();
    return bone;
  }

  /// Parents [layer] to [bone] so it inherits the bone's rotation/position
  /// (forward kinematics) -- e.g. attach a "forearm" art part to a forearm
  /// bone so rotating the bone poses the art.
  void attachToBone(LayerItem layer, LayerItem bone) {
    if (!bone.isBone) return;
    layer.parentId = bone.id;
    save();
    notifyListeners();
  }

  void detachFromParent(LayerItem layer) {
    layer.parentId = null;
    save();
    notifyListeners();
  }

  void setBoneLength(LayerItem bone, double length) {
    if (!bone.isBone) return;
    bone.boneLength = length.clamp(20, 2000);
    save();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Keyframes / posing
  // ---------------------------------------------------------------------

  /// Adds a new keyframe at [timeMs], or updates one that's already there.
  Keyframe upsertKeyframe(
    LayerItem layer,
    int timeMs, {
    required double x,
    required double y,
    double rotationDeg = 0,
    double rotationX = 0,
    double rotationY = 0,
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
      existing.rotationX = rotationX;
      existing.rotationY = rotationY;
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
        rotationX: rotationX,
        rotationY: rotationY,
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
  /// [dx]/[dy] are already in the LAYER'S PARENT-LOCAL space (the canvas
  /// widget is responsible for converting raw screen deltas through the
  /// parent's inverse world matrix before calling this).
  void applyLiveTransform(
    LayerItem layer, {
    required double x,
    required double y,
    double? rotationDeg,
    double? scaleX,
    double? scaleY,
  }) {
    final pose = poseAt(layer, playheadMs);
    upsertKeyframe(
      layer,
      playheadMs,
      x: x,
      y: y,
      rotationDeg: rotationDeg ?? pose.rotationDeg,
      rotationX: pose.rotationX,
      rotationY: pose.rotationY,
      scaleX: scaleX ?? pose.scaleX,
      scaleY: scaleY ?? pose.scaleY,
      opacity: pose.opacity,
    );
  }

  /// Sets the 3D tilt sliders in the inspector -- kept separate from the
  /// canvas gesture handler since a touchscreen drag can't unambiguously
  /// mean "tilt in 3D" vs "rotate on the plane" vs "scale" at once.
  void set3DTilt(LayerItem layer, {required double rotationX, required double rotationY}) {
    final pose = poseAt(layer, playheadMs);
    upsertKeyframe(
      layer,
      playheadMs,
      x: pose.x,
      y: pose.y,
      rotationDeg: pose.rotationDeg,
      rotationX: rotationX,
      rotationY: rotationY,
      scaleX: pose.scaleX,
      scaleY: pose.scaleY,
      opacity: pose.opacity,
    );
  }

  /// Freezes the layer's current interpolated pose into a real keyframe at
  /// the playhead -- the "+ Keyframe" button beginners use most.
  void addKeyframeAtPlayhead(LayerItem layer) {
    final pose = poseAt(layer, playheadMs);
    upsertKeyframe(
      layer,
      playheadMs,
      x: pose.x,
      y: pose.y,
      rotationDeg: pose.rotationDeg,
      rotationX: pose.rotationX,
      rotationY: pose.rotationY,
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

  // ---------------------------------------------------------------------
  // Realistic blink: coordinates THREE separate layers (upper lid, lower
  // lid, eyeball) instead of squashing a single eye image.
  // ---------------------------------------------------------------------

  /// Stores which layers make up an eye rig on [host] (usually a group
  /// wrapping the three parts, but any layer works as the storage spot),
  /// so future "Blink" taps on this layer don't need to re-ask.
  void setEyeRig(
    LayerItem host, {
    required String upperLidId,
    required String lowerLidId,
    required String eyeballId,
  }) {
    host.upperLidId = upperLidId;
    host.lowerLidId = lowerLidId;
    host.eyeballId = eyeballId;
    save();
    notifyListeners();
  }

  /// Inserts a close/open sequence across the three eye-rig layers,
  /// centered on the current playhead:
  ///  - Upper lid slides down and covers the eyeball at the midpoint.
  ///  - Lower lid rises slightly to meet it (most human blinks are lid
  ///    dominant, but a small lower-lid lift reads as far more natural
  ///    than the upper lid doing 100% of the work).
  ///  - Eyeball scales down vertically under the closing lids, so nothing
  ///    peeks out from behind them at the midpoint.
  /// All three snap back to their resting pose by [endT].
  void addBlink(LayerItem host, {int halfDurationMs = 90}) {
    final upper = project.byId(host.upperLidId);
    final lower = project.byId(host.lowerLidId);
    final eyeball = project.byId(host.eyeballId);
    if (upper == null || lower == null || eyeball == null) {
      throw StateError(
          'This layer has no eye rig set yet -- open Blink Helper and pick the upper lid, lower lid, and eyeball first.');
    }

    final center = playheadMs;
    final startT = (center - halfDurationMs).clamp(0, project.durationMs);
    final endT = (center + halfDurationMs).clamp(0, project.durationMs);

    final upperRest = poseAt(upper, center);
    final lowerRest = poseAt(lower, center);
    final eyeRest = poseAt(eyeball, center);

    // How far the upper lid needs to travel to fully cover the eyeball,
    // and how far the lower lid rises to meet it -- expressed as a
    // fraction of the eyeball's own height so it scales with art size.
    final coverDistance = eyeball.height * 0.85;
    final lowerLift = eyeball.height * 0.18;

    void restKeyframes(LayerItem layer, Pose rest, int t, EasingType easing) {
      upsertKeyframe(
        layer,
        t,
        x: rest.x,
        y: rest.y,
        rotationDeg: rest.rotationDeg,
        rotationX: rest.rotationX,
        rotationY: rest.rotationY,
        scaleX: rest.scaleX,
        scaleY: rest.scaleY,
        opacity: rest.opacity,
        easing: easing,
      );
    }

    // --- Rest pose bookending both ends of the blink ---
    restKeyframes(upper, upperRest, startT, EasingType.blinkClose);
    restKeyframes(lower, lowerRest, startT, EasingType.blinkClose);
    restKeyframes(eyeball, eyeRest, startT, EasingType.blinkClose);

    // --- Fully-closed midpoint ---
    upsertKeyframe(
      upper,
      center,
      x: upperRest.x,
      y: upperRest.y + coverDistance,
      rotationDeg: upperRest.rotationDeg,
      rotationX: upperRest.rotationX,
      rotationY: upperRest.rotationY,
      scaleX: upperRest.scaleX,
      scaleY: upperRest.scaleY,
      opacity: upperRest.opacity,
      easing: EasingType.blinkOpen,
    );
    upsertKeyframe(
      lower,
      center,
      x: lowerRest.x,
      y: lowerRest.y - lowerLift,
      rotationDeg: lowerRest.rotationDeg,
      rotationX: lowerRest.rotationX,
      rotationY: lowerRest.rotationY,
      scaleX: lowerRest.scaleX,
      scaleY: lowerRest.scaleY,
      opacity: lowerRest.opacity,
      easing: EasingType.blinkOpen,
    );
    upsertKeyframe(
      eyeball,
      center,
      x: eyeRest.x,
      y: eyeRest.y,
      rotationDeg: eyeRest.rotationDeg,
      rotationX: eyeRest.rotationX,
      rotationY: eyeRest.rotationY,
      scaleX: eyeRest.scaleX,
      scaleY: 0.05,
      opacity: eyeRest.opacity,
      easing: EasingType.blinkOpen,
    );

    // --- Back to rest ---
    restKeyframes(upper, upperRest, endT, EasingType.easeInOut);
    restKeyframes(lower, lowerRest, endT, EasingType.easeInOut);
    restKeyframes(eyeball, eyeRest, endT, EasingType.easeInOut);
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
