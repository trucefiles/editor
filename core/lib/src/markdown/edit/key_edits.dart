import '../document/item_outline.dart';
import '../document/markdown_document.dart';
import '../inline/hard_break.dart';
import '../lines/line_id.dart';
import '../lines/markdown_line.dart';
import '../tree/blocks.dart';
import '../view/edit_view.dart';
import 'container_exits.dart';
import 'item_edits.dart';
import 'line_writer.dart';
import 'text_edits.dart';

/// What the editing keys do to a document: Enter, a line break, and
/// Backspace and Delete across blocks. Each returns the new document and
/// where the caret goes; `null` for the caret where the editor places it
/// (by what it shows around).
extension KeyEdits on MarkdownDocument {
  /// Enter at [offset] in [view]: in an item's text, a new item with the
  /// text after the caret (or, at the start of its first line, an empty
  /// one above it); in an empty item, out of the item: one level out, or
  /// out of the list; in an empty line of a quote or item, out of it;
  /// anywhere else, and in an item [LeafView.held] as text, a new line in
  /// the block, as a text editor does.
  ///
  /// [shownBelow] is the first line of the text the editor shows right
  /// below [view], if any: at the end of an item's text, the new item
  /// goes after the item's blocks the editor shows elsewhere (e.g. done
  /// subitems), so they stay with their item.
  (MarkdownDocument, LineCaret) enter(
    LeafView view,
    int offset, {
    LineId? shownBelow,
  }) {
    if (view.held) return lineBreak(view, offset, hard: false);
    final leaf = view.leaf;
    return switch ((leaf.textItem, leaf)) {
      (final item?, BlankBlock()) => _leaveItem(item),
      (final item?, _) =>
        offset == 0 && item.leaves.first == leaf
            ? _itemAbove(item, view)
            : _splitItem(item, view, offset, shownBelow),
      (null, final BlankBlock blank) when _segmentOf(blank) != null =>
        _leaveContainer(blank),
      _ => lineBreak(view, offset, hard: false),
    };
  }

  /// [text] pasted over the text from [from] to [to], with [removed]
  /// between them (see [TextEdits.replaceText]). Pasted into an item's
  /// text, each further line starts an item of its own, as Enter does
  /// there; blank lines after the first go. Anywhere else, the lines go
  /// in as they are.
  (MarkdownDocument, LineCaret) paste(
    ViewPlace from,
    ViewPlace to,
    String text, {
    Iterable<EditView> removed = const [],
  }) {
    if (from.view
        case LeafView(leaf: LeafBlock(textItem: null)) || RawLineView()) {
      return replaceText(from, to, text, removed: removed);
    }
    final [first, ...rest] = text.split('\n');
    return rest.where((line) => line.trim().isNotEmpty).fold(
      replaceText(from, to, first, removed: removed),
      (pasted, line) {
        final (document, caret) = pasted;
        final view = document._viewAt(caret);
        final (entered, start) = document.enter(view, view.offsetOf(caret)!);
        final next = entered._viewAt(start);
        final place = (view: next, offset: next.offsetOf(start)!);
        return entered.replaceText(place, place, line);
      },
    );
  }

  /// The view of the leaf [caret] is in, as it shows with the caret.
  LeafView _viewAt(LineCaret caret) =>
      LeafView.of(this, leafOf(caret.line), caretLine: caret.line);

  /// A new line at [offset] in [view], in the same block: with [hard], a
  /// hard line break (a backslash at the end of the line before), as
  /// every Markdown app shows it, but only in an item's text, where a
  /// plain one would start a new item; anywhere else, as [enter].
  (MarkdownDocument, LineCaret) lineBreak(
    LeafView view,
    int offset, {
    bool hard = true,
  }) {
    final place = (view: view, offset: offset);
    if (!hard) return replaceText(place, place, '\n');
    if (view.leaf.parent is! ItemBlock || view.leaf is! ParagraphBlock) {
      return enter(view, offset);
    }
    return replaceText(place, place, '\\\n');
  }

  /// Backspace at the start of [view], with [above] the text the editor
  /// shows right above it, if any: an empty line above goes, keeping
  /// [view] as it is (e.g. an item); [view] empty goes; else [view]'s
  /// first line joins the line above, dropping its own prefix and a
  /// hard break that ended the line above. Without [above], only an
  /// empty [view] goes, and the caret is the editor's to place.
  (MarkdownDocument, LineCaret?)? joinBackward(
    EditView view,
    EditView? above,
  ) => switch (above) {
    null when view.text.isEmpty => _without(view, caret: null),
    null => null,
    _ when above.text.isEmpty => _without(
      above,
      caret: (line: view.id, offset: view.lines.first.start),
    ),
    _ when view.text.isEmpty => _without(view, caret: _endOf(above)),
    _ => _joined(above, view),
  };

  /// Delete at the end of [view], with [below] the text the editor shows
  /// right below it, if any: [view] empty goes, keeping the line below as
  /// it is (e.g. checked); an empty line below goes; else the line below
  /// joins [view]'s last line, as [joinBackward] does.
  (MarkdownDocument, LineCaret?)? joinForward(EditView view, EditView? below) =>
      switch (below) {
        null when view.text.isEmpty => _without(view, caret: null),
        null => null,
        _ when view.text.isEmpty => _without(
          view,
          caret: (line: below.id, offset: below.lines.first.start),
        ),
        _ when below.text.isEmpty => _without(below, caret: _endOf(view)),
        _ => _joined(view, below),
      };

  /// [lower]'s first line joined to [upper]'s last line, without a hard
  /// break being typed at the end of [upper]'s block. A plain text view
  /// keeps every character.
  (MarkdownDocument, LineCaret) _joined(EditView upper, EditView lower) {
    final end = upper.text.length;
    final from = upper is LeafView && end > 0 && _breakEnds(upper.text)
        ? end - 1
        : end;
    return replaceText(
      (view: upper, offset: from),
      (view: lower, offset: 0),
      '',
    );
  }

  /// [view]'s lines gone, unless they are all there is.
  (MarkdownDocument, LineCaret?)? _without(
    EditView view, {
    required LineCaret? caret,
  }) {
    final gone = {for (final line in view.lines) line.line.id};
    if (gone.length == lines.length) return null;
    return (
      withLines([
        for (final line in lines)
          if (!gone.contains(line.id)) line,
      ]),
      caret,
    );
  }

  static LineCaret _endOf(EditView view) =>
      (line: view.lines.last.line.id, offset: view.lines.last.end);

  /// An empty [item] left: one level out, or out of its list, its line
  /// keeping only the quote marks it is in.
  (MarkdownDocument, LineCaret) _leaveItem(ItemBlock item) {
    final id = item.markerLine;
    if (outline.depthOf(item) > 0) {
      final outdented = outdent(id);
      return (outdented, (line: id, offset: outdented.lineOf(id)!.raw.length));
    }
    return _leftOut(id, outer: outline.partsOf(item, lineOf(id)!).outer);
  }

  /// An empty item above [item], in its style; the caret stays.
  (MarkdownDocument, LineCaret) _itemAbove(ItemBlock item, LeafView view) {
    final (document, _) = insertItem(
      indexOf(item.markerLine),
      ItemStyle.after(outline, item, item.kind),
      place: BesideItem(item, outline.depthOf(item)),
    );
    return (document, (line: view.id, offset: view.lines.first.start));
  }

  /// [item] split at [offset] in [view], one of its leaves: the rest of
  /// the caret's line goes into a new item of its kind right below it
  /// (at the end of the leaf, below the blocks of [item] shown elsewhere,
  /// see [enter]), unchecked, which takes the lines and blocks after it
  /// in [item] along as they are.
  (MarkdownDocument, LineCaret) _splitItem(
    ItemBlock item,
    LeafView view,
    int offset,
    LineId? shownBelow,
  ) {
    final caret = view.caretAt(offset);
    final line = lineOf(caret.line)!;
    final at = caret.line == view.lines.last.line.id
        ? (_hiddenEnd(item, view.leaf, shownBelow) ?? indexOf(line.id) + 1)
        : indexOf(line.id) + 1;
    final end = view.lines.firstWhere((part) => part.line.id == line.id).end;
    final prefix =
        writer.itemPrefix(outline, BesideItem(item, outline.depthOf(item))) +
        ItemStyle.after(outline, item, item.kind).marker;
    late final MarkdownLine added;
    final split = edited((newLine) {
      added = newLine(
        LineWriter.withContent(prefix, line.raw.substring(caret.offset, end)),
      );
      final index = indexOf(line.id);
      return [...lines]
        ..[index] = line.withRaw(
          line.raw.substring(0, caret.offset) + line.raw.substring(end),
        )
        ..insert(at, added);
    });
    return (split, (line: added.id, offset: prefix.length));
  }

  /// The index past the last of [item]'s blocks after [leaf] that the
  /// editor shows elsewhere: those before [shownBelow], or all of them
  /// without it; `null` if there is none.
  int? _hiddenEnd(ItemBlock item, LeafBlock leaf, LineId? shownBelow) {
    final span = outline.subtree(item);
    final below = shownBelow == null ? span.end : indexOf(shownBelow);
    final hidden = item.leaves
        .skipWhile((other) => other != leaf)
        .skip(1)
        .where((other) => other is! BlankBlock)
        .takeWhile((other) => indexOf(other.id) < below);
    return switch (hidden.lastOrNull) {
      final last? => indexOf(last.lines.last.id) + 1,
      null => null,
    };
  }

  /// The blank [leaf]'s line out of the container it is in: without that
  /// container's marks.
  (MarkdownDocument, LineCaret) _leaveContainer(BlankBlock leaf) {
    final segment = _segmentOf(leaf)!;
    final line = leaf.lines.first.line;
    return _leftOut(
      line.id,
      outer:
          line.raw.substring(0, segment.start) +
          line.raw.substring(segment.end),
    );
  }

  /// Line [id] out of its container, keeping the quote marks [outer]
  /// (see [ContainerExits.outOfContainer]), with the caret at its end.
  (MarkdownDocument, LineCaret) _leftOut(LineId id, {required String outer}) {
    final left = outOfContainer(id, outer: outer);
    return (left, (line: id, offset: left.lineOf(id)!.raw.length));
  }

  /// The marks of the container blank [leaf] is right in, on its line;
  /// `null` if the line has none (it is in no quote or item, or only by
  /// being in its list).
  static PrefixSegment? _segmentOf(BlankBlock leaf) => switch (leaf.parent) {
    final ContainerBlock container
        when container is QuoteBlock || container is ItemBlock =>
      leaf.lines.first.prefix
          .where((segment) => segment.container == container)
          .lastOrNull,
    _ => null,
  };
}

/// Whether a hard line break (a backslash and the line break after it)
/// ends at [offset] in [text]: Backspace there deletes it as one.
bool hardBreakBefore(String text, int offset) =>
    offset >= 2 && text[offset - 1] == '\n' && _breakAt(text, offset - 2);

/// Whether a hard line break starts at [offset] in [text]: Delete there
/// deletes it as one.
bool hardBreakAfter(String text, int offset) =>
    offset + 1 < text.length &&
    text[offset + 1] == '\n' &&
    _breakAt(text, offset);

bool _breakAt(String text, int index) =>
    text[index] == '\\' && breaksAt(text, index);

bool _breakEnds(String text) => _breakAt(text, text.length - 1);
