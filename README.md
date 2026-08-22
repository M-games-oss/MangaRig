# Manga Rigger (MVP)

A beginner-friendly Flutter app for posing and animating cut-up manga
parts: drop in limb/part images, pin down pivot points, pose them with
drag/pinch gestures, keyframe them on a timeline, pick easing presets from
a tiny visual "graph," and use a one-tap Blink Helper for eyes.

Everything is stored locally on-device (Documents/projects/...) — nothing
is uploaded anywhere.

## What's included (MVP feature set)

- **Projects**: create/open/delete named animation projects.
- **Parts (layers)**: import images from your photo library as parts; each
  becomes a draggable, rotatable, scalable layer.
- **Pivot points**: tap "Pivot" on a selected part to drag its joint point
  directly on the image (e.g. the shoulder of an arm).
- **Rigging / posing**: one-finger drag to move a part, two-finger
  pinch+twist to scale and rotate it around its pivot — this is the same
  gesture language as most drawing/design apps, so it should feel familiar.
- **Timeline & keyframes**: a compact per-layer timeline strip. Tap the "+
  Keyframe" button (or just pose the part) to record a pose at the current
  time. Drag diamonds to retime them, tap to select/jump, long-press to
  delete. Layers can be reordered (drag the handle) which also changes
  front/back stacking order.
- **Easing "graph" presets**: Linear, Ease In, Ease Out, Ease In-Out,
  Bounce, Elastic — shown as small live curve previews you tap, no manual
  bezier fiddling required.
- **Blink Helper**: select an eye part, tap "Blink," pick a speed, and it
  auto-inserts a close/open keyframe sequence with easing tuned to look
  like a natural blink. (A full mesh/liquify deformer was out of scope for
  an MVP — this squash-based approach covers blinking with a fraction of
  the complexity.)
- **Onion skinning**: toggle a faint ghost of a nearby frame to help time
  motion.
- **Play/pause/loop preview** with a scrubbable timeline.
- **Export PNG frame sequence**: renders every frame at the project's fps
  to disk as PNGs (Documents/projects/<id>/export/), which you can drop
  into any GIF/video assembler.

## Requirements to build & sideload

You'll need a Mac with:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
  (stable channel).
- Xcode (from the Mac App Store) with command line tools.
- An Apple ID (a free one works for local sideloading; it just limits app
  lifetime to 7 days before you need to reinstall from Xcode. A paid Apple
  Developer account removes that limit).
- Your iPhone/iPad connected via cable (or on the same network for
  wireless debugging), with Developer Mode enabled on the device
  (Settings > Privacy & Security > Developer Mode).

## First-time setup

The files here are the app's Dart source only. Flutter's `ios/` and
`android/` platform folders are generated locally (they're large and
machine-specific, so they aren't included):

```bash
cd manga_rigger

# 1. Scaffold the missing platform folders into this same directory
flutter create . --platforms=ios

# 2. Fetch dependencies
flutter pub get

# 3. Add photo library permission (required to import images)
```

Open `ios/Runner/Info.plist` and add this entry (inside the outer `<dict>`):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Manga Rigger needs access to your photos to import cut-up part images.</string>
```

## Running / sideloading to your device

```bash
# List connected devices
flutter devices

# Run directly on your plugged-in iPhone (installs + launches it)
flutter run -d <your-device-id>
```

The first run will open Xcode's signing prompts if needed — in
`ios/Runner.xcworkspace` (open with Xcode), go to the **Runner** target >
**Signing & Capabilities**, choose your Apple ID under **Team**, and let
Xcode auto-manage the signing certificate. After that, `flutter run` (or
Xcode's Run button) will install straight onto your device.

Alternatively, once you have a signed `.ipa`, tools like **Sideloadly** or
**AltStore** can install it without Xcode each time — but for day-to-day
iteration `flutter run` is much faster since it supports hot reload.

## How to use it

1. Tap **+** on the home screen, name your project.
2. Tap the photo icon in the top bar to import a cut-up part (head, arm,
   eye, etc). It appears centered on the canvas as a new timeline row.
3. Tap a part to select it. Drag to move it; pinch with two fingers to
   rotate/scale it around its pivot.
4. Tap **Pivot** to drag its joint point onto the right spot (e.g. a
   shoulder or elbow) before you start rigging poses.
5. Move the playhead (drag on the ruler, or press play), pose the part
   again — this automatically records a new keyframe. Use the inspector's
   easing picker to change how the motion blends into the next pose.
6. For an eye part, tap **Blink** to auto-generate a blink.
7. Press play to preview the loop. Use **Export** to save a PNG sequence
   when you're ready to assemble it elsewhere.

## Notes on scope

This is intentionally an MVP: single uniform scale (no independent
X/Y stretch via gesture, though the data model supports it), no
undo/redo, no multi-select, and no true mesh warp/liquify tool. These are
reasonable next additions once the core rigging/timeline workflow above
feels good to use.
