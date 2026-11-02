import '../tree/blocks.dart';
import '../tree/inlines.dart';
import 'inline_reader.dart';
import 'open_blocks.dart';
import 'syntax/block_starts.dart';
import 'syntax/characters.dart';
import 'syntax/table_rows.dart';

/// The blocks of a reading: [root] and the blocks in it as immutable
/// blocks, read from [lines], each with an id of its own. Text is read
/// with [definitions].
RootBlock freezeBlocks(
  OpenRoot root,
  List<String> lines, {
  required Map<String, LinkDefinition> definitions,
}) => _Freezer(lines, definitions).container(root) as RootBlock;

/// The link definitions of the paragraphs read in [root], in file order.
List<LinkDefinition> definitionsRead(OpenRoot root) => [
  for (final child in root.children) ..._definitionsIn(child),
];

Iterable<LinkDefinition> _definitionsIn(OpenBlock child) => switch (child) {
  OpenContainer(:final children) => children.expand(_definitionsIn),
  OpenParagraph(:final definitions) => definitions,
  _ => const [],
};

final class _Freezer {
  _Freezer(this._lines, this._definitions);

  final List<String> _lines;
  final Map<String, LinkDefinition> _definitions;
  var _nextId = 0;
  final _ids = <OpenContainer, BlockId>{};

  BlockId _newId() => BlockId(_nextId++);

  BlockId _idOf(OpenContainer open) => _ids[open] ??= _newId();

  ContainerBlock container(OpenContainer open) {
    final id = _idOf(open);
    final children = [for (final child in open.children) ..._blocks(child)];
    return switch (open) {
      OpenRoot() => RootBlock(id, children),
      OpenQuote() => QuoteBlock(
        id,
        children,
        firstLine: open.firstLine,
        lastLine: open.lastLine,
      ),
      OpenList() => ListBlock(
        id,
        children.cast<ItemBlock>(),
        loose: _isLoose(open),
      ),
      OpenItem() => ItemBlock(
        id,
        children,
        markerLine: open.firstLine,
        marker: open.marker,
        checked: open.checked,
        markerColumn: open.markerOffset,
        contentColumn: open.contentColumn,
      ),
    };
  }

  List<Block> _blocks(OpenBlock child) => switch (child) {
    OpenContainer() => [container(child)],
    OpenParagraph() => _paragraph(child),
    OpenHeading() => [_heading(child)],
    OpenCode() => [_code(child)],
    OpenHtml() => [HtmlBlock(_newId(), _sourceLines(child.lines))],
    OpenTable() => [_table(child)],
    OpenRule() => [RuleBlock(_newId(), _sourceLines(child.lines))],
    OpenFrontMatter() => [
      FrontMatterBlock(_newId(), _sourceLines(child.lines)),
    ],
  };

  List<Block> _paragraph(OpenParagraph paragraph) {
    final lines = _sourceLines(paragraph.lines);
    final split = paragraph.definitionLines.clamp(0, lines.length);
    final textLines = lines.sublist(split);
    return [
      if (split > 0)
        DefinitionsBlock(
          _newId(),
          lines.sublist(0, split),
          paragraph.definitions,
        ),
      if (textLines.isNotEmpty)
        ParagraphBlock(
          _newId(),
          textLines,
          readInlineText(_contentOf(textLines), definitions: _definitions),
        ),
    ];
  }

  HeadingBlock _heading(OpenHeading heading) {
    final lines = _sourceLines(heading.lines);
    final content = _contentOf(lines);
    final (start, end) = switch (heading.style) {
      HeadingStyle.setext => (0, content.lastIndexOf('\n')),
      HeadingStyle.atx => _atxText(content),
    };
    return HeadingBlock(
      _newId(),
      lines,
      readInlineText(
        content,
        start: start,
        end: end,
        definitions: _definitions,
      ),
      level: heading.level,
      style: heading.style,
    );
  }

  /// Where an ATX heading's text starts and ends in [content]: after its
  /// `#` marks, before a closing run of `#`.
  static (int, int) _atxText(String content) {
    final open = atxHeading.matchAsPrefix(content)!.end;
    final rest = content.substring(open);
    final closing = _closingMarks.firstMatch(rest);
    final end = open + (closing == null ? rest.length : closing.start);
    return (open, end < open ? open : end);
  }

  static final _closingMarks = RegExp(r'(?:^|[ \t]+)#+[ \t]*$');

  CodeBlock _code(OpenCode code) {
    final lines = _sourceLines(code.lines);
    final fence = code.fence;
    return CodeBlock(
      _newId(),
      lines,
      fence: fence,
      closed: code.closed,
      info: fence == null
          ? ''
          : unescapeText(lines.first.content.substring(fence.length).trim()),
    );
  }

  TableBlock _table(OpenTable table) {
    final lines = _sourceLines(table.lines);
    final width = table.alignments.length;
    List<InlineText> cellsOf(String row) {
      final cells = splitTableRow(row);
      return [
        for (var column = 0; column < width; column++)
          column < cells.length
              ? readInlineText(
                  cells[column].text,
                  definitions: _definitions,
                  tableCell: true,
                )
              : InlineText.empty,
      ];
    }

    return TableBlock(
      _newId(),
      lines,
      alignments: table.alignments,
      rows: [
        for (final (index, line) in lines.indexed)
          if (index != 1) cellsOf(line.content),
      ],
    );
  }

  static String _contentOf(List<SourceLine> lines) =>
      lines.map((line) => line.content).join('\n');

  List<SourceLine> _sourceLines(List<ReadLine> lines) => [
    for (final line in lines)
      SourceLine(
        line.index,
        _lines[line.index],
        prefix: [
          for (final segment in line.prefix)
            (
              container: _idOf(segment.container),
              start: segment.start,
              end: segment.end,
            ),
        ],
        contentStart: line.contentStart.clamp(0, _lines[line.index].length),
        tabColumns: line.tabColumns,
      ),
  ];

  /// Whether blank lines separate [list]'s items or the blocks in them.
  bool _isLoose(OpenList list) {
    final items = list.children;
    bool gapBetween(List<OpenBlock> children) => [
      for (var index = 0; index + 1 < children.length; index++)
        _lastLineOf(children[index]) < children[index + 1].firstLine - 1,
    ].any((gap) => gap);
    return gapBetween(items) ||
        items.any((item) => gapBetween(_childrenOf(item)));
  }

  static List<OpenBlock> _childrenOf(OpenBlock item) => switch (item) {
    OpenContainer(:final children) => children,
    _ => const [],
  };

  static int _lastLineOf(OpenBlock child) => switch (child) {
    OpenQuote(:final lastLine) => lastLine,
    OpenContainer(:final firstLine, :final children) when children.isNotEmpty =>
      _lastLineOf(children.last) < firstLine
          ? firstLine
          : _lastLineOf(children.last),
    OpenContainer(:final firstLine) => firstLine,
    OpenLeaf(:final lines) => lines.last.index,
  };
}
