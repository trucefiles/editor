import 'package:collection/collection.dart';

import '../document/item_outline.dart';
import '../document/markdown_document.dart';
import '../lines/line_id.dart';
import '../lines/markdown_line.dart';
import '../tree/blocks.dart';
import 'item_edits.dart';

extension ListConversion on MarkdownDocument {
  /// Turns the lines [ids] into items of [kind], as a list button in a
  /// text editor does: lines of text become items in no item, items of
  /// another kind keep their level and text. If all of them are items of
  /// [kind] already, they become text again. Only items and lines of text
  /// change; headings, code, tables and the like stay as they are. Blank
  /// lines among others stay blank, so tapping the button again turns a
  /// list with gaps back into text; a blank line alone becomes an empty
  /// item.
  ///
  /// With no line to change, it adds an empty item of [kind]: below the
  /// last of [ids] if that is a heading or rule, else at the end, keeping
  /// a final line break. Returns the new document and that added item's
  /// line, if any.
  (MarkdownDocument, LineId?) toList(List<LineId> ids, ListKind kind) {
    final converting = [
      for (final id in ids)
        if (lineOf(id) case final line? when _converts(line)) line,
    ];
    final filled = converting.where((line) => !line.isBlank).toList();
    final chosen = filled.isEmpty ? converting : filled;
    if (chosen.isEmpty) {
      final below = ids.isEmpty ? null : lineOf(ids.last);
      return below != null && _addsBelow(below)
          ? _addBelow(below, kind)
          : _addAtEnd(kind);
    }
    final back = chosen.every(
      (line) => outline.itemOf(line.id)?.kind == kind,
    );
    return (
      chosen.fold(
        this,
        (document, line) => back
            ? document._toText(line.id)
            : document._toItem(line.id, kind),
      ),
      null,
    );
  }

  /// Whether [line] is an item or a line of text.
  bool _converts(MarkdownLine line) =>
      outline.itemOf(line.id) != null ||
      switch (leafOf(line.id)) {
        ParagraphBlock() || BlankBlock() => true,
        _ => false,
      };

  bool _addsBelow(MarkdownLine line) => switch (leafOf(line.id)) {
    HeadingBlock() || RuleBlock() => true,
    _ => false,
  };

  /// Line [id], an item, as a line of text: its content after the quote
  /// marks it is in.
  MarkdownDocument _toText(LineId id) {
    final item = outline.itemOf(id)!;
    final line = lineOf(id)!;
    final parts = outline.partsOf(item, line);
    return withLines(
      [...lines]..[indexOf(id)] = line.withRaw(
        '${parts.outer}${_contentOf(line)}',
      ),
    );
  }

  /// Line [id] as an item of [kind]: an item keeps its place and text,
  /// with the lines in it moved as far as its content moves; a line of
  /// text becomes an item in no item there.
  MarkdownDocument _toItem(LineId id, ListKind kind) {
    final line = lineOf(id)!;
    final content = _contentOf(line);
    final item = outline.itemOf(id);
    if (item == null) {
      final index = indexOf(id);
      final place = switch (outline.placeAt(index, 0)) {
        AtMargin() => AtMargin(outline.marginOuterOf(line)),
        final place => place,
      };
      final style = ItemStyle.of(
        kind,
        bullet: _bulletNear(index) ?? '-',
      );
      final raw = '${writer.itemPrefix(outline, place)}${style.marker}$content';
      return withLines([...lines]..[index] = line.withRaw(raw));
    }
    if (item.kind == kind) return this;
    final parts = outline.partsOf(item, line);
    final style = ItemStyle.of(
      kind,
      bullet: item.marker.bullet ?? '-',
      number: outline.numberOf(item) ?? 1,
      delimiter: item.marker.delimiter ?? '.',
    );
    final changed = withLines(
      [...lines]..[indexOf(id)] = line.withRaw(
        '${parts.outer}${parts.indent}${style.marker}$content',
      ),
    );
    final now = changed.outline.itemOf(id);
    if (now == null) return changed;
    final shift =
        changed.outline.paddingOf(now) - outline.paddingOf(item);
    final (:start, :end) = outline.subtree(item);
    final shifted = writer.shifted(
      outline,
      item,
      lines.sublist(start, end),
      shift,
    );
    return changed.withLines([
      ...changed.lines.take(start + 1),
      for (final (offset, raw) in shifted.skip(1).indexed)
        changed.lines[start + 1 + offset].withRaw(raw),
      ...changed.lines.skip(end),
    ]);
  }

  /// The bullet character of the last item above the line at [index].
  String? _bulletNear(int index) => lines
      .take(index)
      .map((line) => outline.itemOf(line.id))
      .nonNulls
      .lastOrNull
      ?.marker
      .bullet;

  /// What [line] holds after its prefix: an item's text after its marker
  /// and box, a line of text without its quote marks and indent.
  String _contentOf(MarkdownLine line) {
    final leafLine = leafOf(line.id).lineOf(line.id);
    return line.raw.substring(leafLine.contentStart, leafLine.contentEnd);
  }

  /// An empty item of [kind] on a new line below [line].
  (MarkdownDocument, LineId) _addBelow(MarkdownLine line, ListKind kind) {
    final at = indexOf(line.id) + 1;
    return insertItem(
      at,
      ItemStyle.of(kind, bullet: _bulletNear(at) ?? '-'),
      place: switch (outline.placeAt(at, 0)) {
        AtMargin() => AtMargin(outline.marginOuterOf(line)),
        final place => place,
      },
    );
  }

  /// An empty item of [kind] at the end: on the last line if it is the
  /// only one and blank, else on a new line, before a final line break.
  (MarkdownDocument, LineId) _addAtEnd(ListKind kind) {
    final style = ItemStyle.of(kind);
    if (text.isEmpty) {
      final only = lines.single;
      return (withLines([only.withRaw(style.marker)]), only.id);
    }
    final at = textEnd;
    return insertItem(at, style, place: outline.placeAt(at, 0));
  }
}
