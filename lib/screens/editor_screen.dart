import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../editor_controller.dart';
import '../interpolation.dart';
import '../storage.dart';
import '../widgets/canvas_stage.dart';
import '../widgets/timeline_panel.dart';
import '../widgets/easing_curve_picker.dart';
import '../widgets/pivot_point_dialog.dart';
import '../widgets/blink_helper_dialog.dart';

class EditorScreen extends StatefulWidget {
  final Project project;
  const EditorScreen({super.key, required this.project});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late EditorController controller;
  final GlobalKey _repaintKey = GlobalKey();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    controller = EditorController(widget.project);
    controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _addLayer() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    double w = frame.image.width.toDouble();
    double h = frame.image.height.toDouble();

    // Scale down large imports so they fit comfortably on the canvas.
    const maxDim = 420.0;
    if (w > maxDim || h > maxDim) {
      final scale = maxDim / (w > h ? w : h);
      w *= scale;
      h *= scale;
    }

    final savedPath = await controller.importImage(file);
    final project = controller.project;
    final maxZ = project.layers.isEmpty
        ? 0
        : project.layers.map((l) => l.zIndex).reduce((a, b) => a > b ? a : b) + 1;

    final layer = LayerItem(
      name: 'Part ${project.layers.length + 1}',
      imagePath: savedPath,
      width: w,
      height: h,
      zIndex: maxZ,
    );
    layer.keyframes.add(Keyframe(
      timeMs: 0,
      x: project.canvasWidth / 2,
      y: project.canvasHeight / 2,
    ));
    controller.addLayer(layer);
  }

  Future<void> _exportFrames() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final project = controller.project;
    final frameGapMs = (1000 / project.fps).round().clamp(16, 1000);
    final wasPlaying = controller.isPlaying;
    controller.stopPlayback();
    final exportDir = await ProjectStorage.exportDir(project.id);
    int frameIndex = 0;

    try {
      for (int t = 0; t <= project.durationMs; t += frameGapMs) {
        controller.setPlayhead(t);
        // Let the frame actually paint before we capture it.
        await Future.delayed(const Duration(milliseconds: 40));
        final boundary =
            _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) break;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();
          final file = File(
              '${exportDir.path}/frame_${frameIndex.toString().padLeft(4, '0')}.png');
          await file.writeAsBytes(pngBytes);
        }
        frameIndex++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported $frameIndex PNG frames to ${exportDir.path}')),
        );
      }
    } finally {
      setState(() => _exporting = false);
      if (wasPlaying) controller.togglePlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final layer = controller.selectedLayer;
    return Scaffold(
      backgroundColor: const Color(0xFF101013),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B20),
        title: Text(controller.project.name),
        actions: [
          IconButton(
            tooltip: 'Onion skin',
            icon: Icon(Icons.layers,
                color: controller.onionSkin ? Colors.deepPurpleAccent : Colors.white54),
            onPressed: () => setState(() => controller.onionSkin = !controller.onionSkin),
          ),
          IconButton(
            tooltip: 'Export PNG frames',
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            onPressed: _exporting ? null : _exportFrames,
          ),
          IconButton(
            tooltip: 'Add part (image)',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _addLayer,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: CanvasStage(controller: controller, repaintKey: _repaintKey),
          ),
          _buildTransportBar(),
          if (layer != null) _buildInspector(layer),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                TimelinePanel(controller: controller),
                PlayheadOverlay(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportBar() {
    final ms = controller.playheadMs;
    return Container(
      color: const Color(0xFF17171C),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow),
            color: Colors.white,
            onPressed: controller.togglePlay,
          ),
          IconButton(
            icon: const Icon(Icons.replay, size: 18),
            color: Colors.white54,
            onPressed: () => controller.setPlayhead(0),
          ),
          IconButton(
            tooltip: 'Loop',
            icon: Icon(Icons.loop,
                size: 18, color: controller.loop ? Colors.deepPurpleAccent : Colors.white38),
            onPressed: () => setState(() => controller.loop = !controller.loop),
          ),
          Text('${(ms / 1000).toStringAsFixed(2)}s / ${(controller.project.durationMs / 1000).toStringAsFixed(1)}s',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const Spacer(),
          if (controller.selectedLayer != null)
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Keyframe'),
              onPressed: () => controller.addKeyframeAtPlayhead(controller.selectedLayer!),
            ),
        ],
      ),
    );
  }

  Widget _buildInspector(LayerItem layer) {
    final exactKeyframe = keyframeAtExactTime(layer, controller.playheadMs);
    return Container(
      color: const Color(0xFF1B1B20),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  layer.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Eye layer marker',
                icon: Icon(Icons.remove_red_eye,
                    size: 18, color: layer.isEyeLayer ? Colors.tealAccent : Colors.white30),
                onPressed: () => controller.toggleEyeLayer(layer),
              ),
              TextButton.icon(
                icon: const Icon(Icons.control_camera, size: 16),
                label: const Text('Pivot'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => PivotPointDialog(layer: layer, controller: controller),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Blink'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => BlinkHelperDialog(layer: layer, controller: controller),
                ),
              ),
              IconButton(
                tooltip: 'Delete layer',
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                onPressed: () => controller.removeLayer(layer.id),
              ),
            ],
          ),
          if (exactKeyframe == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Drag or pinch the part on the canvas to pose it, or add a '
                'keyframe here to edit precisely.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            )
          else
            EasingCurvePicker(
              selected: exactKeyframe.easingOut,
              onSelected: (e) => controller.setKeyframeEasing(layer, exactKeyframe.id, e),
            ),
        ],
      ),
    );
  }
}
