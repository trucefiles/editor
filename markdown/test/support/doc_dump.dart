import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/tree/inlines.dart';
import 'package:truce_markdown/src/visible/formatting.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

/// [root]'s content as text, without ids or sources, so two document
/// trees can be compared: blocks with their attributes, texts as runs
/// of characters with their formats and links. A soft break counts as a
/// space. Empty paragraphs, which print nothing, are left out.
String dumpDoc(DocBlock root) {
  final out = StringBuffer();
  void block(DocBlock node, int depth) {
    final pad = '  ' * depth;
    out.writeln('$pad${_head(node)}');
    if (node is DocContainer) {
      for (final child in node.children) {
        if (child is ParagraphNode && child.text.isEmpty) continue;
        block(child, depth + 1);
      }
    }
  }

  block(root, 0);
  return out.toString();
}

String _head(DocBlock node) => switch (node) {
  DocRoot() => 'root',
  QuoteNode() => 'quote',
  ListNode(kind: ListKind.bullet) => 'list bullet',
  ListNode(:final start, :final numbering, :final items) =>
    'list numbered $start'
        '${items.length > 1 ? ' ${numbering.name}' : ''}',
  ItemNode(:final checked) => 'item${checked == null ? '' : ' [$checked]'}',
  ParagraphNode(:final text) => 'paragraph ${dumpText(text)}',
  HeadingNode(:final level, :final text) => 'heading $level ${dumpText(text)}',
  CodeNode(:final info, :final code) => 'code "$info" ${_quoted(code)}',
  DividerNode() => 'divider',
  TableNode(:final raw) => 'table ${_quoted(raw)}',
  RawNode(:final kind, :final raw) => '${kind.name} ${_quoted(raw)}',
};

/// [text] as runs of characters of one look: a soft break as a space, a
/// hard break as `⏎`.
String dumpText(VisibleText text) {
  final runs = <(String, String)>[];
  for (final piece in text.pieces) {
    final (shown, look) = switch (piece) {
      TextPiece(:final text) => (text, _look(piece.formatting)),
      SoftBreakPiece() => (' ', _look(piece.formatting)),
      HardBreakPiece() => ('⏎', _look(piece.formatting)),
      ObjectPiece(inline: final ImageInline image) => (
        '[image ${image.destination}|${image.title}|'
            '${plainTextOf(image.children)}]',
        _look(piece.formatting),
      ),
      ObjectPiece(:final inline) => (
        '[${inOneLine(inline).source}]',
        _look(piece.formatting),
      ),
    };
    if (runs.isNotEmpty && runs.last.$2 == look) {
      runs.last = (runs.last.$1 + shown, look);
    } else {
      runs.add((shown, look));
    }
  }
  return runs.map((run) => '${_quoted(run.$1)}${run.$2}').join(' ');
}

String _look(Formatting formatting) {
  final formats =
      (formatting.formats.map((format) => format.name).toList()..sort()).join(
        ',',
      );
  final link = switch (formatting.link) {
    final LinkMark link => '<${link.destination}|${link.title}>',
    null => '',
  };
  return '${formats.isEmpty ? '' : '{$formats}'}$link';
}

String _quoted(String text) =>
    '"${text.replaceAll('\\', r'\\').replaceAll('\n', r'\n').replaceAll('"', r'\"')}"';
