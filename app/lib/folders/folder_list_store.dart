import 'dart:io';
import 'dart:ui' show Color;

import 'package:truce_core/truce_core.dart';

import '../storage/json_file.dart';
import 'base_folder.dart';
import 'document_folder.dart';

/// Keeps the folder list in a JSON file in app storage: each base folder
/// once, and the folders that show parts of them.
///
/// ```json
/// {"baseFolders": [{"id": "b1", "address": "file:///home/me/Sync",
///                   "tool": "syncthing"}],
///  "folders": [{"id": "f1", "base": "b1", "name": "Work", "color": 4278228616,
///               "subfolders": ["work"]}]}
/// ```
///
/// A folder without `subfolders` shows its whole base folder.
final class FolderListStore {
  /// [_toolIds] are the ids of the sync tools the app works with: a list
  /// naming another one (e.g. written by a later version) is corrupt.
  FolderListStore(File file, {required this._toolIds}) : _file = JsonFile(file);

  final JsonFile _file;
  final Set<String> _toolIds;

  /// The saved folders; empty before the first [save].
  Future<Result<List<DocumentFolder>, SettingsError>> load() async =>
      switch (await _file.read()) {
        Ok(:final value) => switch (_decode(value)) {
          final folders? => Ok(folders),
          null => const Err(SettingsError.corrupt),
        },
        Err(error: JsonFileError.missing) => const Ok([]),
        Err(error: JsonFileError.corrupt) => const Err(SettingsError.corrupt),
        Err() => const Err(SettingsError.unreadable),
      };

  /// Replaces the saved list atomically.
  Future<Result<void, SettingsError>> save(
    List<DocumentFolder> folders,
  ) async => switch (await _file.write(_encode(folders))) {
    Ok() => const Ok(null),
    Err() => const Err(SettingsError.unwritable),
  };

  static Object _encode(List<DocumentFolder> folders) => {
    'baseFolders': [
      for (final base in {for (final folder in folders) folder.base})
        base.toJson(),
    ],
    'folders': [
      for (final folder in folders)
        {
          'id': folder.id,
          'base': folder.base.id,
          'name': folder.name,
          'color': folder.color.toARGB32(),
          if (folder.selection case Subfolders(:final roots))
            'subfolders': [for (final root in roots) root.value]..sort(),
        },
    ],
  };

  /// `null` if [json] is not a list written by [_encode] for the app's
  /// sync tools.
  List<DocumentFolder>? _decode(Object? json) {
    if (json case {
      'baseFolders': final List<Object?> baseList,
      'folders': final List<Object?> folderList,
    }) {
      final bases = baseList.map(BaseFolder.fromJson).toList();
      if (bases.any(
        (base) => base == null || !_toolIds.contains(base.toolId),
      )) {
        return null;
      }
      final byId = {for (final base in bases.nonNulls) base.id: base};
      final folders = [
        for (final folder in folderList) _decodeFolder(folder, byId),
      ];
      return folders.contains(null) ? null : folders.nonNulls.toList();
    }
    return null;
  }

  static DocumentFolder? _decodeFolder(
    Object? json,
    Map<String, BaseFolder> bases,
  ) => switch (json) {
    {
      'id': final String id,
      'base': final String baseId,
      'name': final String name,
      'color': final int color,
    } =>
      switch ((bases[baseId], _selection(json))) {
        (final base?, final selection?) => DocumentFolder(
          id: id,
          base: base,
          selection: selection,
          name: name,
          color: Color(color),
        ),
        _ => null,
      },
    _ => null,
  };

  /// The whole base folder without `subfolders`; `null` for subfolders
  /// that don't parse, or none.
  static Selection? _selection(Map<Object?, Object?> json) =>
      switch (json['subfolders']) {
        null => const WholeFolder(),
        final List<Object?> raw when raw.isNotEmpty => _subfolders(raw),
        _ => null,
      };

  static Selection? _subfolders(List<Object?> raw) {
    final paths = [
      for (final value in raw) value is String ? RelPath.parse(value) : null,
    ];
    return paths.contains(null)
        ? null
        : Selection.of([for (final path in paths) ?path]);
  }
}

enum SettingsError { unreadable, corrupt, unwritable }
