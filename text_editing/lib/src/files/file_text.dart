import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../text/text_file.dart';

/// A text file as the app last read or wrote it: the [listed] and its
/// text, in its file's byte style ([textFile]). The text editing kit's
/// reading of a file's bytes. Held only while the file is open,
/// compared, restored, or its card or search hit is worked out. Never
/// changes.
final class FileText {
  FileText(this.listed, this.textFile);

  /// [read] as text; `null` if its bytes are not UTF-8.
  static FileText? of(FileBytes read) => switch (TextFile.decode(read.bytes)) {
    final file? => FileText(read.listed, file),
    null => null,
  };

  /// [written] as text: bytes the app wrote as text (e.g. a moved text
  /// file); else a bug.
  static FileText ofWritten(FileBytes written) =>
      FileText(written.listed, decodeWritten(written.bytes));

  /// [bytes] the app wrote as text (e.g. a type's arrival), decoded; else
  /// a bug.
  static TextFile decodeWritten(Uint8List bytes) =>
      TextFile.decode(bytes) ??
      (throw StateError('Written as text, but not text.'));

  final ListedFile listed;
  final TextFile textFile;

  String get text => textFile.text;

  /// The file's bytes: its text in its byte style, as in its file.
  FileBytes get fileBytes => FileBytes(listed, textFile.encode(text));

  Folder get folder => listed.folder;
  RelPath get path => listed.path;
  FileTypeSupport get type => listed.type;
  FileKey get key => listed.key;
}
