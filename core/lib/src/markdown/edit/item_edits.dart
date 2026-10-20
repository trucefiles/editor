import 'dart:math';

import 'package:collection/collection.dart';

import '../document/item_outline.dart';
import '../document/markdown_document.dart';
import '../lines/line_id.dart';
import '../lines/markdown_line.dart';
import '../tree/block_starts.dart';
import '../tree/blocks.dart';

/// Edits on a document's list items. Lines other than the items moved
/// stay byte-identical and in place.
extension ItemEdits on MarkdownDocument {
  /// The checkbox item [id] with its box checked if it was not, else
  /// unchecked.
  MarkdownDocument toggle(LineId id) {
    final item = outline.itemOf(id)!;
    assert(item.checked != null, 'only a checkbox toggles');
    final line = lineOf(id)!;
    final mark = boxMarkIndex(outline, item);
    return _replaced(
      id,
      line.withRaw(
        line.raw.replaceRange(mark, mark + 1, item.isChecked ? ' ' : 'x'),
      ),
    );
  }

  /// Toggles the checkbox [id] and, in no item, moves it with its
  /// subitems within its own list: once checked, below the list's last
  /// item; once unchecked, below its last open item, or above its first
  /// item if none is open. Open items are every item but checked
  /// checkboxes. A subitem toggles in place, under its item. Then every
  /// other checked item in no item moves below too (see [sortChecked]),
  /// e.g. ones another editor left among the open items. Lines other
  /// than items stay in place, and an item with only such lines between
  /// it and its place does not move.
  MarkdownDocument toggleAndSort(LineId id) => toggle(id).sortToggled(id);

  /// Moves the item [id], just toggled, as [toggleAndSort] does.
  MarkdownDocument sortToggled(LineId id) => _sorted(id).sortChecked();

  /// Moves every checked item in no item, with its subitems, below the
  /// last item of its list, keeping their order; as [toggleAndSort] does
  /// for one.
  MarkdownDocument sortChecked() => [
    for (final item in outline.items)
      if (item.isChecked && outline.depthOf(item) == 0) item.markerLine,
  ].fold(this, (document, id) => document._sorted(id));

  /// The item [id] moved to where [toggleAndSort] puts it.
  MarkdownDocument _sorted(LineId id) {
    final item = outline.itemOf(id);
    if (item == null || outline.depthOf(item) != 0) return this;
    final others = [...outline.listOf(item)]..remove(item);
    if (others.isEmpty) return this;
    final open = others.where((other) => !other.isChecked);
    final target = item.isChecked
        ? _endOf(others.last)
        : (open.isEmpty ? indexOf(others.first.markerLine) : _endOf(open.last));
    final index = indexOf(id);
    final end = _endOf(item);
    final between = target < index
        ? (start: target, end: index)
        : (start: end, end: max(end, target));
    final passesItem = lines
        .sublist(between.start, between.end)
        .any((line) => outline.itemOf(line.id) != null);
    if (!passesItem) return this;
    return move(id, beforeId: target < lines.length ? lines[target].id : null);
  }

  /// Adds an empty item of [kind] next to the item [anchor]: just before
  /// it, at its level, so the items below never become its subitems; else
  /// after the item in no item it is in (or it itself) with its subitems,
  /// so it never takes subitems of another. It is written in the style of
  /// the item it lands beside, so it stays in that item's list. Returns
  /// the new document and the new line's id.
  (MarkdownDocument, LineId) addItem(
    ListKind kind, {
    required LineId anchor,
    required bool before,
  }) {
    final item = outline.itemOf(anchor)!;
    final beside = before ? item : outline.marginItemOf(item);
    final at = before ? indexOf(anchor) : _endOf(beside);
    return insertItem(
      at,
      ItemStyle.after(outline, beside, kind),
      place: BesideItem(beside, outline.depthOf(beside)),
    );
  }

  /// Adds an item at index [at], written at [place] with [style] and
  /// [text]. Returns the new document and the new line's id.
  (MarkdownDocument, LineId) insertItem(
    int at,
    ItemStyle style, {
    required LinePlace place,
    String text = '',
  }) {
    late final LineId id;
    final prefix = writer.itemPrefix(outline, place);
    final document = edited((newLine) {
      final line = newLine('$prefix${style.marker}$text');
      id = line.id;
      return [...lines]..insert(at, line);
    });
    return (document, id);
  }

  /// Removes the item [id] with its subitems.
  MarkdownDocument remove(LineId id) {
    final (:start, :end) = outline.subtree(outline.itemOf(id)!);
    return withLines([...lines]..removeRange(start, end));
  }

  /// Removes all checked items, with their subitems.
  MarkdownDocument clearDone() {
    final done = outline.doneIds;
    return withLines(lines.where((line) => !done.contains(line.id)).toList());
  }

  /// Moves the item [id] with its subitems to just before the line
  /// [beforeId], or to the end if [beforeId] is `null`. Levels are kept.
  MarkdownDocument move(LineId id, {required LineId? beforeId}) =>
      _moveSubtree(
        id,
        spot: (rest, moved) => beforeId == null
            ? rest.textEnd
            : _indexWithout(moved, indexOf(beforeId)),
      );

  /// Moves the item [id] with its subitems next to the line [target], as
  /// dropping it there: just above it, else [below] it. Below an item with
  /// subitems, it goes right under the item, before them.
  ///
  /// It takes the level of the spot it lands on: the target's, or below
  /// an item with subitems, theirs; so it never becomes the parent of the
  /// items below it. Its subitems keep their levels under it.
  MarkdownDocument moveNextTo(
    LineId id, {
    required LineId target,
    required bool below,
  }) {
    if (outline.itemOf(id) == null) return this;
    final at = indexOf(target);
    return _moveSubtree(
      id,
      spot: (rest, moved) => switch (_indexWithout(moved, at)) {
        final index? => _spotNextTo(rest, index, below),
        null => null,
      },
      level: _levelNextTo(at, below),
    );
  }

  /// The level of the spot next to the line at [index]: its own, or
  /// [below] an item with subitems, theirs.
  int _levelNextTo(int index, bool below) {
    final line = lines[index];
    final item = outline.itemOf(line.id);
    final next = index + 1 < lines.length ? lines[index + 1] : null;
    if (below && item != null && next != null && index + 1 < _endOf(item)) {
      if (outline.itemOf(next.id) case final child?) {
        return outline.depthOf(child);
      }
    }
    return outline.lineDepth(line.id);
  }

  /// Where in [rest] an item dropped on the line at [target] goes: before
  /// it, or [below] it: before its first subitem, else after its block,
  /// before a final line break.
  int _spotNextTo(MarkdownDocument rest, int target, bool below) {
    if (!below) return target;
    final line = rest.lines[target];
    final item = rest.outline.itemOf(line.id);
    final end = item == null ? target + 1 : rest._endOf(item);
    if (target + 1 < end &&
        rest.outline.itemOf(rest.lines[target + 1].id) != null) {
      return target + 1;
    }
    return end == rest.lines.length ? rest.textEnd : end;
  }

  /// Moves the item [id] with its subitems one level right, under the
  /// item shown above it: the one the line shown above starts or is in. Lines in [hidden] (e.g. done items an editor
  /// shows elsewhere) and blank lines are not shown; hidden lines in
  /// between move below the item, so it lands under the line the user
  /// saw.
  ///
  /// Does nothing if the line shown above is in no item, or if the item
  /// is already one level deeper than that item.
  MarkdownDocument indent(LineId id, {Set<LineId> hidden = const {}}) {
    final item = outline.itemOf(id);
    final index = indexOf(id);
    final above = _shownAbove(index, hidden);
    final aboveItem = above == null
        ? null
        : outline.itemsAt(lines[above].id).firstOrNull;
    if (item == null || aboveItem == null) return this;
    final depth = outline.depthOf(item);
    if (depth > outline.depthOf(aboveItem)) return this;
    // Right after the lines under the item above, unless among them.
    final spot = min(_endOf(aboveItem), index);
    return _moveSubtree(id, spot: (_, _) => spot, level: depth + 1);
  }

  /// Moves the item [id] with its subitems one level left, beside the
  /// item it was under. Does nothing in no item.
  MarkdownDocument outdent(LineId id) {
    final item = outline.itemOf(id);
    if (item == null) return this;
    final depth = outline.depthOf(item);
    if (depth == 0) return this;
    final index = indexOf(id);
    return _moveSubtree(id, spot: (_, _) => index, level: depth - 1);
  }

  /// Index of the nearest line above [index] that is neither blank nor
  /// in [hidden]; `null` if there is none.
  int? _shownAbove(int index, Set<LineId> hidden) {
    if (index == 0) return null;
    final above = lines.lastIndexWhere(
      (line) => !line.isBlank && !hidden.contains(line.id),
      index - 1,
    );
    return above < 0 ? null : above;
  }

  /// Index just past [item]'s lines (see [ItemOutline.subtree]).
  int _endOf(ItemBlock item) => outline.subtree(item).end;

  /// Takes the item [id] with its subitems out and puts them back where
  /// [spot] says: it gets the document of the remaining lines and the
  /// span taken, and returns the index in them, or `null` to leave the
  /// document as it is. With [level], they are written at that level
  /// there; else they stay as written.
  MarkdownDocument _moveSubtree(
    LineId id, {
    required int? Function(MarkdownDocument rest, LineSpan moved) spot,
    int? level,
  }) {
    final item = outline.itemOf(id)!;
    final span = outline.subtree(item);
    final moved = lines.sublist(span.start, span.end);
    final rest = withLines([...lines]..removeRange(span.start, span.end));
    final at = spot(rest, span);
    if (at == null) return this;
    final placed = level == null
        ? moved
        : [
            for (final (index, raw) in writer
                .placed(
                  outline,
                  item,
                  moved,
                  rest.outline,
                  rest.outline.placeAt(at, level),
                )
                .indexed)
              moved[index].withRaw(raw),
          ];
    return withLines([...rest.lines]..insertAll(at, placed));
  }

  /// The index the line at [index] has once the lines of [span] are taken
  /// out; `null` if it is among them.
  static int? _indexWithout(LineSpan span, int index) => index < span.start
      ? index
      : (index >= span.end ? index - (span.end - span.start) : null);

  /// Where lines go at the end: before a final line break (an empty last
  /// line), if any.
  int get textEnd => lines.length > 1 && lines.last.raw.isEmpty
      ? lines.length - 1
      : lines.length;

  MarkdownDocument _replaced(LineId id, MarkdownLine line) =>
      withLines([...lines]..[indexOf(id)] = line);
}

/// The index in its marker line of [item]'s box mark: the character
/// between `[` and `]`. Only for a checkbox.
int boxMarkIndex(ItemOutline outline, ItemBlock item) {
  final rest = outline.partsOf(item, item.firstLine).rest;
  final raw = item.firstLine.raw;
  final restStart = raw.length - rest.length;
  final marker = item.marker.isNumbered
      ? numberedMarker.matchAsPrefix(rest)!.end
      : 1;
  final box = taskBox.firstMatch(rest.substring(marker))!;
  return restStart + marker + box.start + 1;
}

/// How a new item's marker is written: [marker], with the space after
/// it.
final class ItemStyle {
  const ItemStyle._(this.marker);

  /// An item of [kind] in the style of the [item] it goes right after:
  /// its bullet character, or the number after its own.
  factory ItemStyle.after(ItemOutline outline, ItemBlock item, ListKind kind) =>
      ItemStyle.of(
        kind,
        bullet: item.marker.bullet ?? '-',
        number: (outline.numberOf(item) ?? 0) + 1,
        delimiter: item.marker.delimiter ?? '.',
      );

  /// An item of [kind], unchecked.
  factory ItemStyle.of(
    ListKind kind, {
    String bullet = '-',
    int number = 1,
    String delimiter = '.',
  }) => ItemStyle._(switch (kind) {
    ListKind.checkbox => '$bullet [ ] ',
    ListKind.bullet => '$bullet ',
    ListKind.numbered => '$number$delimiter ',
  });

  final String marker;
}
