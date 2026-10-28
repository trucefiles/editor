import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../file_types/document_types.dart';
import '../folders/document_folder.dart';
import '../sync_tool/folder_services.dart';
import 'document.dart';
import 'document_file_name.dart';

/// Reads and writes single document files in one folder. Every write is atomic
/// and checks that the file did not change since it was read.
final class DocumentFiles {
  const DocumentFiles(this._folder, this._services);

  /// Gives up on a unique name after this many tries.
  static const _maxAttempts = 100;

  final DocumentFolder _folder;
  final FolderServices _services;

  FileStore get _store => _services.store;

  /// The current version of [document]'s file.
  Future<Result<Document, StoreError>> reload(Document document) =>
      open(document.path);

  /// The bytes of the file at [path], e.g. an image a document shows; `null`
  /// if it can't be read.
  Future<Uint8List?> bytesOf(RelPath path) async =>
      switch (await _store.read(path)) {
        Ok(value: final content) => content.bytes,
        Err() => null,
      };

  /// The document in the file at [path].
  Future<Result<Document, StoreError>> open(RelPath path) async {
    final read = await _store.read(path);
    return switch (read) {
      Ok(value: final content) => switch (TextFile.decode(content.bytes)) {
        final file? => Ok(
          _document(path, file, content.version, content.modified),
        ),
        null => const Err(StoreError.ioFailure),
      },
      Err(:final error) => Err(error),
    };
  }

  /// New document in [subfolder] (the folder's root if `null`), named after
  /// [title], holding [text]; by default a `# title` line. If [subfolder]
  /// is gone, the document goes to the folder's top level: it is kept, and the
  /// deleted folder never comes back.
  Future<Result<Document, StoreError>> create(
    String title, {
    RelPath? subfolder,
    String? text,
  }) async {
    final file = TextFile.empty().withText(text ?? '# ${title.trim()}\n');
    final extension = newDocumentType.newFileExtension;
    final created = await _createNamed(title, extension, subfolder, file);
    if (created case Err(error: StoreError.notFound) when subfolder != null) {
      return _createNamed(title, extension, null, file);
    }
    return created;
  }

  /// A copy of [document], from any folder, holding [text] in [document]'s byte
  /// style, in [subfolder] of this folder (its root if `null`); named
  /// after [title] (by default [document]'s name) with [document]'s extension, and
  /// a number if that name is taken.
  Future<Result<Document, StoreError>> copyIn(
    Document document,
    String text, {
    RelPath? subfolder,
    String? title,
  }) {
    final (:base, :extension) = splitFileName(document.path.name);
    return _createNamed(
      title ?? base,
      extension,
      subfolder,
      document.file.withText(text),
    );
  }

  /// Fails with [StoreError.notFound] if [subfolder] is gone: the store
  /// would create it, and a deleted folder never comes back.
  Future<Result<Document, StoreError>> _createNamed(
    String title,
    String extension,
    RelPath? subfolder,
    TextFile file,
  ) async {
    if (subfolder != null && !await _hasFolder(subfolder)) {
      return const Err(StoreError.notFound);
    }
    final bytes = file.encode(file.text);
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final name = documentFileName(
        title,
        attempt: attempt,
        extension: extension,
      );
      final path = subfolder == null
          ? RelPath.parse(name)!
          : subfolder.child(name)!;
      switch (await _store.create(path, bytes)) {
        case Ok(value: final entry):
          return Ok(_documentAt(entry, file));
        case Err(error: StoreError.alreadyExists):
          continue;
        case Err(:final error):
          return Err(error);
      }
    }
    return const Err(StoreError.alreadyExists);
  }

  /// Whether [subfolder] is there; lists only the folders on the way to it.
  Future<bool> _hasFolder(RelPath subfolder) async {
    bool onTheWay(RelPath folder) =>
        folder == subfolder || subfolder.value.startsWith('${folder.value}/');
    final listed = await _store.list(
      enterFolder: onTheWay,
      includeFile: (_) => false,
    );
    return switch (listed) {
      Ok(value: final listing) =>
        listing.folders.contains(subfolder) ||
            listing.unreadable.contains(subfolder),
      Err() => false,
    };
  }

  /// Writes [text] over [document]; fails with [StoreError.changedSinceRead]
  /// if the file changed since [document] was read.
  Future<Result<Document, StoreError>> save(
    Document document,
    String text,
  ) async {
    final written = await _store.replace(
      document.path,
      document.file.encode(text),
      ifUnchanged: document.version,
    );
    return switch (written) {
      Ok(value: final entry) => Ok(
        _documentAt(entry, document.file.withText(text)),
      ),
      Err(:final error) => Err(error),
    };
  }

  /// Writes [text] as [document]'s file again, e.g. after it was deleted
  /// elsewhere or to undo a delete. Never overwrites an existing file.
  Future<Result<Document, StoreError>> restore(
    Document document,
    String text,
  ) async {
    final created = await _store.create(
      document.path,
      document.file.encode(text),
    );
    return switch (created) {
      Ok(value: final entry) => Ok(
        _documentAt(entry, document.file.withText(text)),
      ),
      Err(:final error) => Err(error),
    };
  }

  /// Keeps [text] as a conflict copy of [document], for edits that cannot go
  /// into its file. It syncs, and is resolved like any conflict.
  Future<Result<void, StoreError>> saveAsConflict(
    Document document,
    String text,
  ) => _services.conflicts.keepAsConflict(
    document.path,
    document.file.encode(text),
  );

  /// Like [saveAsConflict], for a document whose file is gone: [text] is
  /// written in the default byte style.
  Future<Result<void, StoreError>> saveAsConflictOfGone(
    RelPath path,
    String text,
  ) => _services.conflicts.keepAsConflict(path, TextFile.empty().encode(text));

  /// Keeps a backup of [text], the document's text now, before the user
  /// replaces it with a backup.
  Future<Result<void, StoreError>> backUpCurrent(
    Document document,
    String text,
  ) => _services.backups.saveCurrent(
    at: DateTime.now(),
    filePath: document.path,
    bytes: document.file.encode(text),
  );

  /// Keeps a backup of [current], the document's file, and [edited], text the
  /// user edited from an older version, before the user keeps one of them.
  Future<Result<void, StoreError>> backUp(Document current, String edited) =>
      _services.backups.saveBoth(
        at: DateTime.now(),
        filePath: current.path,
        current: current.file.encode(current.file.text),
        other: current.file.encode(edited),
      );

  /// Keeps a backup of [document]'s file before edits are first saved over it.
  Future<Result<void, StoreError>> backUpBeforeEdit(Document document) =>
      _services.backups.saveBeforeEdit(
        at: DateTime.now(),
        filePath: document.path,
        bytes: document.file.encode(document.file.text),
      );

  Future<Result<void, StoreError>> delete(Document document) =>
      _store.delete(document.path, ifUnchanged: document.version);

  /// The document just written as [entry], holding [file].
  Document _documentAt(FileEntry entry, TextFile file) =>
      _document(entry.path, file, entry.version, entry.modified);

  Document _document(
    RelPath path,
    TextFile file,
    FileVersion version,
    DateTime modified,
  ) => Document(
    folder: _folder,
    path: path,
    file: file,
    version: version,
    modified: modified,
  );
}

final documentFilesProvider = Provider.family<DocumentFiles, DocumentFolder>(
  (ref, folder) =>
      DocumentFiles(folder, ref.watch(folderServicesProvider(folder.location))),
);
