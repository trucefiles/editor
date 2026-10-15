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
  Future<Result<Note, StoreError>> reload(Note note) => open(note.path);

  /// The note in the file at [path].
  Future<Result<Note, StoreError>> open(RelPath path) async {
    final read = await _store.read(path);
    return switch (read) {
      Ok(value: final content) => switch (TextFile.decode(content.bytes)) {
        final file? => Ok(_note(path, file, content.version, content.modified)),
        null => const Err(StoreError.ioFailure),
      },
      Err(:final error) => Err(error),
    };
  }

  /// New note in [subfolder] (the folder's root if `null`), named after
  /// [title], starting with a `# title` line.
  Future<Result<Note, StoreError>> create(
    String title, {
    RelPath? subfolder,
  }) async {
    final file = TextFile.empty().withText('# ${title.trim()}\n');
    final bytes = file.encode(file.text);
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final name = noteFileName(title, attempt: attempt);
      final path = subfolder == null
          ? RelPath.parse(name)!
          : subfolder.child(name)!;
      switch (await _store.create(path, bytes)) {
        case Ok(value: final entry):
          return Ok(_noteAt(entry, file));
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
      ifUnchanged: note.version,
    );
    return switch (written) {
      Ok(value: final entry) => Ok(_noteAt(entry, note.file.withText(text))),
      Err(:final error) => Err(error),
    };
  }

  /// Writes [text] as [note]'s file again, e.g. after it was deleted
  /// elsewhere or to undo a delete. Never overwrites an existing file.
  Future<Result<Note, StoreError>> restore(Note note, String text) async {
    final created = await _store.create(note.path, note.file.encode(text));
    return switch (created) {
      Ok(value: final entry) => Ok(_noteAt(entry, note.file.withText(text))),
      Err(:final error) => Err(error),
    };
  }

  /// Keeps [text] as a conflict copy of [note], for edits that cannot go
  /// into its file. It syncs, and is resolved like any conflict.
  Future<Result<void, StoreError>> saveAsConflict(Note note, String text) =>
      _services.conflicts.keepAsConflict(note.path, note.file.encode(text));

  /// Like [saveAsConflict], for a note whose file is gone: [text] is
  /// written in the default byte style.
  Future<Result<void, StoreError>> saveAsConflictOfGone(
    RelPath path,
    String text,
  ) => _services.conflicts.keepAsConflict(path, TextFile.empty().encode(text));

  /// Keeps a backup of [current], the note's file, and [edited], text the
  /// user edited from an older version, before the user keeps one of them.
  Future<Result<void, StoreError>> backUp(Note current, String edited) =>
      _services.backups.saveBoth(
        at: DateTime.now(),
        filePath: current.path,
        current: current.file.encode(current.file.text),
        other: current.file.encode(edited),
      );

  /// Keeps a backup of [note]'s file before edits are first saved over it.
  Future<Result<void, StoreError>> backUpBeforeEdit(Note note) =>
      _services.backups.saveBeforeEdit(
        at: DateTime.now(),
        filePath: note.path,
        bytes: note.file.encode(note.file.text),
      );

  Future<Result<void, StoreError>> delete(Note note) =>
      _store.delete(note.path, ifUnchanged: note.version);

  /// The note just written as [entry], holding [file].
  Note _noteAt(FileEntry entry, TextFile file) =>
      _note(entry.path, file, entry.version, entry.modified);

  Note _note(
    RelPath path,
    TextFile file,
    FileVersion version,
    DateTime modified,
  ) => Note(
    folder: _folder,
    path: path,
    file: file,
    version: version,
    modified: modified,
  );
}

final noteFilesProvider = Provider.family<NoteFiles, NoteFolder>(
  (ref, folder) =>
      NoteFiles(folder, ref.watch(folderServicesProvider(folder.location))),
);
