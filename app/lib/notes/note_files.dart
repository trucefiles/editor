import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../folders/note_folder.dart';
import 'note.dart';
import 'note_file_name.dart';

/// Reads and writes single note files in one folder. Every write is atomic
/// and checks that the file did not change since it was read.
final class NoteFiles {
  const NoteFiles(this._folder, this._services);

  /// Gives up on a unique name after this many tries.
  static const _maxAttempts = 100;

  final NoteFolder _folder;
  final FolderServices _services;

  FileStore get _store => _services.store;

  /// The current version of [note]'s file.
  Future<Result<Note, StoreError>> reload(Note note) async {
    final read = await _store.read(note.path);
    return switch (read) {
      Ok(value: final content) => switch (TextFile.decode(content.bytes)) {
        final file? => Ok(_note(note.path, file, content.stamp)),
        null => const Err(StoreError.ioFailure),
      },
      Err(:final error) => Err(error),
    };
  }

  /// New note at the folder's root, named after [title], starting with a
  /// `# title` line.
  Future<Result<Note, StoreError>> create(String title) async {
    final file = TextFile.empty().withText('# ${title.trim()}\n');
    final bytes = file.encode(file.text);
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final path = RelPath.parse(noteFileName(title, attempt: attempt))!;
      switch (await _store.create(path, bytes)) {
        case Ok(value: final stamp):
          return Ok(_note(path, file, stamp));
        case Err(error: StoreError.alreadyExists):
          continue;
        case Err(:final error):
          return Err(error);
      }
    }
    return const Err(StoreError.alreadyExists);
  }

  /// Writes [text] over [note]; fails with [StoreError.changedSinceRead]
  /// if the file changed since [note] was read.
  Future<Result<Note, StoreError>> save(Note note, String text) async {
    final written = await _store.replace(
      note.path,
      note.file.encode(text),
      ifUnchanged: note.stamp,
    );
    return switch (written) {
      Ok(value: final stamp) => Ok(
        _note(note.path, note.file.withText(text), stamp),
      ),
      Err(:final error) => Err(error),
    };
  }

  /// Writes [text] as [note]'s file again, e.g. after it was deleted
  /// elsewhere or to undo a delete. Never overwrites an existing file.
  Future<Result<Note, StoreError>> restore(Note note, String text) async {
    final created = await _store.create(note.path, note.file.encode(text));
    return switch (created) {
      Ok(value: final stamp) => Ok(
        _note(note.path, note.file.withText(text), stamp),
      ),
      Err(:final error) => Err(error),
    };
  }

  /// Keeps [text] as a conflict copy of [note], for edits that cannot go
  /// into its file. It syncs, and is resolved like any conflict.
  Future<Result<void, StoreError>> saveAsConflict(Note note, String text) =>
      _services.conflicts.keepAsConflict(note.path, note.file.encode(text));

  Future<Result<void, StoreError>> delete(Note note) =>
      _store.delete(note.path, ifUnchanged: note.stamp);

  Note _note(RelPath path, TextFile file, FileStamp stamp) =>
      Note(folder: _folder, path: path, file: file, stamp: stamp);
}

final noteFilesProvider = Provider.family<NoteFiles, NoteFolder>(
  (ref, folder) => NoteFiles(folder, ref.watch(folderServicesProvider(folder))),
);
