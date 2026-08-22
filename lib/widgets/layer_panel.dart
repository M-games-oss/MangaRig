import 'package:flutter/material.dart';
import '../models.dart';
import '../editor_controller.dart';

/// Hierarchy view of every node in the rig (parts, groups, bones), indented
/// to show parent/child relationships. Multi-select + "Group" wraps parts
/// together; "Add Bone" builds a skeleton; drag a part's "Attach" handle
/// onto a bone row to parent it (forward kinematics).
class LayerPanel extends StatefulWidget {
  final EditorController controller;
  const LayerPanel({super.key, required this.controller});

  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  final Set<String> _multiSelected = {};

  EditorController get controller => widget.controller;

  int _depthOf(LayerItem l) {
    int depth = 0;
    String? pid = l.parentId;
    final seen = <String>{};
    while (pid != null && !seen.contains(pid)) {
      seen.add(pid);
      final parent = controller.project.byId(pid);
      if (parent == null) break;
      depth++;
      pid = parent.parentId;
    }
    return depth;
  }

  @override
  Widget build(BuildContext context) {
    final layers = [...controller.project.layers]
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

    return Container(
      color: const Color(0xFF17171C),
      child: Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView.builder(
              itemCount: layers.length,
              itemBuilder: (context, i) => _buildRow(layers[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Wrap(
        spacing: 4,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.folder, size: 14),
            label: const Text('Group', style: TextStyle(fontSize: 11)),
            onPressed: _multiSelected.length < 2 ? null : _groupSelected,
          ),
          TextButton.icon(
            icon: const Icon(Icons.accessibility_new, size: 14),
            label: const Text('Add Bone', style: TextStyle(fontSize: 11)),
            onPressed: () {
              final sel = controller.selectedLayer;
              controller.addBone(parentBoneId: (sel != null && sel.isBone) ? sel.id : null);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.layers_clear, size: 14),
            label: Text(controller.showSkeleton ? 'Hide Rig' : 'Show Rig',
                style: const TextStyle(fontSize: 11)),
            onPressed: () => setState(() => controller.showSkeleton = !controller.showSkeleton),
          ),
        ],
      ),
    );
  }

  void _groupSelected() {
    final members = _multiSelected
        .map((id) => controller.project.byId(id))
        .whereType<LayerItem>()
        .toList();
    if (members.length < 2) return;
    controller.groupLayers(members);
    setState(() => _multiSelected.clear());
  }

  Widget _buildRow(LayerItem layer) {
    final depth = _depthOf(layer);
    final selected = controller.selectedLayerId == layer.id;
    final multiSelected = _multiSelected.contains(layer.id);

    IconData icon;
    if (layer.isGroup) {
      icon = Icons.folder_outlined;
    } else if (layer.isBone) {
      icon = Icons.accessibility_new;
    } else if (layer.isEyeLayer) {
      icon = Icons.remove_red_eye;
    } else {
      icon = Icons.image_outlined;
    }

    return Container(
      color: selected ? Colors.deepPurple.withOpacity(0.25) : Colors.transparent,
      padding: EdgeInsets.only(left: 8.0 + depth * 16, right: 4),
      child: Row(
        children: [
          Checkbox(
            visualDensity: VisualDensity.compact,
            value: multiSelected,
            onChanged: (v) => setState(() {
              if (v == true) {
                _multiSelected.add(layer.id);
              } else {
                _multiSelected.remove(layer.id);
              }
            }),
          ),
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => controller.selectLayer(layer.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  layer.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (layer.parentId != null)
            IconButton(
              tooltip: 'Detach from parent',
              icon: const Icon(Icons.link_off, size: 14, color: Colors.white38),
              onPressed: () => controller.detachFromParent(layer),
            ),
          if (!layer.isGroup && !layer.isBone)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: Colors.white38),
              color: const Color(0xFF2A2A32),
              onSelected: (boneId) {
                final bone = controller.project.byId(boneId);
                if (bone != null) controller.attachToBone(layer, bone);
              },
              itemBuilder: (context) => controller.project.layers
                  .where((l) => l.isBone)
                  .map((b) => PopupMenuItem(
                        value: b.id,
                        child: Text('Attach to ${b.name}',
                            style: const TextStyle(fontSize: 12)),
                      ))
                  .toList(),
            ),
          if (layer.isGroup)
            IconButton(
              tooltip: 'Ungroup',
              icon: const Icon(Icons.folder_off_outlined, size: 14, color: Colors.white38),
              onPressed: () => controller.ungroup(layer),
            ),
          IconButton(
            icon: Icon(layer.visible ? Icons.visibility : Icons.visibility_off,
                size: 14, color: Colors.white38),
            onPressed: () => controller.toggleVisible(layer),
          ),
        ],
      ),
    );
  }
}
