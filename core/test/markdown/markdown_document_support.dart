import 'package:truce_core/truce_core.dart';

/// A shopping list with a checked item, a subitem and a text line.
const doc = '# Shopping\n- [ ] milk\n- [x] eggs\n  - [ ] large\n\nnote\n';

/// Id of the first line of [document] whose content (after its quote
/// marks, indent, marker and box) is [content].
LineId idOf(MarkdownDocument document, String content) => document.lines
    .firstWhere((line) => contentOf(document, line.id) == content)
    .id;

/// The content of line [id]: what its leaf holds of it.
String contentOf(MarkdownDocument document, LineId id) =>
    document.leafOf(id).lineOf(id).content;

/// The item whose marker is on the first line with [content].
ItemBlock itemOf(MarkdownDocument document, String content) =>
    document.outline.itemOf(idOf(document, content))!;

/// The nesting level of the line with [content]; see
/// [ItemOutline.lineDepth].
int depthOf(MarkdownDocument document, String content) =>
    document.outline.lineDepth(idOf(document, content));

/// Nesting levels of all lines, in file order.
List<int> depths(MarkdownDocument document) => [
  for (final line in document.lines) document.outline.lineDepth(line.id),
];
