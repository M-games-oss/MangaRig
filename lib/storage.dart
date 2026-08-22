import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// Everything is stored on-device under the app's Documents directory:
///   Documents/projects/<projectId>/project.json
///   Documents/projects/<projectId>/assets/<image files>
///   Documents/projects/<projectId>/export/<exported frames>
/// Nothing leaves the device.
class ProjectStorage {
  static Future<Directory> _projectsRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/projects');
    if (!await root.exists()) await root.create(recursive: true);
    return root;
  }

  static Future<Directory> projectDir(String projectId) async {
    final root = await _projectsRoot();
    final dir = Directory('${root.path}/$projectId');
    if (!await dir.exists()) await dir.create(recursive: true);
    final assets = Directory('${dir.path}/assets');
    if (!await assets.exists()) await assets.create(recursive: true);
    return dir;
  }

  static Future<void> saveProject(Project project) async {
    final dir = await projectDir(project.id);
    final file = File('${dir.path}/project.json');
    await file.writeAsString(jsonEncode(project.toJson()));
  }

  static Future<Project?> loadProject(String projectId) async {
    final dir = await projectDir(projectId);
    final file = File('${dir.path}/project.json');
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString());
    return Project.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> deleteProject(String projectId) async {
    final dir = await projectDir(projectId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static Future<List<Project>> listProjects() async {
    final root = await _projectsRoot();
    final List<Project> projects = [];
    await for (final entity in root.list()) {
      if (entity is Directory) {
        final file = File('${entity.path}/project.json');
        if (await file.exists()) {
          try {
            final data = jsonDecode(await file.readAsString());
            projects.add(Project.fromJson(data as Map<String, dynamic>));
          } catch (_) {
            // Skip corrupted project folders instead of crashing the list.
          }
        }
      }
    }
    projects.sort((a, b) => a.name.compareTo(b.name));
    return projects;
  }

  /// Copies an image the user picked into the project's own assets folder
  /// so the project stays self-contained and portable.
  static Future<String> importImage(String projectId, File sourceFile) async {
    final dir = await projectDir(projectId);
    final assetsDir = Directory('${dir.path}/assets');
    final ext = sourceFile.path.contains('.') ? sourceFile.path.split('.').last : 'png';
    final newName = 'part_${DateTime.now().microsecondsSinceEpoch}.$ext';
    final newFile = await sourceFile.copy('${assetsDir.path}/$newName');
    return newFile.path;
  }

  static Future<Directory> exportDir(String projectId) async {
    final dir = await projectDir(projectId);
    final exp = Directory('${dir.path}/export');
    if (!await exp.exists()) await exp.create(recursive: true);
    return exp;
  }
}
