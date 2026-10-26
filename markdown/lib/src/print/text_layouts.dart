import '../doc/doc_nodes.dart';
import '../tree/blocks.dart';
import '../tree/document_style.dart';
import 'inline_layout.dart';
import 'print_style.dart';

/// The layouts of a document's texts for one print: each text laid out
/// once, in its own style, with the document's link definitions.
final class TextLayouts {
  TextLayouts({required this.definitions, required this.style});

  /// The link definitions the document holds.
  final Map<String, LinkDefinition> definitions;

  /// The style the document uses most.
  final DocumentStyle style;

  final _layouts = Expando<InlineLayout>();

  /// The layout of [node]'s text.
  InlineLayout of(TextNode node) => _layouts[node] ??= layoutOf(
    node.text,
    heading: node is HeadingNode,
    definitions: definitions,
    style: spanStyleOf(node.source, style),
  );

  /// [node] with its text as Markdown can write it: the same node if its
  /// text is so already.
  TextNode writable(TextNode node) {
    final layout = of(node);
    if (layout.text == node.text) return node;
    final written = node.withText(layout.text);
    _layouts[written] = layout;
    return written;
  }
}
