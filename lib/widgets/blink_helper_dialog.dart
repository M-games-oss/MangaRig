import 'package:flutter/material.dart';
import '../models.dart';
import '../editor_controller.dart';

/// Realistic blink generator. Unlike the old single-layer squash, this asks
/// you to point out the three parts that make up a working eye:
///   1. Upper eyelid  -- slides down to cover the eye.
///   2. Lower eyelid  -- lifts slightly to meet it.
///   3. Eyeball       -- shrinks vertically under the closing lids.
/// It then inserts coordinated keyframes on all three, centered on the
/// current playhead, so the blink reads as lids actually closing over an
/// eye rather than one flat image squishing.
class BlinkHelperDialog extends StatefulWidget {
  final LayerItem layer;
  final EditorController controller;
  const BlinkHelperDialog({super.key, required this.layer, required this.controller});

  @override
  State<BlinkHelperDialog> createState() => _BlinkHelperDialogState();
}

class _BlinkHelperDialogState extends State<BlinkHelperDialog> {
  double halfDuration = 90;
  String? upperLidId;
  String? lowerLidId;
  String? eyeballId;

  List<LayerItem> get _candidateLayers => widget.controller.project.layers
      .where((l) => !l.isGroup && !l.isBone && l.imagePath != null)
      .toList();

  @override
  void initState() {
    super.initState();
    // Reuse a previously-configured rig on this layer if there is one.
    upperLidId = widget.layer.upperLidId;
    lowerLidId = widget.layer.lowerLidId;
    eyeballId = widget.layer.eyeballId;
  }

  bool get _ready => upperLidId != null && lowerLidId != null && eyeballId != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Blink Helper', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pick the three parts that make up this eye. They can be any '
              'layers in the project -- they don\'t need to be grouped.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _layerPicker('Upper eyelid', upperLidId, (id) => setState(() => upperLidId = id)),
            const SizedBox(height: 8),
            _layerPicker('Lower eyelid', lowerLidId, (id) => setState(() => lowerLidId = id)),
            const SizedBox(height: 8),
            _layerPicker('Eyeball', eyeballId, (id) => setState(() => eyeballId = id)),
            const SizedBox(height: 16),
            Text('Blink speed: ${halfDuration.round() * 2} ms',
                style: const TextStyle(color: Colors.white)),
            Slider(
              value: halfDuration,
              min: 30,
              max: 220,
              onChanged: (v) => setState(() => halfDuration = v),
            ),
            if (!_ready)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Select all three parts to insert a blink.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !_ready
              ? null
              : () {
                  widget.controller.setEyeRig(
                    widget.layer,
                    upperLidId: upperLidId!,
                    lowerLidId: lowerLidId!,
                    eyeballId: eyeballId!,
                  );
                  try {
                    widget.controller.addBlink(widget.layer, halfDurationMs: halfDuration.round());
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
          child: const Text('Insert Blink'),
        ),
      ],
    );
  }

  Widget _layerPicker(String label, String? value, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            dropdownColor: const Color(0xFF2A2A32),
            value: value,
            hint: const Text('Choose a layer', style: TextStyle(color: Colors.white38, fontSize: 12)),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: _candidateLayers
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
