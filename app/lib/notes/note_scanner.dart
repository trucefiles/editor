import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../folders/note_folder.dart';
import 'note.dart';

/// Reads all notes of one folder. Keeps the last scan, so a rescan reads
/// only files whose stamp changed.
///
/// Files that are not valid UTF-8 are left out: they cannot be edited
/// without damaging them. A listed file that can't be read as text right
/// now (e.g. mid-rewrite, or briefly no access) keeps its last version, so
/// it doesn't look deleted.
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

  /// The cached note if unchanged, else a fresh read; the cached note if
  /// that fails while the file still exists; `null` if the file vanished,
  /// or is not text and was never read as text.
  Future<Note?> _noteFor(FileEntry entry) async {
    final cached = _last[entry.path];
    if (cached != null && cached.stamp == entry.stamp) return cached;
    switch (await _services.store.read(entry.path)) {
      case Ok(value: final content):
        return switch (TextFile.decode(content.bytes)) {
          final file? => Note(
            folder: folder,
            path: entry.path,
            file: file,
            stamp: content.stamp,
          ),
          null => cached,
        };
      case Err(error: StoreError.notFound):
        return null;
      case Err():
        return cached;
    }
  }
}
