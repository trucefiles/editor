import 'dart:convert';
import 'dart:io';

import 'package:truce_core/truce_core.dart';

import 'note_folder.dart';

/// Keeps the folder list in a JSON file in app storage.
final class FolderSettingsStore {
  const FolderSettingsStore(this._file);

  final File _file;

  /// The saved folders; empty before the first [save].
  Future<Result<List<NoteFolder>, SettingsError>> load() async {
    final String raw;
    try {
      if (!await _file.exists()) return const Ok([]);
      raw = await _file.readAsString();
    } on FileSystemException {
      return const Err(SettingsError.unreadable);
    }
    final folders = switch (_tryDecode(raw)) {
      final List<Object?> list => list.map(NoteFolder.fromJson).toList(),
      _ => null,
    };
    if (folders == null || folders.contains(null)) {
      return const Err(SettingsError.corrupt);
    }
    return Ok(folders.cast<NoteFolder>());
  }

  /// Replaces the saved list atomically, via a temp file.
  Future<Result<void, SettingsError>> save(List<NoteFolder> folders) async {
    final temp = File('${_file.path}.tmp');
    try {
      await _file.parent.create(recursive: true);
      await temp.writeAsString(
        jsonEncode([for (final folder in folders) folder.toJson()]),
        flush: true,
      );
      await temp.rename(_file.path);
      return const Ok(null);
    } on FileSystemException {
      return const Err(SettingsError.unwritable);
    }
  }

  static Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

enum SettingsError { unreadable, corrupt, unwritable }
