import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';
import 'package:truce_core/src/note/tree/inlines.dart';

/// [tree]'s whole structure as text, without ids, so two readings can be
/// compared: blocks with their attributes, leaf lines with their prefix
/// parts (by the container's depth) and inline nodes with their sources.
String dumpTree(NoteTree tree) {
  final out = StringBuffer();
  final depthOf = <BlockId, int>{};
  void block(Block block, int depth) {
    final pad = '  ' * depth;
    depthOf[block.id] = depth;
    switch (block) {
      case RootBlock():
        out.writeln('${pad}root');
      case QuoteBlock(:final firstLine, :final lastLine):
        out.writeln(
          '${pad}quote ${tree.indexOf(firstLine)}-${tree.indexOf(lastLine)}',
        );
      case ListBlock(:final loose, :final numbering):
        out.writeln(
          '${pad}list ${loose ? 'loose' : 'tight'} ${numbering.name}',
        );
      case ItemBlock():
        out.writeln(
          '${pad}item ${block.marker} ${block.checked} '
          'at ${tree.indexOf(block.markerLine)} '
          'columns ${block.markerColumn}/${block.contentColumn}',
        );
      case LeafBlock():
        out.writeln('$pad${_leafHead(block)}');
        for (final line in block.lines) {
          final parts = line.prefix
              .map(
                (part) =>
                    '${depthOf[part.container]}:${part.start}-${part.end}',
              )
              .join(' ');
          out.writeln(
            '$pad  | ${tree.indexOf(line.id)} [$parts] ${line.contentStart}'
            '+${line.tabColumns} ${line.text}',
          );
        }
        for (final text in _textsOf(block)) {
          out.writeln('$pad  ${_inlineText(text)}');
        }
    }
  }

  void walk(Block node, int depth) {
    block(node, depth);
    if (node is ContainerBlock) {
      for (final child in node.children) {
        walk(child, depth + 1);
      }
    }
  }

  walk(tree.root, 0);
  out.writeln('definitions ${tree.definitions}');
  return out.toString();
}

String _leafHead(LeafBlock leaf) => switch (leaf) {
  ParagraphBlock() => 'paragraph',
  HeadingBlock(:final level, :final style) => 'heading $level ${style.name}',
  CodeBlock(:final fence, :final closed, :final info) =>
    'code ${fence ?? 'indented'} $closed "$info"',
  HtmlBlock() => 'html',
  TableBlock(:final alignments) => 'table $alignments',
  RuleBlock() => 'rule',
  DefinitionsBlock(:final definitions) => 'definitions $definitions',
  FrontMatterBlock() => 'front matter',
};

List<InlineText> _textsOf(LeafBlock leaf) => switch (leaf) {
  TextLeaf(:final text) => [text],
  TableBlock(:final rows) => [for (final row in rows) ...row],
  _ => const [],
};

String _inlineText(InlineText text) =>
    '{${_quote(text.before)} ${text.inlines.map(_inline).join(' ')} '
    '${_quote(text.after)}}';

String _inline(Inline inline) => switch (inline) {
  TextInline(:final literal, :final source) =>
    literal == source
        ? _quote(literal)
        : '${_quote(literal)}=${_quote(source)}',
  SoftBreakInline(:final source) => 'soft${_quote(source)}',
  HardBreakInline(:final source) => 'hard${_quote(source)}',
  CodeInline(:final source, :final literal) =>
    'code${_quote(source)}=${_quote(literal)}',
  HtmlInline(:final source) => 'html${_quote(source)}',
  LinkInline(:final style, :final destination, :final title) =>
    'link-${style.name}(${_quote(destination)},${_quote(title)})'
        '${_container(inline)}',
  ImageInline(:final destination, :final title) =>
    'image(${_quote(destination)},${_quote(title)})${_container(inline)}',
  EmphasisInline() => 'em${_container(inline)}',
  StrongInline() => 'strong${_container(inline)}',
  StrikeInline() => 'strike${_container(inline)}',
};

String _container(ContainerInline inline) =>
    '[${_quote(inline.open)} ${inline.children.map(_inline).join(' ')} '
    '${_quote(inline.close)}]';

String _quote(String text) =>
    '"${text.replaceAll('\\', r'\\').replaceAll('\n', r'\n').replaceAll('"', r'\"')}"';
