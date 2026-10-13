import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../folders/note_folder.dart';
import 'note.dart';

/// Reads the notes of one folder from its scanned files. Keeps the last
/// notes, so only files with a new version are read again.
///
/// Files that are not valid UTF-8 are left out: they cannot be edited
/// without damaging them. A note that can't be read as text any more
/// (e.g. mid-rewrite, briefly no access) keeps its last version while the
/// file exists, so it doesn't look deleted; saving to it then fails its
/// change check instead of overwriting anything.
final class NoteLoader {
  NoteLoader(this._folder, this._services);

  final NoteFolder _folder;
  final FolderServices _services;
  Map<RelPath, Note> _last = {};

  /// The notes in [files], as listed by the folder's scan.
  Future<List<Note>> load(List<FileEntry> files) async {
    final next = <RelPath, Note>{};
    for (final entry in files) {
      final note = await _noteFor(entry);
      if (note != null) next[entry.path] = note;
    }
    _last = next;
    return next.values.toList();
  }

  /// The last note if unchanged, else a fresh read; the last note if that
  /// fails while the file still exists; `null` if the file vanished, or is
  /// not text and was never read as text.
  Future<Note?> _noteFor(FileEntry entry) async {
    final last = _last[entry.path];
    if (last != null && last.version == entry.version) return last;
    switch (await _services.store.read(entry.path)) {
      case Ok(value: final content):
        return switch (TextFile.decode(content.bytes)) {
          final file? => Note(
            folder: _folder,
            path: entry.path,
            file: file,
            version: content.version,
            modified: content.modified,
          ),
          null => last,
        };
      case Err(error: StoreError.notFound):
        return null;
      case Err():
        return last;
    }
  }
}
