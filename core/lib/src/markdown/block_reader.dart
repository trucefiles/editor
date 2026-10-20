import 'markdown_line.dart';
import 'syntax/block_syntax.dart';
import 'syntax/line_kinds.dart';

/// What reading a document says of one of its lines.
final class LineRead {
  const LineRead(
    this.kind, {
    this.parent,
    this.isItem = false,
    this.inQuote = false,
    this.heading,
  }) : isBlank = false;

  const LineRead._blank()
    : kind = LineKind.plain,
      parent = null,
      isItem = false,
      inQuote = false,
      heading = null,
      isBlank = true;

  /// A blank line outside code blocks: in no block, under no item.
  static const blank = LineRead._blank();

  final LineKind kind;

  /// The index of the innermost item the line is in; `null` at the top
  /// level.
  final int? parent;

  /// Whether the line is a list item.
  final bool isItem;

  /// Whether the line shows in a quote: it has the quote's `>` marks, or
  /// it continues the paragraph of a quote without them.
  final bool inQuote;

  /// The line of a heading written as text over an underline (`Title`
  /// over `===`) the line is; `null` for any other line.
  final UnderlinedHeadingLine? heading;

  final bool isBlank;

  LineRead _asHeadingText(int level) => LineRead(
    kind,
    parent: parent,
    isItem: isItem,
    inQuote: inQuote,
    heading: (level: level, isUnderline: false),
  );
}

/// Reads [lines] as Markdown does, in one pass from the top: each line
/// first meets the open containers (list items it is indented to the
/// content of, a quote it has the `>` of), and the rest of it is read
/// inside the innermost one: code, a table, a quote, an item or text.
/// Text right below a paragraph's text continues it, also lazily, without
/// the containers' indent or `>`. The one reader of block structure.
List<LineRead> readLines(List<MarkdownLine> lines) => _Reader(lines).read();

/// An open list item: its line and the column its content starts at.
typedef _OpenItem = ({int index, int column});

/// The block the reader is in, inside the innermost container.
sealed class _Leaf {
  const _Leaf();
}

final class _NoLeaf extends _Leaf {
  const _NoLeaf();
}

/// A paragraph from line [start], the text of [of].
final class _Paragraph extends _Leaf {
  const _Paragraph(this.start, this.of);

  final int start;
  final _TextOf of;
}

/// What a paragraph is the text of.
enum _TextOf { block, item, quote }

/// A fenced code block opened with [fence].
final class _Fence extends _Leaf {
  const _Fence(this.fence);

  final String fence;
}

final class _Table extends _Leaf {
  const _Table();
}

final class _Reader {
  _Reader(this._lines);

  final List<MarkdownLine> _lines;
  final _reads = <LineRead>[];

  /// The open items, outermost first; their columns grow inwards.
  final _open = <_OpenItem>[];
  var _inQuote = false;
  _Leaf _leaf = const _NoLeaf();

  List<LineRead> read() {
    for (var index = 0; index < _lines.length; index++) {
      _reads.add(_readAt(index));
    }
    return _reads;
  }

  int? get _parent => _open.lastOrNull?.index;

  LineRead _readAt(int index) {
    final line = _lines[index];
    if (line.isBlank) return _blank(index);
    final width = columnsOf(line.indent);
    final matched = _open.takeWhile((item) => width >= item.column).length;
    final all = matched == _open.length;
    final column = matched == 0 ? 0 : _open[matched - 1].column;
    final rest = restFrom(line.raw, column);
    final quoted = quoteTextStart(rest) != null;
    if (_leaf case _Fence(:final fence) when all) return _inFence(fence, rest);
    if (all && _inQuote && quoted) return _quoteLine(index, rest);
    if (_leaf is _Paragraph && (!all || _inQuote) && _isText(rest)) {
      return LineRead(LineKind.plain, parent: _parent, inQuote: _inQuote);
    }
    _open.removeRange(matched, _open.length);
    if (!all || _inQuote) _endBlocks();
    return _blockAt(index, rest, column);
  }

  /// A blank line at [index]: code in a code block; else it ends a
  /// paragraph, table or quote, and leaves items open, except an item
  /// right above with no content yet: as in Markdown, an item starts with
  /// at most one blank line, so it ends.
  LineRead _blank(int index) {
    if (_leaf is _Fence) return LineRead(LineKind.code, parent: _parent);
    _endBlocks();
    if (_open.lastOrNull case (index: final item, column: _)
        when item == index - 1 && _lines[item].text.trim().isEmpty) {
      _open.removeLast();
    }
    return LineRead.blank;
  }

  /// Ends the quote and the paragraph, table or code block in it, if any.
  void _endBlocks() {
    _inQuote = false;
    _leaf = const _NoLeaf();
  }

  LineRead _inFence(String fence, String rest) {
    if (!closesFence(fence, rest)) {
      return LineRead(LineKind.code, parent: _parent);
    }
    _leaf = const _NoLeaf();
    return LineRead(LineKind.fence, parent: _parent);
  }

  LineRead _quoteLine(int index, String rest) {
    final text = _isText(rest.substring(quoteTextStart(rest)!));
    _leaf = switch (_leaf) {
      final _Paragraph paragraph when text => paragraph,
      _ when text => _Paragraph(index, _TextOf.quote),
      _ => const _NoLeaf(),
    };
    _inQuote = true;
    return LineRead(LineKind.plain, parent: _parent, inQuote: true);
  }

  /// The line at [index], [rest] of it from [column] on, inside the
  /// innermost open container, which starts at [column].
  LineRead _blockAt(int index, String rest, int column) {
    final line = _lines[index];
    final parent = _parent;
    if (_leaf is _Table) {
      if (isTableRow(rest) && !startsBlock(rest)) {
        return LineRead(LineKind.table, parent: parent);
      }
      _leaf = const _NoLeaf();
    }
    final paragraph = switch (_leaf) {
      final _Paragraph paragraph => paragraph,
      _ => null,
    };
    // Unlike in Markdown, a lone `-` is an empty item, not an underline,
    // so starting a list below text never turns that text into a heading.
    if (paragraph case _Paragraph(:final start, of: _TextOf.block)
        when !line.hasItemSyntax) {
      if (underlineLevel(rest) case final level?) {
        return _underline(start, index, level);
      }
    }
    if (fenceOf(rest) case final fence?) {
      _leaf = _Fence(fence);
      return LineRead(LineKind.fence, parent: parent);
    }
    if (_startsTable(index, rest, column)) {
      _leaf = const _Table();
      return LineRead(LineKind.table, parent: parent);
    }
    if (quoteTextStart(rest) != null) return _quoteLine(index, rest);
    if (line.hasItemSyntax &&
        (paragraph == null || _interrupts(paragraph, line))) {
      _open.add((index: index, column: line.contentColumn));
      _leaf = _isText(line.text)
          ? _Paragraph(index, _TextOf.item)
          : const _NoLeaf();
      return LineRead(LineKind.plain, parent: parent, isItem: true);
    }
    final text = _isText(rest);
    if (paragraph == null || !(text || line.hasItemSyntax)) {
      _leaf = text ? _Paragraph(index, _TextOf.block) : const _NoLeaf();
    }
    return LineRead(LineKind.plain, parent: parent);
  }

  /// The underline at [index] of a heading of [level] whose text is the
  /// paragraph from [start].
  LineRead _underline(int start, int index, int level) {
    for (var line = start; line < index; line++) {
      _reads[line] = _reads[line]._asHeadingText(level);
    }
    _leaf = const _NoLeaf();
    return LineRead(
      LineKind.plain,
      parent: _parent,
      heading: (level: level, isUnderline: true),
    );
  }

  /// Whether the line at [index], [rest] of it inside a container from
  /// [column], starts a table with the line below, which is in the same
  /// container. A line that starts another block (an item, a quote) does
  /// not.
  bool _startsTable(int index, String rest, int column) {
    if (index + 1 >= _lines.length) return false;
    final below = _lines[index + 1];
    return !startsBlock(rest) &&
        columnsOf(below.indent) >= column &&
        startsTable(rest, restFrom(below.raw, column));
  }

  /// Whether the item [line] starts a list right below the text of
  /// [paragraph], which it would else continue. As in Markdown, a numbered
  /// item there must start at 1; unlike it, an empty item may, and below
  /// an item's text any item may (a subitem).
  static bool _interrupts(_Paragraph paragraph, MarkdownLine line) =>
      paragraph.of == _TextOf.item ||
      line.listKind != ListKind.numbered ||
      line.number == 1;
}

/// Whether [text] is a paragraph's text: not blank, and starting no other
/// block.
bool _isText(String text) => text.trim().isNotEmpty && !startsBlock(text);
