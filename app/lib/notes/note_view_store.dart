import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../storage/json_file.dart';
import 'note.dart';
import 'note_view.dart';

/// Keeps the last view of each note in a JSON file in app storage. Per
/// device and never synced. A convenience: read and write failures are
/// ignored.
final class NoteViewStore {
  NoteViewStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved views by [storeKey]; empty if none or unreadable.
  Future<Map<String, NoteView>> load() async => switch (await _file.read()) {
    Ok(value: final Map<String, Object?> json) => {
      for (final MapEntry(:key, :value) in json.entries)
        key: ?NoteView.values.asNameMap()[value],
    },
    _ => const {},
  };

  /// Replaces the saved views; on failure the next save tries again.
  Future<void> save(Map<String, NoteView> views) => _file.write({
    for (final MapEntry(:key, :value) in views.entries) key: value.name,
  });

  /// Key of [note] in the saved map.
  static String storeKey(NoteKey note) =>
      '${folderPrefix(note.folderId)}${note.path.value}';

  /// How the keys of the notes in folder [folderId] start.
  static String folderPrefix(String folderId) => '$folderId/';
}
