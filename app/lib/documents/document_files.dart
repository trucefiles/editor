import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../file_types/document_type.dart';
import '../file_types/document_types.dart';
import '../folders/document_folder.dart';
import '../sync_tool/base_folder_services.dart';
import 'document.dart';
import 'document_file_name.dart';
import 'document_text.dart';
import 'open_failure.dart';

/// Reads and writes single document files in one folder, through its base
/// folder's services. Every write is atomic and checks that the file did
/// not change since it was read. A path the folder doesn't show, or of a
/// type the app doesn't handle, is refused with [StoreError.outside].
final class DocumentFiles {
  const DocumentFiles(this._folder, this._services, this._types);

  /// Gives up on a unique name after this many tries.
  static const _maxAttempts = 100;

  final DocumentFolder _folder;
  final BaseFolderServices _services;
  final DocumentTypes _types;

  FileStore get _store => _services.store;

  /// [document]'s file as it is now.
  Future<Result<DocumentText, OpenFailure>> reload(Document document) =>
      open(document.path);

  /// The bytes of the file at [path], e.g. an image a document shows; `null`
  /// if it can't be read.
  Future<Uint8List?> bytesOf(RelPath path) async =>
      switch (await _store.read(path)) {
        Ok(value: final content) => content.bytes,
        Err() => null,
      };

  /// The document in the file at [path], with its text, e.g. kept from
  /// before its folder changed: refused if the folder doesn't show it;
  /// [NotText] if it is not text.
  Future<Result<DocumentText, OpenFailure>> open(RelPath path) async {
    final type = _types.of(path);
    if (type == null || !_folder.covers(path)) {
      return const Err(NotRead(StoreError.outside));
    }
    final read = await _store.read(path);
    return switch (read) {
      Ok(value: final content) => switch (TextFile.decode(content.bytes)) {
        final file? => Ok(
          DocumentText(
            _document(path, type, content.version, content.modified),
            file,
          ),
        ),
        null => const Err(NotText()),
      },
      Err(:final error) => Err(NotRead(error)),
    };
  }

  /// New document of [type] in [subfolder] (the base folder's top level
  /// if `null`), named after [title], holding [text]; by default a
  /// `# title` line. If [subfolder] is gone, the document goes to the top
  /// of the folder's part that held it: it is kept, and the deleted
  /// folder never comes back.
  Future<Result<DocumentText, StoreError>> create(
    String title, {
    required DocumentType type,
    RelPath? subfolder,
    String? text,
  }) async {
    final file = TextFile.empty().withText(text ?? '# ${title.trim()}\n');
    final extension = type.newFileExtension;
    final created = await _createNamed(title, extension, subfolder, file);
    if (created case Err(error: StoreError.notFound) when subfolder != null) {
      final top = _topOf(subfolder);
      if (top != subfolder) return _createNamed(title, extension, top, file);
    }
    return created;
  }

  /// The top of the folder's part that holds [subfolder]: the base
  /// folder's top level (`null`) or a selected subfolder.
  RelPath? _topOf(RelPath subfolder) => switch (_folder.selection) {
    WholeFolder() => null,
    final Subfolders subfolders => subfolders.rootOf(subfolder),
  };

  /// Creates [subfolder], a new one the user asked for; one that is
  /// already there is fine. Never brings back a gone chosen subfolder of
  /// the folder, nor the base folder.
  Future<Result<void, StoreError>> createSubfolder(RelPath subfolder) =>
      _store.createFolder(subfolder);

  /// A copy of [document], from any folder, holding [text] in
  /// [document]'s byte style, in [subfolder] (the base folder's top level
  /// if `null`); named after [title] (by default [document]'s name) with
  /// [document]'s extension, and a number if that name is taken.
  Future<Result<DocumentText, StoreError>> copyIn(
    DocumentText document,
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

  /// Moves [document]'s file, as last saved, from anywhere in this base
  /// folder to [subfolder] (its top level if `null`); named after [title]
  /// (by default [document]'s name) with [document]'s extension, and a
  /// number if that name is taken. Fails with [StoreError.changedSinceRead]
  /// if the file changed since [document] was read: nothing moved.
  Future<Result<DocumentText, StoreError>> moveIn(
    DocumentText document, {
    RelPath? subfolder,
    String? title,
  }) {
    final DocumentText(document: Document(path: from, :version), :file) =
        document;
    final (:base, :extension) = splitFileName(from.name);
    return _named(
      title ?? base,
      extension,
      subfolder,
      (path) => _store.move(from, path, ifUnchanged: version),
      file,
    );
  }

  /// Fails with [StoreError.notFound] if [subfolder] is gone: the store
  /// would create it, and a deleted folder never comes back.
  Future<Result<DocumentText, StoreError>> _createNamed(
    String title,
    String extension,
    RelPath? subfolder,
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
  /// [subfolder]. Fails with [StoreError.notFound] if [subfolder] is gone:
  /// the store would create it, and a deleted folder never comes back.
  Future<Result<DocumentText, StoreError>> _named(
    String title,
    String extension,
    RelPath? subfolder,
    Future<Result<FileEntry, StoreError>> Function(RelPath path) write,
    TextFile file,
  ) async {
    if (subfolder != null && !await _hasFolder(subfolder)) {
      return const Err(StoreError.notFound);
    }
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      final name = documentFileName(
        title,
        attempt: attempt,
        extension: extension,
      );
      final path = subfolder == null
          ? RelPath.parse(name)!
          : subfolder.child(name)!;
      switch (await write(path)) {
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

  /// Whether [subfolder] is there.
  Future<bool> _hasFolder(RelPath subfolder) async =>
      switch (await _store.foldersThere({subfolder})) {
        Ok(value: final there) => there.contains(subfolder),
        Err() => false,
      };

  /// Writes [text] over [document]; fails with [StoreError.changedSinceRead]
  /// if the file changed since [document] was read.
  Future<Result<DocumentText, StoreError>> save(
    DocumentText document,
    String text,
  ) async {
    final written = await _store.replace(
      document.path,
      document.file.encode(text),
      ifUnchanged: document.document.version,
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
  Future<Result<DocumentText, StoreError>> restore(
    DocumentText document,
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
    DocumentText document,
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
    DocumentText document,
    String text,
  ) => _services.backups.saveCurrent(
    at: DateTime.now(),
    filePath: document.path,
    bytes: document.file.encode(text),
  );

  /// Keeps a backup of [current], the document's file, and [edited], text the
  /// user edited from an older version, before the user keeps one of them.
  Future<Result<void, StoreError>> backUp(
    DocumentText current,
    String edited,
  ) => _services.backups.saveBoth(
    at: DateTime.now(),
    filePath: current.path,
    current: current.file.encode(current.text),
    other: current.file.encode(edited),
  );

  /// Keeps a backup of [document]'s file before edits are first saved over it.
  Future<Result<void, StoreError>> backUpBeforeEdit(DocumentText document) =>
      _services.backups.saveBeforeEdit(
        at: DateTime.now(),
        filePath: document.path,
        bytes: document.file.encode(document.text),
      );

  Future<Result<void, StoreError>> delete(Document document) =>
      _store.delete(document.path, ifUnchanged: document.version);

  /// The document just written as [entry], holding [file].
  /// Only ever of a handled type: the store writes nothing else.
  DocumentText _documentAt(FileEntry entry, TextFile file) => DocumentText(
    _document(
      entry.path,
      _types.of(entry.path)!,
      entry.version,
      entry.modified,
    ),
    file,
  );

  Document _document(
    RelPath path,
    DocumentType type,
    FileVersion version,
    DateTime modified,
  ) => Document(
    folder: _folder,
    path: path,
    type: type,
    version: version,
    modified: modified,
  );
}

final documentFilesProvider = Provider.family<DocumentFiles, DocumentFolder>(
  (ref, folder) => DocumentFiles(
    folder,
    ref.watch(baseFolderServicesProvider(folder.base)),
    ref.watch(documentTypesProvider),
  ),
);
