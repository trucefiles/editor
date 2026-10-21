import 'package:truce_core/truce_core.dart';

import '../text_format.dart';
import 'note_nodes.dart';

/// [format] applied to the text of [view] from [start] to [end], as
/// Markdown marks: the text with the selection after it. A
/// [TextFormat.link] goes to [url]. `null` in text without inline
/// formatting (code, a table being edited), or for a heading in a list
/// item or quote.
FormattedText? formatOf(
  EditView view,
  TextFormat format,
  int start,
  int end, {
  String url = '',
}) {
  if (!view.kind.hasInlines) return null;
  final text = view.text;
  return switch (format) {
    TextFormat.bold => toggleWrap(text, start, end, '**'),
    TextFormat.italic => toggleWrap(text, start, end, '*'),
    TextFormat.link => insertLink(text, start, end, url),
    TextFormat.heading when framesOf(view).isEmpty => cycleHeading(
      text,
      start,
      end,
    ),
    TextFormat.heading => null,
  };
}
