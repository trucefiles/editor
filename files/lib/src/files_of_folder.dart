import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'file_bytes.dart';
import 'listed_file.dart';
import 'move_failure.dart';
import 'new_file_name.dart';
import 'shown_file_type.dart';
import 'shown_file_types.dart';

/// Reads and writes single files in one folder, through its services,
/// as bytes.
/// Every write is atomic and checks that the file did not change since it
/// was read. A path of a type the app doesn't handle is refused with
/// [StoreError.outside]; once the folder is removed, everything with
/// [StoreError.closed].
final class FilesOfFolder {
  const FilesOfFolder(this._folder, this._services, this._types);

  /// Gives up on a unique name after this many tries.
  static const _maxAttempts = 100;

  final Folder _folder;
  final FolderServices _services;
  final ShownFileTypes _types;

  /// The folder these files are in.
  Folder get folder => _folder;

  FileStore get _store => _services.store;

  /// [file]'s file as it is now.
  Future<Result<FileBytes, StoreError>> reload(ListedFile file) =>
      read(file.path);

  /// The bytes of the file at [path], e.g. an image a file shows; `null`
  /// if it can't be read.
  Future<Uint8List?> bytesOf(RelPath path) async =>
      switch (await _store.read(path)) {
        Ok(value: final content) => content.bytes,
        Err() => null,
      };

  /// The file at [path], with its bytes: refused if the app doesn't show
  /// its type.
  Future<Result<FileBytes, StoreError>> read(RelPath path) async {
    final type = _types.of(path)?.support;
    if (type == null) return const Err(StoreError.outside);
    return (await _store.read(path)).map(
      (content) => FileBytes(
        _file(path, type, content.version, content.modified),
        content.bytes,
      ),
    );
  }

  /// New file of [type] in [subfolder] (the folder's top level if
  /// `null`), named after [title], holding [bytes]; [newSubfolder] makes
  /// [subfolder] first. If [subfolder] is gone, the file goes to the
  /// folder's top level: it is kept, and the deleted subfolder never
  /// comes back.
  Future<Result<FileBytes, StoreError>> create(
    String title, {
    required ShownFileType type,
    RelPath? subfolder,
    required Uint8List bytes,
    bool newSubfolder = false,
  }) => _createNew(
    title,
    type.newFileExtension,
    (folder: subfolder, isNew: newSubfolder),
    bytes,
    (path) => _store.create(path, bytes),
  );

  /// The new file a draft at [path] waits for, holding [bytes], written as
  /// [create] would: named after [path]'s name, in its folder
  /// ([newSubfolder]: a new one to make), else at the top level. A file at
  /// one of the names tried that already holds [bytes] is that file,
  /// written before the app was ended: it is not written twice.
  Future<Result<FileBytes, StoreError>> createOnce(
    RelPath path,
    Uint8List bytes, {
    bool newSubfolder = false,
  }) {
    final (:base, :extension) = splitFileName(path.name);
    return _createNew(
      base,
      extension,
      (folder: path.parent, isNew: newSubfolder),
      bytes,
      (at) async => switch (await _store.create(at, bytes)) {
        Err(error: StoreError.alreadyExists) => await _holding(at, bytes),
        final created => created,
      },
    );
  }

  /// The file at [path] if it holds [bytes]; else [StoreError.alreadyExists].
  Future<Result<FileEntry, StoreError>> _holding(
    RelPath path,
    Uint8List bytes,
  ) async => switch (await _store.read(path)) {
    Ok(:final value)
        when const ListEquality<int>().equals(value.bytes, bytes) =>
      Ok(FileEntry(path, version: value.version, modified: value.modified)),
    _ => const Err(StoreError.alreadyExists),
  };

  /// Writes a new file by [write] at the first free name after [title] in
  /// [subfolder] (see [_named]); if [subfolder] is gone, at the folder's
  /// top level: the file is kept, and the deleted subfolder never comes
  /// back.
  Future<Result<FileBytes, StoreError>> _createNew(
    String title,
    String extension,
    _Subfolder subfolder,
    Uint8List bytes,
    Future<Result<FileEntry, StoreError>> Function(RelPath path) write,
  ) async {
    final created = await _named(title, extension, subfolder, write, bytes);
    if (created case Err(error: StoreError.notFound)
        when subfolder.folder != null) {
      return _named(
        title,
        extension,
        (folder: null, isNew: false),
        write,
        bytes,
      );
    }
    return created;
  }

  /// A copy holding [bytes] of the file at [of] in any folder (or a
  /// backup of it), in [subfolder] (the folder's top level if `null`;
  /// made first if [newSubfolder]); named after [title] (by default
  /// [of]'s name) with [of]'s extension, and a number if that name is
  /// taken.
  Future<Result<FileBytes, StoreError>> copyIn(
    RelPath of,
    Uint8List bytes, {
    RelPath? subfolder,
    bool newSubfolder = false,
    String? title,
  }) {
    final (:base, :extension) = splitFileName(of.name);
    return _createNamed(title ?? base, extension, (
      folder: subfolder,
      isNew: newSubfolder,
    ), bytes);
  }

  /// Moves [read]'s file, as last saved, from this folder into [target]
  /// (this one too), to [subfolder] (its top level if `null`; made first
  /// if [newSubfolder]); named after [title] (by default [read]'s name)
  /// with [read]'s extension, and a number if that name is taken; holding
  /// [holding] there if given (its type changed it as it moved), else as
  /// it is. The folder decides how ([OpenFolder.moveInto]). Nothing moves
  /// if the file changed since [read] was read; if its old file can't be
  /// removed, both stay ([MoveLeftOriginal]).
  Future<Result<FileBytes, MoveFailure>> moveTo(
    FilesOfFolder target,
    FileBytes read, {
    RelPath? subfolder,
    bool newSubfolder = false,
    String? title,
    Uint8List? holding,
  }) async {
    final FileBytes(listed: ListedFile(path: from, :version)) = read;
    final bytes = holding ?? read.bytes;
    final (:base, :extension) = splitFileName(from.name);
    CopiedOnly? left;
    // A copy whose old file stays still names the file: it ends the
    // search for a free name.
    Future<Result<FileEntry, StoreError>> moveAt(RelPath path) async {
      switch (await _services.open.moveInto(
        from,
        ifUnchanged: version,
        target: target._services.open,
        to: path,
        bytes: holding,
      )) {
        case Ok(:final value):
          return Ok(value);
        case Err(error: NotMoved(:final error)):
          return Err(error);
        case Err(error: final CopiedOnly copied):
          left = copied;
          return Ok(copied.copy);
      }
    }

    final moved = await target._named(
      title ?? base,
      extension,
      (folder: subfolder, isNew: newSubfolder),
      moveAt,
      bytes,
    );
    return switch ((moved, left)) {
      (Ok(:final value), final CopiedOnly left) => Err(
        MoveLeftOriginal(value, left.error),
      ),
      (Ok(:final value), null) => Ok(value),
      (Err(:final error), _) => Err(MoveNotWritten(error)),
    };
  }

  /// See [_named].
  Future<Result<FileBytes, StoreError>> _createNamed(
    String title,
    String extension,
    _Subfolder subfolder,
    Uint8List bytes,
  ) => _named(
    title,
    extension,
    subfolder,
    (path) => _store.create(path, bytes),
    bytes,
  );

  /// Writes [bytes] by [write] at the first free name after [title] in
  /// [subfolder]'s folder, made first if it is a new one the user asked
  /// for. Fails with [StoreError.notFound] if an existing one is gone: the
  /// store would create it, and a deleted folder never comes back.
  Future<Result<FileBytes, StoreError>> _named(
    String title,
    String extension,
    _Subfolder subfolder,
    Future<Result<FileEntry, StoreError>> Function(RelPath path) write,
    Uint8List bytes,
  ) async {
    if (await _ready(subfolder) case Err(:final error)) return Err(error);
    final folder = subfolder.folder;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final name = newFileName(title, attempt: attempt, extension: extension);
      final path = folder == null ? RelPath.parse(name)! : folder.child(name)!;
      switch (await write(path)) {
        case Ok(value: final entry):
          return Ok(_fileAt(entry, bytes));
        case Err(error: StoreError.alreadyExists):
          continue;
        case Err(:final error):
          return Err(error);
      }
    }
    return const Err(StoreError.alreadyExists);
  }

  /// Makes [subfolder]'s folder if it is new, else checks it is there.
  Future<Result<void, StoreError>> _ready(_Subfolder subfolder) async =>
      switch (subfolder) {
        (folder: null, isNew: _) => const Ok(null),
        (folder: final folder?, isNew: true) => _store.createFolder(folder),
        (folder: final folder?, isNew: false) =>
          await _hasFolder(folder)
              ? const Ok(null)
              : const Err(StoreError.notFound),
      };

  /// Whether [subfolder] is there.
  Future<bool> _hasFolder(RelPath subfolder) async =>
      switch (await _store.foldersThere({subfolder})) {
        Ok(value: final there) => there.contains(subfolder),
        Err() => false,
      };

  /// Writes [bytes] over [file]; fails with [StoreError.changedSinceRead]
  /// if the file changed since [file] was read.
  Future<Result<FileBytes, StoreError>> replace(
    ListedFile file,
    Uint8List bytes,
  ) async {
    final written = await _store.replace(
      file.path,
      bytes,
      ifUnchanged: file.version,
    );
    return written.map((entry) => _fileAt(entry, bytes));
  }

  /// Writes [bytes] at [path] again, e.g. after its file was deleted
  /// elsewhere or to undo a delete. Never overwrites an existing file.
  Future<Result<FileBytes, StoreError>> restore(
    RelPath path,
    Uint8List bytes,
  ) async {
    final created = await _store.create(path, bytes);
    return created.map((entry) => _fileAt(entry, bytes));
  }

  /// Keeps [bytes] as a conflict copy of the file at [path], for edits
  /// that cannot go into its file. It syncs, and is resolved like any
  /// conflict.
  Future<Result<void, StoreError>> saveAsConflict(
    RelPath path,
    Uint8List bytes,
  ) => _services.conflicts.keepAsConflict(path, bytes);

  /// Keeps a backup of [bytes], the file at [path] now, before the user
  /// replaces it with a backup.
  Future<Result<void, StoreError>> backUpCurrent(
    RelPath path,
    Uint8List bytes,
  ) => _services.backups.saveCurrent(
    at: DateTime.now(),
    filePath: path,
    bytes: bytes,
  );

  /// Keeps a backup of [current], the file at [path], and [other], what
  /// the user edited from an older version, before the user keeps one of
  /// them.
  Future<Result<void, StoreError>> backUp(
    RelPath path, {
    required Uint8List current,
    required Uint8List other,
  }) => _services.backups.saveBoth(
    at: DateTime.now(),
    filePath: path,
    current: current,
    other: other,
  );

  /// Keeps a backup of [file]'s file before edits are first saved over it.
  Future<Result<void, StoreError>> backUpBeforeEdit(FileBytes file) =>
      _services.backups.saveBeforeEdit(
        at: DateTime.now(),
        filePath: file.path,
        bytes: file.bytes,
      );

  /// Keeps a backup of [bytes], the file at [path], as the user deletes
  /// it.
  Future<Result<void, StoreError>> backUpBeforeDelete(
    RelPath path,
    Uint8List bytes,
  ) => _services.backups.saveBeforeDelete(
    at: DateTime.now(),
    filePath: path,
    bytes: bytes,
  );

  Future<Result<void, StoreError>> delete(ListedFile file) =>
      _store.delete(file.path, ifUnchanged: file.version);

  /// The file just written as [entry], holding [bytes].
  /// Only ever of a handled type: the store writes nothing else.
  FileBytes _fileAt(FileEntry entry, Uint8List bytes) => FileBytes(
    _file(
      entry.path,
      _types.of(entry.path)!.support,
      entry.version,
      entry.modified,
    ),
    bytes,
  );

  ListedFile _file(
    RelPath path,
    FileTypeSupport type,
    FileVersion version,
    DateTime modified,
  ) => ListedFile(
    folder: _folder,
    path: path,
    type: type,
    version: version,
    modified: modified,
  );
}

/// Where a file goes in its folder: [folder] (its top level if
/// `null`), and whether it is a new one the user asked for ([isNew]),
/// made right before the file.
typedef _Subfolder = ({RelPath? folder, bool isNew});

/// The files of every folder, each through its services.
final class FileAccess {
  const FileAccess(this._servicesOf, this._types);

  final FolderServices Function(FolderId folder) _servicesOf;
  final ShownFileTypes _types;

  /// The files of [folder].
  FilesOfFolder of(Folder folder) =>
      FilesOfFolder(folder, _servicesOf(folder.id), _types);
}
