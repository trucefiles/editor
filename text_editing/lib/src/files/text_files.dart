import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../text/text_file.dart';
import 'file_text.dart';
import 'text_file_type.dart';

/// The text files of one folder, as the text editing kit reads and
/// writes them: [FilesOfFolder]'s bytes as text, each file kept in its
/// own byte style.
final class TextFiles {
  const TextFiles(this._files);

  final FilesOfFolder _files;

  /// [file]'s file as it is now.
  Future<Result<FileText, OpenFailure>> reload(ListedFile file) =>
      open(file.path);

  /// The file at [path], with its text: refused if the app doesn't show
  /// its type; [NotText] if it is not text.
  Future<Result<FileText, OpenFailure>> open(RelPath path) async =>
      textOf(await _files.read(path));

  /// New file of [type] in [subfolder] (see [FilesOfFolder.create]),
  /// holding [text] in its type's new file style.
  Future<Result<FileText, StoreError>> create(
    String title, {
    required TextFileType type,
    RelPath? subfolder,
    required String text,
    bool newSubfolder = false,
  }) async {
    final file = type.newFile.withText(text);
    final created = await _files.create(
      title,
      type: type,
      subfolder: subfolder,
      bytes: file.encode(text),
      newSubfolder: newSubfolder,
    );
    return created.map((written) => FileText(written.listed, file));
  }

  /// Writes [text] over [file]; fails with [StoreError.changedSinceRead]
  /// if the file changed since [file] was read.
  Future<Result<FileText, StoreError>> save(FileText file, String text) =>
      _written(_files.replace(file.listed, _bytes(file, text)), file, text);

  /// Writes [text] as [file]'s file again, e.g. after it was deleted
  /// elsewhere. Never overwrites an existing file.
  Future<Result<FileText, StoreError>> restore(FileText file, String text) =>
      _written(_files.restore(file.path, _bytes(file, text)), file, text);

  /// Keeps [text] as a conflict copy of [file], for edits that cannot go
  /// into its file.
  Future<Result<void, StoreError>> saveAsConflict(FileText file, String text) =>
      _files.saveAsConflict(file.path, _bytes(file, text));

  /// Like [saveAsConflict], for a file at [path] whose file is gone:
  /// [text] is written in [style], its type's for a new file (e.g. a
  /// calendar's line breaks).
  Future<Result<void, StoreError>> saveAsConflictOfGone(
    RelPath path,
    String text, {
    required TextFile style,
  }) => _files.saveAsConflict(path, style.encode(text));

  /// Keeps a backup of [text], the file's text now, before the user
  /// replaces it with a backup.
  Future<Result<void, StoreError>> backUpCurrent(FileText file, String text) =>
      _files.backUpCurrent(file.path, _bytes(file, text));

  /// Keeps a backup of [current], the file, and [edited], text the user
  /// edited from an older version, before the user keeps one of them.
  Future<Result<void, StoreError>> backUp(FileText current, String edited) =>
      _files.backUp(
        current.path,
        current: _bytes(current, current.text),
        other: _bytes(current, edited),
      );

  /// Keeps a backup of [file]'s file before edits are first saved over it.
  Future<Result<void, StoreError>> backUpBeforeEdit(FileText file) =>
      _files.backUpBeforeEdit(file.fileBytes);

  /// [text] in [file]'s byte style.
  static Uint8List _bytes(FileText file, String text) =>
      file.textFile.encode(text);

  /// [written], the file now holding [text] in [file]'s byte style.
  static Future<Result<FileText, StoreError>> _written(
    Future<Result<FileBytes, StoreError>> written,
    FileText file,
    String text,
  ) async => (await written).map(
    (now) => FileText(now.listed, file.textFile.withText(text)),
  );

  /// The file [read] gave, as text: [NotRead] if it couldn't be read,
  /// [NotText] if its bytes are not UTF-8.
  static Result<FileText, OpenFailure> textOf(
    Result<FileBytes, StoreError> read,
  ) => switch (read) {
    Ok(value: final read) => switch (FileText.of(read)) {
      final text? => Ok(text),
      null => const Err(NotText()),
    },
    Err(:final error) => Err(NotRead(error)),
  };
}
