import 'dart:io';
import 'package:flutter/material.dart';
import '../models.dart';
import '../editor_controller.dart';

/// Lets the user drag a crosshair over the part's image to place its pivot
/// (joint) point -- e.g. the shoulder of an arm, or the hinge of a jaw.
/// For bone-attached parts, this pivot is where the part rotates around
/// relative to the bone's own transform.
class PivotPointDialog extends StatefulWidget {
  final LayerItem layer;
  final EditorController controller;
  const PivotPointDialog({super.key, required this.layer, required this.controller});

  @override
  State<PivotPointDialog> createState() => _PivotPointDialogState();
}

class _PivotPointDialogState extends State<PivotPointDialog> {
  late double px;
  late double py;

  @override
  void initState() {
    super.initState();
    px = widget.layer.pivotX;
    py = widget.layer.pivotY;
  }

  @override
  Widget build(BuildContext context) {
    const boxSize = 300.0;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text('Set Pivot Point', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: boxSize,
        height: boxSize + 50,
        child: Column(
          children: [
            const Text(
              'Drag the dot to the joint this part should rotate around.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  px = (px + details.delta.dx / boxSize).clamp(0.0, 1.0);
                  py = (py + details.delta.dy / boxSize).clamp(0.0, 1.0);
                });
              },
              onTapDown: (details) {
                setState(() {
                  px = (details.localPosition.dx / boxSize).clamp(0.0, 1.0);
                  py = (details.localPosition.dy / boxSize).clamp(0.0, 1.0);
                });
              },
              child: Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  border: Border.all(color: Colors.white24),
                ),
                child: Stack(
                  children: [
                    if (widget.layer.imagePath != null)
                      Positioned.fill(
                        child: Image.file(File(widget.layer.imagePath!), fit: BoxFit.contain),
                      ),
                    Positioned(
                      left: px * boxSize - 10,
                      top: py * boxSize - 10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orangeAccent.withOpacity(0.9),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              px = 0.5;
              py = 0.5;
            });
          },
          child: const Text('Center'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.controller.setPivot(widget.layer, px, py);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
