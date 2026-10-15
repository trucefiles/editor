import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../storage/json_file.dart';
import 'note_folder.dart';

/// Keeps the folder list in a JSON file in app storage.
final class FolderSettingsStore {
  FolderSettingsStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved folders; empty before the first [save].
  Future<Result<List<NoteFolder>, SettingsError>> load() async {
    final Object? json;
    switch (await _file.read()) {
      case Ok(:final value):
        json = value;
      case Err(error: JsonFileError.missing):
        return const Ok([]);
      case Err(error: JsonFileError.corrupt):
        return const Err(SettingsError.corrupt);
      case Err():
        return const Err(SettingsError.unreadable);
    }
    final folders = switch (json) {
      final List<Object?> list => list.map(NoteFolder.fromJson).toList(),
      _ => null,
    };
    if (folders == null || folders.contains(null)) {
      return const Err(SettingsError.corrupt);
    }
    return Ok(folders.cast<NoteFolder>());
  }

  /// Replaces the saved list atomically.
  Future<Result<void, SettingsError>> save(List<NoteFolder> folders) async =>
      switch (await _file.write([
        for (final folder in folders) folder.toJson(),
      ])) {
        Ok() => const Ok(null),
        Err() => const Err(SettingsError.unwritable),
      };
}

enum SettingsError { unreadable, corrupt, unwritable }
