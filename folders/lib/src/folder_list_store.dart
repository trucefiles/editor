import 'dart:io';

import 'package:truce_core/truce_core.dart';

/// One folder as the app keeps it: its id, name and color.
typedef FolderEntry = ({FolderId id, String name, String color});

/// What the folder list file holds: the app's folders, and every plugin's
/// state as its blob, by plugin id.
typedef SavedFolders = ({
  List<FolderEntry> folders,
  Map<String, Object?> blobs,
});

/// Keeps the folder list in one JSON file in app storage, the app's
/// entries and every plugin's blob together, so one atomic write keeps
/// them in step:
///
/// ```json
/// {"folders": [{"plugin": "syncthing", "id": "f1", "name": "Work",
///               "color": "teal"}],
///  "plugins": {"syncthing": {"roots": [], "folders": []}}}
/// ```
interface class FolderListStore {
  FolderListStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved list; empty before the first [save].
  Future<Result<SavedFolders, SettingsError>> load() async =>
      switch (await _file.read()) {
        Ok(:final value) => switch (_decode(value)) {
          final saved? => Ok(saved),
          null => const Err(SettingsError.corrupt),
        },
        Err(error: JsonFileError.missing) => const Ok((folders: [], blobs: {})),
        Err(error: JsonFileError.corrupt) => const Err(SettingsError.corrupt),
        Err() => const Err(SettingsError.unreadable),
      };

  /// Replaces the saved list atomically.
  Future<Result<void, SettingsError>> save(SavedFolders saved) async =>
      switch (await _file.write(_encode(saved))) {
        Ok() => const Ok(null),
        Err() => const Err(SettingsError.unwritable),
      };

  static Object _encode(SavedFolders saved) => {
    'folders': [
      for (final folder in saved.folders)
        {
          'plugin': folder.id.plugin,
          'id': folder.id.folder,
          'name': folder.name,
          'color': folder.color,
        },
    ],
    'plugins': saved.blobs,
  };

  /// `null` if [json] is not a list written by [_encode].
  static SavedFolders? _decode(Object? json) {
    if (json case {
      'folders': final List<Object?> raw,
      'plugins': final Map<String, Object?> blobs,
    }) {
      final folders = raw.map(_decodeFolder).toList();
      return folders.contains(null)
          ? null
          : (folders: folders.nonNulls.toList(), blobs: blobs);
    }
    return null;
  }

  static FolderEntry? _decodeFolder(Object? json) => switch (json) {
    {
      'plugin': final String plugin,
      'id': final String id,
      'name': final String name,
      'color': final String color,
    } =>
      switch (FolderId.parse(plugin, id)) {
        final id? => (id: id, name: name, color: color),
        null => null,
      },
    _ => null,
  };
}

enum SettingsError { unreadable, corrupt, unwritable }
