import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../folders/note_folder.dart';
import 'note.dart';

/// Reads all notes of one folder. Keeps the last scan, so a rescan reads
/// only files whose stamp changed.
///
/// Files that are not valid UTF-8 are left out: they cannot be edited
/// without damaging them.
final class NoteScanner {
  NoteScanner(this.folder, this._services);

  final NoteFolder folder;
  final FolderServices _services;
  Map<RelPath, Note> _last = {};

  Future<Result<List<Note>, StoreError>> scan() async {
    final List<FileEntry> entries;
    switch (await _services.store.list(
      enterFolder: _services.filter.includesFolder,
    )) {
      case Ok(:final value):
        entries = value;
      case Err(:final error):
        return Err(error);
    }

    final next = <RelPath, Note>{};
    for (final entry in entries) {
      if (!_services.filter.includesFile(entry.path)) continue;
      final note = await _noteFor(entry);
      if (note != null) next[entry.path] = note;
    }
    _last = next;
    return Ok(next.values.toList());
  }

  /// The cached note if unchanged, else a fresh read; `null` if the file
  /// vanished or is not text.
  Future<Note?> _noteFor(FileEntry entry) async {
    final cached = _last[entry.path];
    if (cached != null && cached.stamp == entry.stamp) return cached;
    final read = await _services.store.read(entry.path);
    if (read case Ok(value: final content)) {
      final file = TextFile.decode(content.bytes);
      if (file == null) return null;
      return Note(
        folder: folder,
        path: entry.path,
        file: file,
        stamp: content.stamp,
      );
    }
    return null;
  }
}
