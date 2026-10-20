import '../document/markdown_document.dart';
import '../edit/line_writer.dart';
import '../lines/line_id.dart';
import '../lines/markdown_line.dart';
import '../tree/blocks.dart';
import 'leaf_markup.dart';
import 'markup.dart';

/// A place in a line: an offset in the line as in the file.
typedef LineCaret = ({LineId line, int offset});

/// One line of a view: the part of [line] from [start] to [end] shows.
typedef ViewLine = ({MarkdownLine line, int start, int end});

/// What one editor node shows of a document: parts of its lines, joined
/// by line breaks, with their markup. Edits on its [text] map back to
/// these lines (see `TextEdits`). Any editor can show it.
sealed class EditView {
  EditView(List<ViewLine> lines) : lines = List.unmodifiable(lines);

  final List<ViewLine> lines;

  /// The id of its first line: stable while that line stays first.
  LineId get id => lines.first.line.id;

  late final String text = lines
      .map((line) => line.line.raw.substring(line.start, line.end))
      .join('\n');

  /// Where each line's part starts in [text].
  late final List<int> _starts = lines.take(lines.length - 1).fold([
    0,
  ], (starts, line) => [...starts, starts.last + line.end - line.start + 1]);

  /// What a new line in it starts with, below a line whose part starts
  /// after [prefix]; [afterBlank] when a blank line is between them.
  String newLinePrefix(String prefix, {bool afterBlank = false});

  /// The kind of block its text reads as.
  LeafKind get kind;

  /// The markup of [shown], read as this view reads its text. [shown] may
  /// differ from [text], e.g. while the user types into it before the
  /// document has it.
  List<MarkupSpan> markupOf(String shown);

  /// Where [caret] is in [text]; `null` if it is in none of its lines.
  /// A caret in a line's prefix goes to where its part starts.
  int? offsetOf(LineCaret caret) {
    final index = lines.indexWhere((line) => line.line.id == caret.line);
    if (index < 0) return null;
    final line = lines[index];
    return _starts[index] +
        (caret.offset.clamp(line.start, line.end) - line.start);
  }

  /// The place in the file of [offset] in [text].
  LineCaret caretAt(int offset) {
    final index = _starts.lastIndexWhere((start) => start <= offset);
    final line = lines[index < 0 ? 0 : index];
    final inLine = offset - _starts[index < 0 ? 0 : index];
    return (
      line: line.line.id,
      offset: line.start + inLine.clamp(0, line.end - line.start),
    );
  }

  /// The url of the link at [offset] in [shown], by its [markupOf];
  /// `null` if there is none.
  String? linkAt(String shown, int offset) => [
    for (final span in markupOf(shown))
      if (span.markup case LinkMarkup(:final url)
          when span.start <= offset && offset < span.end)
        url,
  ].firstOrNull;
}

/// A container around a leaf, as an editor draws it.
sealed class Frame {
  const Frame();
}

/// A block quote: a bar beside its text.
final class QuoteFrame extends Frame {
  const QuoteFrame();
}

/// A list item: indented, and its marker beside its first line.
final class ItemFrame extends Frame {
  const ItemFrame({
    required this.item,
    required this.kind,
    required this.checked,
    required this.number,
    required this.showsMarker,
  });

  /// The item, by its marker line.
  final LineId item;
  final ListKind kind;
  final bool checked;

  /// The number a numbered item shows.
  final int? number;

  /// Whether the leaf starts the item, so its marker shows beside it.
  final bool showsMarker;

  @override
  bool operator ==(Object other) =>
      other is ItemFrame &&
      other.item == item &&
      other.kind == kind &&
      other.checked == checked &&
      other.number == number &&
      other.showsMarker == showsMarker;

  @override
  int get hashCode => Object.hash(item, kind, checked, number, showsMarker);
}

/// A leaf block as a structured editor shows it: its content, inside its
/// [frames], outermost first. New lines in it go on in its blocks.
final class LeafView extends EditView {
  LeafView._(
    super.lines, {
    required this.leaf,
    required this.frames,
    required this.held,
    required this._definitions,
  });

  /// How [leaf] of [document] shows. An empty item whose marker ends its
  /// line shows as text while the caret is in it ([caretLine]), so `-5`
  /// can be typed: it is [held] until a space follows the marker or the
  /// caret leaves.
  factory LeafView.of(
    MarkdownDocument document,
    LeafBlock leaf, {
    LineId? caretLine,
  }) {
    final outline = document.outline;
    final item = outline.itemOf(leaf.id);
    final first = leaf.lines.first;
    final marker = item == null ? null : outline.partsOf(item, first.line).rest;
    final held =
        leaf is BlankBlock &&
        marker != null &&
        caretLine == leaf.id &&
        !marker.endsWith(' ') &&
        !marker.endsWith('\t');
    final frames = [
      for (final block in leaf.ancestors.toList().reversed)
        if (!(held && block == item))
          ?switch (block) {
            QuoteBlock() => const QuoteFrame(),
            ItemBlock() => ItemFrame(
              item: block.markerLine,
              kind: block.kind,
              checked: block.isChecked,
              number: outline.numberOf(block),
              showsMarker: block.leaves.first == leaf,
            ),
            _ => null,
          },
    ];
    final heldStart = held ? first.line.raw.length - marker.length : null;
    return LeafView._(
      [
        for (final (index, line) in leaf.lines.indexed)
          (
            line: line.line,
            start: index == 0 && heldStart != null
                ? heldStart
                : line.contentStart,
            end: line.contentEnd,
          ),
      ],
      leaf: leaf,
      frames: frames,
      held: held,
      definitions: document.definitions,
    );
  }

  final LeafBlock leaf;
  final List<Frame> frames;

  /// Whether it is an empty item shown as text only because the caret is
  /// in it (see [LeafView.of]): it shows as an item once the caret leaves.
  final bool held;

  final Map<String, LinkDefinition> _definitions;

  @override
  LeafKind get kind => held ? LeafKind.paragraph : LeafKind.of(leaf);

  /// The innermost item it is in, by its marker line, also while [held].
  LineId? get item =>
      leaf.ancestors.whereType<ItemBlock>().firstOrNull?.markerLine;

  /// Whether it is in a block quote.
  bool get quoted => frames.any((frame) => frame is QuoteFrame);

  /// The item whose marker shows beside it, if any: the innermost one.
  ItemFrame? get markedItem =>
      switch (frames.whereType<ItemFrame>().lastOrNull) {
        final item? when item.showsMarker => item,
        _ => null,
      };

  @override
  String newLinePrefix(String prefix, {bool afterBlank = false}) =>
      LineWriter.continuation(prefix, afterBlank: afterBlank);

  @override
  List<MarkupSpan> markupOf(String shown) => [
    if (quoted && shown.isNotEmpty)
      MarkupSpan(const QuoteMarkup(), 0, shown.length),
    ...leafMarkup(shown, kind, leaf: leaf, definitions: _definitions),
  ];
}

/// One line of a document as a plain text editor shows it: every
/// character of it. New lines in it are plain lines.
final class RawLineView extends EditView {
  RawLineView._(MarkdownLine line, this._leafView)
    : super([(line: line, start: 0, end: line.raw.length)]);

  /// How [line] of [document] shows.
  factory RawLineView.of(MarkdownDocument document, MarkdownLine line) =>
      RawLineView._(line, LeafView.of(document, document.leafOf(line.id)));

  /// The view of its leaf, whose markup it shows its part of.
  final LeafView _leafView;

  @override
  String newLinePrefix(String prefix, {bool afterBlank = false}) => '';

  @override
  LeafKind get kind => _leafView.kind;

  /// Its leaf's markup on its own part, its prefix as syntax. Once the
  /// user changed its prefix, its text reads as a line of text.
  @override
  List<MarkupSpan> markupOf(String shown) {
    final line = _leafView.lines.firstWhere((line) => line.line.id == id);
    final prefix = line.line.raw.substring(0, line.start);
    if (!shown.startsWith(prefix)) {
      return leafMarkup(
        shown,
        LeafKind.paragraph,
        leaf: _leafView.leaf,
        definitions: _leafView._definitions,
      );
    }
    final start = _leafView.offsetOf((line: id, offset: line.start))!;
    final ownText = shown.substring(prefix.length);
    final leafText = _leafView.text.replaceRange(
      start,
      start + line.end - line.start,
      ownText,
    );
    final end = start + ownText.length;
    return [
      if (prefix.isNotEmpty) MarkupSpan(const SyntaxMarkup(), 0, prefix.length),
      for (final span in _leafView.markupOf(leafText))
        if (span.end > start && span.start < end)
          MarkupSpan(
            span.markup,
            prefix.length + span.start.clamp(start, end) - start,
            prefix.length + span.end.clamp(start, end) - start,
          ),
    ];
  }
}
