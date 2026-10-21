import 'package:truce_core/truce_core.dart';

/// The first line of [document] that reads [raw], as in the file.
MarkdownLine lineAt(MarkdownDocument document, String raw) =>
    document.lines.firstWhere((line) => line.raw == raw);

/// The view of the leaf the line [raw] is in; with [caret], the caret is
/// in that line.
LeafView leafViewAt(
  MarkdownDocument document,
  String raw, {
  bool caret = false,
}) {
  final line = lineAt(document, raw);
  return LeafView.of(
    document,
    document.leafOf(line.id),
    caretLine: caret ? line.id : null,
  );
}

/// The view of the line [raw] as a plain text editor shows it.
RawLineView rawViewAt(MarkdownDocument document, String raw) =>
    RawLineView.of(document, lineAt(document, raw));

/// [caret]'s line in [document], with `|` where the caret is.
String marked(MarkdownDocument document, LineCaret caret) => document
    .lineOf(caret.line)!
    .raw
    .replaceRange(caret.offset, caret.offset, '|');
