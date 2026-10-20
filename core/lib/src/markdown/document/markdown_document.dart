import 'package:collection/collection.dart';

import '../lines/line_id.dart';
import '../lines/markdown_line.dart';
import '../tree/block_reader.dart';
import '../tree/blocks.dart';
import '../tree/characters.dart';
import '../edit/line_writer.dart';
import 'item_outline.dart';

/// A Markdown document: its lines as in the file, and the block tree
/// read from them once.
///
/// Lines are the storage: every edit changes lines, and lines it does
/// not touch stay byte-identical. Every line has an id that survives
/// edits, so an editor can follow it while its text changes; ids are
/// unique only among the documents derived from one
/// [MarkdownDocument.parse]. Immutable: each edit returns a new
/// document, read anew.
final class MarkdownDocument {
  MarkdownDocument._(this.lines, this._nextId, [this._writer]);

  /// [text] with `\n` line breaks.
  factory MarkdownDocument.parse(String text) {
    final lines = _linesOf(text.split('\n'), firstId: 0);
    return MarkdownDocument._(lines, lines.length);
  }

  /// [text] as a new version of this document, e.g. after it changed
  /// elsewhere. The unchanged lines at its start and end keep their ids,
  /// so an editor keeps its place there; all other lines get ids this
  /// document never used, so an editor cannot mistake a new line for an
  /// old one.
  MarkdownDocument reparse(String text) {
    final raws = text.split('\n');
    final olds = [for (final line in lines) line.raw];
    final head = _sameAtStart(raws, olds);
    final tail = _sameAtStart(
      raws.skip(head).toList().reversed,
      olds.skip(head).toList().reversed,
    );
    final changed = _linesOf(
      raws.sublist(head, raws.length - tail),
      firstId: _nextId,
    );
    return MarkdownDocument._([
      ...lines.take(head),
      ...changed,
      ...lines.skip(lines.length - tail),
    ], _nextId + changed.length);
  }

  /// All lines, in file order.
  final List<MarkdownLine> lines;

  final int _nextId;

  /// The writer of the document this one was edited from, if any.
  final LineWriter? _writer;

  /// Writes lines where edits put them, in the style of the file as it
  /// was read: edits keep it.
  late final LineWriter writer = _writer ?? LineWriter.of(outline);

  String get text => lines.map((line) => line.raw).join('\n');

  /// The block tree.
  late final RootBlock root = readBlocks(lines);

  /// Every leaf, in file order: each line is in exactly one.
  List<LeafBlock> get leaves => root.leaves;

  /// The link reference definitions, by normalized label; the first of
  /// a label counts.
  late final Map<String, LinkDefinition> definitions = {
    for (final block in leaves.whereType<DefinitionsBlock>().toList().reversed)
      for (final definition in block.definitions.reversed)
        normalizeLabel(definition.label): definition,
  };

  /// The list items and where items go.
  late final ItemOutline outline = ItemOutline(this);

  late final Map<LineId, int> _indexById = {
    for (final (index, line) in lines.indexed) line.id: index,
  };

  late final Map<LineId, LeafBlock> _leafByLine = {
    for (final leaf in leaves)
      for (final line in leaf.lines) line.id: leaf,
  };

  late final Map<LineId, LeafBlock> _leafById = {
    for (final leaf in leaves) leaf.id: leaf,
  };

  /// The line [id]; `null` if there is none.
  MarkdownLine? lineOf(LineId id) => switch (_indexById[id]) {
    final index? => lines[index],
    null => null,
  };

  /// The index of line [id]. Only for a line of this document.
  int indexOf(LineId id) =>
      _indexById[id] ?? (throw ArgumentError.value(id, 'id', 'no such line'));

  /// The leaf line [id] is in. Only for a line of this document.
  LeafBlock leafOf(LineId id) =>
      _leafByLine[id] ?? (throw ArgumentError.value(id, 'id', 'no such line'));

  /// The leaf whose first line is [id]; `null` if there is none.
  LeafBlock? leafById(LineId id) => _leafById[id];

  /// Whether the document has checkbox items.
  bool get hasCheckboxes => outline.items.any((item) => item.checked != null);

  /// The document with the lines [build] returns, in its writer's style.
  /// Lines [build] makes with the [NewLine] it gets have ids this
  /// document never handed out.
  MarkdownDocument edited(
    List<MarkdownLine> Function(NewLine newLine) build,
  ) {
    final newLine = NewLine._(_nextId);
    final built = build(newLine);
    return MarkdownDocument._(List.unmodifiable(built), newLine._next, writer);
  }

  /// The document with [lines] instead: these lines, moved or changed.
  MarkdownDocument withLines(List<MarkdownLine> lines) => edited((_) => lines);

  /// Lines of [raws], with ids counting up from [firstId].
  static List<MarkdownLine> _linesOf(
    List<String> raws, {
    required int firstId,
  }) => List.unmodifiable([
    for (final (offset, raw) in raws.indexed)
      MarkdownLine(LineId(firstId + offset), raw),
  ]);
}

/// Makes new lines for [MarkdownDocument.edited], each with an id of its
/// own.
final class NewLine {
  NewLine._(this._next);

  int _next;

  /// A new line with [raw].
  MarkdownLine call(String raw) => MarkdownLine(LineId(_next++), raw);
}

/// How many items [a] and [b] have equal at their start.
int _sameAtStart(Iterable<String> a, Iterable<String> b) =>
    IterableZip([a, b]).takeWhile((pair) => pair[0] == pair[1]).length;
