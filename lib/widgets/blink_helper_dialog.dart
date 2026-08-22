import 'package:flutter/material.dart';
import '../models.dart';
import '../editor_controller.dart';

/// One-tap blink generator: squashes the selected layer vertically and back
/// around the current playhead time, using easing presets tuned to look
/// like a natural blink (fast close, slightly slower open).
class BlinkHelperDialog extends StatefulWidget {
  final LayerItem layer;
  final EditorController controller;
  const BlinkHelperDialog({super.key, required this.layer, required this.controller});

  @override
  State<BlinkHelperDialog> createState() => _BlinkHelperDialogState();
}

class _BlinkHelperDialogState extends State<BlinkHelperDialog> {
  double halfDuration = 90;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Blink Helper', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Squashes this layer (e.g. an eye) shut and back open, '
              'centered on the current playhead.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text('Blink speed: ${halfDuration.round() * 2} ms',
                style: const TextStyle(color: Colors.white)),
            Slider(
              value: halfDuration,
              min: 30,
              max: 220,
              onChanged: (v) => setState(() => halfDuration = v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: mark this layer as an "eye layer" from the layer list so '
              'you can find it quickly later.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
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
          onPressed: () {
            widget.controller.addBlink(widget.layer, halfDurationMs: halfDuration.round());
            Navigator.of(context).pop();
          },
          child: const Text('Insert Blink'),
        ),
      ],
    );
  }
}
