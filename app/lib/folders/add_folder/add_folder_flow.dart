import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../base_folder.dart';
import '../document_folder.dart';
import '../folder_colors.dart';
import '../folder_error.dart';
import '../subfolders/subfolder_choice.dart';

/// The steps of adding a folder, in order.
enum AddFolderStep {
  /// Pick a base folder, or one already added.
  base,

  /// Say which sync tool syncs it, if the app can't tell.
  tool,

  /// Choose the whole base folder or some subfolders.
  parts,

  /// Name and color.
  name,
}

/// What [AddFolderFlow] needs from the app, wired.
final class AddFolderWork {
  const AddFolderWork({
    required this.tools,
    required this.markersOf,
    required this.namesOf,
    required this.isToolFolder,
    required this.add,
  });

  /// The sync tools the app works with, in the order offered.
  final List<SyncTool> tools;

  /// A look at the base folder at a path, for the tools to recognize it.
  final FolderMarkers Function(String basePath) markersOf;

  /// The folder names of the base folder at a path.
  final SubfolderNames Function(String basePath) namesOf;

  final bool Function(List<String> segments) isToolFolder;

  /// Adds the folder; see `FoldersController.add`.
  final Future<Result<DocumentFolder, FolderError>> Function({
    required String basePath,
    required String toolId,
    required Selection selection,
    required String name,
    required Color color,
  })
  add;
}

/// The user's way through adding a folder (see [AddFolderStep]); the
/// screen shows it and forwards the user's choices.
final class AddFolderFlow extends ChangeNotifier {
  /// [folders] are the folders added before.
  AddFolderFlow(this._work, this._folders);

  final AddFolderWork _work;
  final List<DocumentFolder> _folders;

  AddFolderStep _step = AddFolderStep.base;
  String? _basePath;
  SyncTool? _tool;
  SubfolderChoice? _parts;
  String _name = '';
  Color _color = folderColors.first;

  AddFolderStep get step => _step;

  /// The base folders added before, to add another part of one.
  List<BaseFolder> get bases => [
    ...{for (final folder in _folders) folder.base},
  ];

  /// The tools to pick from at [AddFolderStep.tool].
  List<SyncTool> get tools => _work.tools;

  /// The chosen base folder's path; from [AddFolderStep.tool] on.
  String get basePath => _basePath!;

  /// The sync tool for the base folder; from [AddFolderStep.parts] on.
  SyncTool get tool => _tool!;

  /// The part to show; from [AddFolderStep.parts] on.
  SubfolderChoice get parts => _parts!;

  String get name => _name;
  Color get color => _color;

  /// Uses the base folder at [path]: one added before keeps its tool;
  /// else the first tool that recognizes it, or the user says which.
  Future<void> pickBase(String path) async {
    _basePath = path;
    final added = bases.where((base) => base.path == path).firstOrNull;
    final tool = added != null
        ? _work.tools.firstWhere((tool) => tool.id == added.toolId)
        : await _recognized(path);
    if (tool == null) {
      _go(AddFolderStep.tool);
    } else {
      chooseTool(tool);
    }
  }

  void chooseTool(SyncTool tool) {
    _tool = tool;
    _parts?.dispose();
    _parts = SubfolderChoice(
      names: _work.namesOf(basePath),
      isToolFolder: _work.isToolFolder,
      taken: [
        for (final folder in _folders)
          if (folder.base.path == basePath) folder.selection,
      ],
    );
    _go(AddFolderStep.parts);
  }

  /// To name and color, with a name after what is shown and a color no
  /// folder has yet.
  void toName() {
    _name = switch (parts.selection) {
      Subfolders(:final roots) when roots.length == 1 => roots.single.name,
      _ => _lastSegment(basePath),
    };
    _color = nextFolderColor(_folders.map((folder) => folder.color));
    _go(AddFolderStep.name);
  }

  void rename(String name) => _name = name;

  void recolor(Color color) {
    _color = color;
    notifyListeners();
  }

  /// The step before; `false` at the first one.
  bool back() => switch (_step) {
    AddFolderStep.base => false,
    AddFolderStep.tool => _go(AddFolderStep.base),
    AddFolderStep.parts => _go(AddFolderStep.base),
    AddFolderStep.name => _go(AddFolderStep.parts),
  };

  /// Adds the folder as chosen.
  Future<Result<DocumentFolder, FolderError>> finish() => _work.add(
    basePath: basePath,
    toolId: tool.id,
    selection: parts.selection!,
    name: _name.trim(),
    color: _color,
  );

  Future<SyncTool?> _recognized(String path) async {
    final markers = _work.markersOf(path);
    for (final tool in _work.tools) {
      if (await tool.recognize(markers) == SyncStatus.synced) return tool;
    }
    return null;
  }

  bool _go(AddFolderStep step) {
    _step = step;
    notifyListeners();
    return true;
  }

  static String _lastSegment(String path) => path
      .split(Platform.pathSeparator)
      .lastWhere((segment) => segment.isNotEmpty, orElse: () => path);

  @override
  void dispose() {
    _parts?.dispose();
    super.dispose();
  }
}
