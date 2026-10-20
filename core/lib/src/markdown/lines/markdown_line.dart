import 'line_id.dart';

/// One line of a document: its text as in the file, without its line
/// break, under an id that survives edits. What the line is (an item, a
/// heading) is the document tree's to say.
final class MarkdownLine {
  const MarkdownLine(this.id, this.raw);

  final LineId id;

  /// The line as in the file, without its line break.
  final String raw;

  /// Whether the line is empty or only spaces and tabs.
  bool get isBlank => raw.trim().isEmpty;

  /// The line with [raw] as its text, under the same id.
  MarkdownLine withRaw(String raw) => MarkdownLine(id, raw);

  @override
  String toString() => 'MarkdownLine($id, $raw)';
}
