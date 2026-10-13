import 'dart:convert';
import 'dart:io';

import 'note.dart';
import 'note_view.dart';

/// Keeps the last view of each note in a JSON file in app storage. Per
/// device and never synced. A convenience: read and write failures are
/// ignored.
final class NoteViewStore {
  const NoteViewStore(this._file);

  final File _file;

  /// The saved views by [storeKey]; empty if none or unreadable.
  Future<Map<String, NoteView>> load() async {
    try {
      if (!await _file.exists()) return const {};
      return switch (jsonDecode(await _file.readAsString())) {
        final Map<String, Object?> json => {
          for (final MapEntry(:key, :value) in json.entries)
            key: ?NoteView.values.asNameMap()[value],
        },
        _ => const {},
      };
    } on FileSystemException {
      return const {};
    } on FormatException {
      return const {};
    }
  }

  /// Replaces the saved views atomically, via a temp file.
  Future<void> save(Map<String, NoteView> views) async {
    final temp = File('${_file.path}.tmp');
    try {
      await _file.parent.create(recursive: true);
      await temp.writeAsString(
        jsonEncode({
          for (final MapEntry(:key, :value) in views.entries) key: value.name,
        }),
        flush: true,
      );
      await temp.rename(_file.path);
    } on FileSystemException {
      // Only a convenience; the next save tries again.
    }
  }

  /// Key of [note] in the saved map.
  static String storeKey(NoteKey note) => '${note.folderId}/${note.path.value}';
}
