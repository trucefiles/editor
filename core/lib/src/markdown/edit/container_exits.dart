import '../document/markdown_document.dart';
import '../lines/line_id.dart';
import 'line_writer.dart';

/// Lines that edits take out of a list or a quote.
extension ContainerExits on MarkdownDocument {
  /// Line [id], taken out of the list or quote it is in, as [content]
  /// after the quote marks [outer] it stays in; see
  /// [LineWriter.outOfContainer]. The line keeps its id.
  MarkdownDocument outOfContainer(
    LineId id, {
    required String outer,
    String content = '',
  }) {
    final index = indexOf(id);
    final [...blanks, raw] = LineWriter.outOfContainer(
      outer,
      content,
      above: index == 0 ? null : leafOf(lines[index - 1].id),
    );
    return edited(
      (newLine) => [
        ...lines.take(index),
        ...blanks.map(newLine.call),
        lines[index].withRaw(raw),
        ...lines.skip(index + 1),
      ],
    );
  }
}
