import 'file_type.dart';

/// What the app knows of one document type: its files, by extension, and
/// what lists show of a text of it. [Options] say how a preview shows,
/// the type's own way (e.g. whether checked items show).
abstract interface class FileTypeSupport<Options> {
  FileType get type;

  /// The extensions of its files, lower case, without the dot (`md`).
  Set<String> get extensions;

  /// What lists show of [text], with previews of up to [maxLines] lines.
  TextSummary<Options> summary(String text, {required int maxLines});
}

/// What lists show of one text: its title, and a preview of its first
/// lines as plain words. Each part is worked out when first asked.
abstract interface class TextSummary<Options> {
  /// The text's own title; `null` if it has none (the file name is used).
  String? get title;

  /// The first line with words, as plain words; empty if there is none.
  /// Names new documents.
  String get firstLine;

  /// The lines after the title, shown as [options] say.
  String preview(Options options);
}
