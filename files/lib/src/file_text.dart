import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'file_card_summary.dart';
import 'listed_file.dart';

/// A file as the app last read or wrote it: the [listed] and
/// its text, in its file's byte style ([textFile]), and what lists show of it
/// ([summary]). Held only while the file is open, compared, restored,
/// or its card or search hit is worked out. Never changes.
final class FileText {
  FileText(this.listed, this.textFile);

  final ListedFile listed;
  final TextFile textFile;

  String get text => textFile.text;

  /// What cards and search show of [text], by its type; read when first
  /// asked, once for title and preview.
  late final TextSummary<Object?> summary = type.summary(
    text,
    maxLines: FileCardSummary.previewLines,
  );

  Folder get folder => listed.folder;
  RelPath get path => listed.path;
  FileTypeSupport<Object?> get type => listed.type;
  FileKey get key => listed.key;
}
