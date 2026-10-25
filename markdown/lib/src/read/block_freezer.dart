import '../lines/line.dart';
import '../tree/blocks.dart';
import '../tree/inlines.dart';
import 'inline_reader.dart';
import 'open_blocks.dart';
import 'syntax/block_starts.dart';
import 'syntax/characters.dart';
import 'syntax/table_rows.dart';

/// The kinds of blocks, to match a block read anew with an earlier one.
enum BlockKind {
  root,
  quote,
  list,
  item,
  paragraph,
  heading,
  code,
  html,
  table,
  rule,
  definitions,
  frontMatter;

  static BlockKind of(Block block) => switch (block) {
    RootBlock() => root,
    QuoteBlock() => quote,
    ListBlock() => list,
    ItemBlock() => item,
    ParagraphBlock() => paragraph,
    HeadingBlock() => heading,
    CodeBlock() => code,
    HtmlBlock() => html,
    TableBlock() => table,
    RuleBlock() => rule,
    DefinitionsBlock() => definitions,
    FrontMatterBlock() => frontMatter,
  };
}

/// Gives a block read anew its id, from its kind and first line.
typedef NewBlockId = BlockId Function(BlockKind kind, LineId firstLine);

/// The blocks of a reading: [root] and the blocks in it as immutable
/// blocks. Kept blocks stay as they are; containers continued from an
/// earlier reading keep their ids; other blocks get theirs from [newId].
/// Text is read with [definitions]. [lineIndex] gives kept lines'
/// indexes.
RootBlock freezeBlocks(
  OpenRoot root,
  List<Line> lines, {
  required NewBlockId newId,
  required Map<String, LinkDefinition> definitions,
  required int Function(LineId id) lineIndex,
}) =>
    _Freezer(lines, newId, definitions, lineIndex).container(root) as RootBlock;

/// The link definitions of the paragraphs read in [root], in file order.
List<LinkDefinition> definitionsRead(OpenRoot root) => [
  for (final child in root.children) ..._definitionsIn(child),
];

Iterable<LinkDefinition> _definitionsIn(ReadChild child) => switch (child) {
  OpenContainer(:final children) => children.expand(_definitionsIn),
  OpenParagraph(:final definitions) => definitions,
  _ => const [],
};

final class _Freezer {
  _Freezer(this._lines, this._newId, this._definitions, this._lineIndex);

  final List<Line> _lines;
  final NewBlockId _newId;
  final Map<String, LinkDefinition> _definitions;
  final int Function(LineId id) _lineIndex;
  final _ids = <OpenContainer, BlockId>{};

  BlockId _idOf(OpenContainer open) => _ids[open] ??=
      open.keptId ??
      _newId(switch (open) {
        OpenRoot() => BlockKind.root,
        OpenQuote() => BlockKind.quote,
        OpenList() => BlockKind.list,
        OpenItem() => BlockKind.item,
      }, _lines[_firstLineOf(open)].id);

  ContainerBlock container(OpenContainer open) {
    final id = _idOf(open);
    final children = [for (final child in open.children) ..._blocks(child)];
    return switch (open) {
      OpenRoot() => RootBlock(id, children),
      OpenQuote() => QuoteBlock(
        id,
        children,
        firstLine: _lines[open.firstLine].id,
        lastLine: _lines[open.lastLine].id,
      ),
      OpenList() => ListBlock(
        id,
        children.cast<ItemBlock>(),
        loose: _isLoose(open),
      ),
      OpenItem() => ItemBlock(
        id,
        children,
        markerLine: _lines[open.firstLine].id,
        marker: open.marker,
        checked: open.checked,
        markerColumn: open.markerOffset,
        contentColumn: open.contentColumn,
      ),
    };
  }

  List<Block> _blocks(ReadChild child) => switch (child) {
    KeptChild(:final block) => [block],
    OpenContainer() => [container(child)],
    OpenParagraph() => _paragraph(child),
    OpenHeading() => [_heading(child)],
    OpenCode() => [_code(child)],
    OpenHtml() => [
      HtmlBlock(_leafId(BlockKind.html, child), _sourceLines(child.lines)),
    ],
    OpenTable() => [_table(child)],
    OpenRule() => [
      RuleBlock(_leafId(BlockKind.rule, child), _sourceLines(child.lines)),
    ],
    OpenFrontMatter() => [
      FrontMatterBlock(
        _leafId(BlockKind.frontMatter, child),
        _sourceLines(child.lines),
      ),
    ],
  };

  BlockId _leafId(BlockKind kind, OpenLeaf leaf, [int from = 0]) =>
      _newId(kind, _lines[leaf.lines[from].index].id);

  List<Block> _paragraph(OpenParagraph paragraph) {
    final lines = _sourceLines(paragraph.lines);
    final split = paragraph.definitionLines.clamp(0, lines.length);
    final textLines = lines.sublist(split);
    return [
      if (split > 0)
        DefinitionsBlock(
          _leafId(BlockKind.definitions, paragraph),
          lines.sublist(0, split),
          paragraph.definitions,
        ),
      if (textLines.isNotEmpty)
        ParagraphBlock(
          _leafId(BlockKind.paragraph, paragraph, split),
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
      _leafId(BlockKind.heading, heading),
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
      _leafId(BlockKind.code, code),
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
      _leafId(BlockKind.table, table),
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
        _lines[line.index].id,
        _lines[line.index].text,
        prefix: [
          for (final segment in line.prefix)
            (
              container: _idOf(segment.container),
              start: segment.start,
              end: segment.end,
            ),
        ],
        contentStart: line.contentStart.clamp(
          0,
          _lines[line.index].text.length,
        ),
        tabColumns: line.tabColumns,
      ),
  ];

  /// Whether blank lines separate [list]'s items or the blocks in them.
  bool _isLoose(OpenList list) {
    final items = list.children;
    bool gapBetween(List<ReadChild> children) => [
      for (var index = 0; index + 1 < children.length; index++)
        _lastLineOf(children[index]) < _firstLineOf(children[index + 1]) - 1,
    ].any((gap) => gap);
    return gapBetween(items) ||
        items.any((item) => gapBetween(_childrenOf(item)));
  }

  static List<ReadChild> _childrenOf(ReadChild item) => switch (item) {
    OpenContainer(:final children) => children,
    KeptChild(block: ContainerBlock(:final children)) => [
      for (final child in children) KeptChild(child),
    ],
    _ => const [],
  };

  int _firstLineOf(ReadChild child) => switch (child) {
    KeptChild(:final block) => _lineIndex(lineSpanOf(block).first),
    OpenBlock(:final firstLine) => firstLine,
  };

  int _lastLineOf(ReadChild child) => switch (child) {
    KeptChild(:final block) => _lineIndex(lineSpanOf(block).last),
    OpenQuote(:final lastLine) => lastLine,
    OpenContainer(:final firstLine, :final children) when children.isNotEmpty =>
      _lastLineOf(children.last) < firstLine
          ? firstLine
          : _lastLineOf(children.last),
    OpenContainer(:final firstLine) => firstLine,
    OpenLeaf(:final lines) => lines.last.index,
  };
}
