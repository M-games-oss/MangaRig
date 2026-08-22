import 'package:flutter/material.dart';
import '../models.dart';
import '../storage.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Project>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _projectsFuture = ProjectStorage.listProjects();
  }

  Future<void> _createProject() async {
    final controller = TextEditingController(text: 'New Animation');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('New Project', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Project name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final project = Project(name: name);
    await ProjectStorage.saveProject(project);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(project: project)),
    );
    setState(_refresh);
  }

  Future<void> _openProject(Project p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(project: p)),
    );
    setState(_refresh);
  }

  Future<void> _deleteProject(Project p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text('Delete project?', style: TextStyle(color: Colors.white)),
        content: Text('"${p.name}" and all its parts will be permanently deleted.',
            style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ProjectStorage.deleteProject(p.id);
      setState(_refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101013),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B20),
        title: const Text('Manga Rigger'),
      ),
      body: FutureBuilder<List<Project>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snapshot.data!;
          if (projects.isEmpty) {
            return const Center(
              child: Text(
                'No projects yet.\nTap + to start rigging your first cut-up.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38),
              ),
            );
          }
          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final p = projects[i];
              return ListTile(
                leading: const Icon(Icons.movie_creation_outlined, color: Colors.deepPurpleAccent),
                title: Text(p.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${p.layers.length} parts · ${(p.durationMs / 1000).toStringAsFixed(1)}s · ${p.fps}fps',
                  style: const TextStyle(color: Colors.white38),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white38),
                  onPressed: () => _deleteProject(p),
                ),
                onTap: () => _openProject(p),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
    );
  }
}
