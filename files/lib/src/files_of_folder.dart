import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'file_text.dart';
import 'listed_file.dart';
import 'move_failure.dart';
import 'new_file_name.dart';
import 'open_failure.dart';
import 'shown_file_type.dart';
import 'shown_file_types.dart';

/// Reads and writes single files in one folder, through its services.
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

  FileStore get _store => _services.store;

  /// [file]'s file as it is now.
  Future<Result<FileText, OpenFailure>> reload(ListedFile file) =>
      open(file.path);

  /// The bytes of the file at [path], e.g. an image a file shows; `null`
  /// if it can't be read.
  Future<Uint8List?> bytesOf(RelPath path) async =>
      switch (await _store.read(path)) {
        Ok(value: final content) => content.bytes,
        Err() => null,
      };

  /// The file at [path], with its text: refused if the app doesn't show
  /// its type; [NotText] if it is not text.
  Future<Result<FileText, OpenFailure>> open(RelPath path) async {
    final type = _types.of(path)?.support;
    if (type == null) {
      return const Err(NotRead(StoreError.outside));
    }
    final read = await _store.read(path);
    return switch (read) {
      Ok(value: final content) => switch (TextFile.decode(content.bytes)) {
        final file? => Ok(
          FileText(_file(path, type, content.version, content.modified), file),
        ),
        null => const Err(NotText()),
      },
      Err(:final error) => Err(NotRead(error)),
    };
  }

  /// New file of [type] in [subfolder] (the folder's top level if
  /// `null`), named after [title], holding [text]; [newSubfolder] makes
  /// [subfolder] first. If [subfolder] is gone, the file goes to the
  /// folder's top level: it is kept, and the deleted subfolder never
  /// comes back.
  Future<Result<FileText, StoreError>> create(
    String title, {
    required ShownFileType type,
    RelPath? subfolder,
    required String text,
    bool newSubfolder = false,
  }) async {
    final file = type.newFile.withText(text);
    final extension = type.newFileExtension;
    final created = await _createNamed(title, extension, (
      folder: subfolder,
      isNew: newSubfolder,
    ), file);
    if (created case Err(error: StoreError.notFound) when subfolder != null) {
      return _createNamed(title, extension, (folder: null, isNew: false), file);
    }
    return created;
  }

  /// A copy of [file], from any folder, holding [text] in
  /// [file]'s byte style, in [subfolder] (the folder's top level
  /// if `null`; made first if [newSubfolder]); named after [title] (by
  /// default [file]'s name) with [file]'s extension, and a number
  /// if that name is taken.
  Future<Result<FileText, StoreError>> copyIn(
    FileText file,
    String text, {
    RelPath? subfolder,
    bool newSubfolder = false,
    String? title,
  }) {
    final (:base, :extension) = splitFileName(file.path.name);
    return _createNamed(title ?? base, extension, (
      folder: subfolder,
      isNew: newSubfolder,
    ), file.textFile.withText(text));
  }

  /// Moves [read]'s file, as last saved, from this folder into [target]
  /// (this one too), to [subfolder] (its top level if `null`; made first
  /// if [newSubfolder]); named after [title] (by default [read]'s name)
  /// with [read]'s extension, and a number if that name is taken. The
  /// folder decides how ([OpenFolder.moveInto]). Nothing moves if the
  /// file changed since [read] was read; if its old file can't be
  /// removed, both stay ([MoveLeftOriginal]).
  Future<Result<FileText, MoveFailure>> moveTo(
    FilesOfFolder target,
    FileText read, {
    RelPath? subfolder,
    bool newSubfolder = false,
    String? title,
  }) async {
    final FileText(listed: ListedFile(path: from, :version), textFile: file) =
        read;
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
      file,
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
  Future<Result<FileText, StoreError>> _createNamed(
    String title,
    String extension,
    _Subfolder subfolder,
    TextFile file,
  ) {
    final bytes = file.encode(file.text);
    return _named(
      title,
      extension,
      subfolder,
      (path) => _store.create(path, bytes),
      file,
    );
  }

  /// Writes [file] by [write] at the first free name after [title] in
  /// [subfolder]'s folder, made first if it is a new one the user asked
  /// for. Fails with [StoreError.notFound] if an existing one is gone: the
  /// store would create it, and a deleted folder never comes back.
  Future<Result<FileText, StoreError>> _named(
    String title,
    String extension,
    _Subfolder subfolder,
    Future<Result<FileEntry, StoreError>> Function(RelPath path) write,
    TextFile file,
  ) async {
    if (await _ready(subfolder) case Err(:final error)) return Err(error);
    final folder = subfolder.folder;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final name = newFileName(title, attempt: attempt, extension: extension);
      final path = folder == null ? RelPath.parse(name)! : folder.child(name)!;
      switch (await write(path)) {
        case Ok(value: final entry):
          return Ok(_fileAt(entry, file));
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

  /// Writes [text] over [file]; fails with [StoreError.changedSinceRead]
  /// if the file changed since [file] was read.
  Future<Result<FileText, StoreError>> save(FileText file, String text) async {
    final written = await _store.replace(
      file.path,
      file.textFile.encode(text),
      ifUnchanged: file.listed.version,
    );
    return switch (written) {
      Ok(value: final entry) => Ok(
        _fileAt(entry, file.textFile.withText(text)),
      ),
      Err(:final error) => Err(error),
    };
  }

  /// Writes [text] as [file]'s file again, e.g. after it was deleted
  /// elsewhere or to undo a delete. Never overwrites an existing file.
  Future<Result<FileText, StoreError>> restore(
    FileText file,
    String text,
  ) async {
    final created = await _store.create(file.path, file.textFile.encode(text));
    return switch (created) {
      Ok(value: final entry) => Ok(
        _fileAt(entry, file.textFile.withText(text)),
      ),
      Err(:final error) => Err(error),
    };
  }

  /// Keeps [text] as a conflict copy of [file], for edits that cannot go
  /// into its file. It syncs, and is resolved like any conflict.
  Future<Result<void, StoreError>> saveAsConflict(FileText file, String text) =>
      _services.conflicts.keepAsConflict(file.path, file.textFile.encode(text));

  /// Like [saveAsConflict], for a file whose file is gone: [text] is
  /// written in its type's style for a new file (e.g. a calendar's line
  /// breaks).
  Future<Result<void, StoreError>> saveAsConflictOfGone(
    RelPath path,
    String text,
  ) => _services.conflicts.keepAsConflict(
    path,
    (_types.of(path)?.newFile ?? const TextFile.empty()).encode(text),
  );

  /// Keeps a backup of [text], the file's text now, before the user
  /// replaces it with a backup.
  Future<Result<void, StoreError>> backUpCurrent(FileText file, String text) =>
      _services.backups.saveCurrent(
        at: DateTime.now(),
        filePath: file.path,
        bytes: file.textFile.encode(text),
      );

  /// Keeps a backup of [current], the file, and [edited], text the
  /// user edited from an older version, before the user keeps one of them.
  Future<Result<void, StoreError>> backUp(FileText current, String edited) =>
      _services.backups.saveBoth(
        at: DateTime.now(),
        filePath: current.path,
        current: current.textFile.encode(current.text),
        other: current.textFile.encode(edited),
      );

  /// Keeps a backup of [file]'s file before edits are first saved over it.
  Future<Result<void, StoreError>> backUpBeforeEdit(FileText file) =>
      _services.backups.saveBeforeEdit(
        at: DateTime.now(),
        filePath: file.path,
        bytes: file.textFile.encode(file.text),
      );

  Future<Result<void, StoreError>> delete(ListedFile file) =>
      _store.delete(file.path, ifUnchanged: file.version);

  /// The file just written as [entry], holding [file].
  /// Only ever of a handled type: the store writes nothing else.
  FileText _fileAt(FileEntry entry, TextFile file) => FileText(
    _file(
      entry.path,
      _types.of(entry.path)!.support,
      entry.version,
      entry.modified,
    ),
    file,
  );

  ListedFile _file(
    RelPath path,
    FileTypeSupport<Object?> type,
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
