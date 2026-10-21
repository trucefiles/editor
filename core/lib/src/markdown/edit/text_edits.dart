import 'dart:math';

import 'package:collection/collection.dart';

import '../document/markdown_document.dart';
import '../lines/markdown_line.dart';
import '../view/edit_view.dart';
import 'key_edits.dart';

/// A place in a view's text.
typedef ViewPlace = ({EditView view, int offset});

/// The single mapping from text edits in views back to file lines.
extension TextEdits on MarkdownDocument {
  /// The text from [from] to [to] replaced by [text], as an editor's
  /// typing, pasting or deleting does; [to] may be in a later view, and
  /// the lines of [removed] views between them go. Returns the new
  /// document and the caret after [text].
  ///
  /// The new text of [from]'s view maps back to lines by lines: lines it
  /// keeps stay byte-identical; a changed line keeps its own prefix (quote
  /// marks, indent, marker); a new line gets the prefix the view gives
  /// it below the line before; lines no longer there go. A line break
  /// deleted alone in a structured view takes the hard break mark before
  /// it along, as it shows as one break.
  (MarkdownDocument, LineCaret) replaceText(
    ViewPlace from,
    ViewPlace to,
    String text, {
    Iterable<EditView> removed = const [],
  }) {
    final view = from.view;
    if (view is LeafView &&
        to.view == view &&
        text.isEmpty &&
        to.offset == from.offset + 1 &&
        hardBreakBefore(view.text, to.offset)) {
      return replaceText((view: view, offset: from.offset - 1), to, text);
    }
    final newText =
        view.text.substring(0, from.offset) +
        text +
        to.view.text.substring(to.offset);
    final gone = {
      for (final other in [...removed, if (to.view != view) to.view])
        for (final line in other.lines) line.line.id,
    };
    late final List<MarkdownLine> written;
    final document = edited((newLine) {
      written = _written(
        view,
        newText.split('\n'),
        newLine,
        firstEdited: _lineIndexAt(view.text, from.offset),
        lastEdited: to.view == view
            ? _lineIndexAt(view.text, to.offset)
            : view.lines.length,
      );
      final first = indexOf(view.id);
      final last = indexOf(view.lines.last.line.id);
      return [
        for (final line in lines.take(first))
          if (!gone.contains(line.id)) line,
        ...written,
        for (final line in lines.skip(last + 1))
          if (!gone.contains(line.id)) line,
      ];
    });
    return (
      document,
      _caretIn(written, view, newText, from.offset + text.length),
    );
  }

  /// The lines [view] shows once its text has [contents] as its lines,
  /// after an edit from its line [firstEdited] to its line [lastEdited]
  /// (past its last line if the edit goes on in a later view): the same
  /// lines at the start and end stay, as far as the edit leaves them;
  /// between them each old line takes the next new content, in order;
  /// new contents left over become new lines below them, made with
  /// [newLine]; old lines left over go. A view's first line stays first
  /// unless the text before it is kept, so its marker stays on the first
  /// line.
  List<MarkdownLine> _written(
    EditView view,
    List<String> contents,
    NewLine newLine, {
    required int firstEdited,
    required int lastEdited,
  }) {
    final olds = view.lines;
    String contentOf(ViewLine line) =>
        line.line.raw.substring(line.start, line.end);
    final head = _sameCount(
      olds.map(contentOf),
      contents,
      min(min(olds.length, contents.length), firstEdited + 1),
    );
    final most = min(olds.length, contents.length) - head;
    final tail = _sameCount(
      olds.reversed.map(contentOf),
      contents.reversed,
      min(head == 0 ? most - 1 : most, olds.length - lastEdited),
    );
    final changedOld = olds.sublist(head, olds.length - tail);
    final changedNew = contents.sublist(head, contents.length - tail);
    final paired = min(changedOld.length, changedNew.length);
    final pairedLines = [
      for (final (index, old) in changedOld.take(paired).indexed)
        _withContent(old, changedNew[index]),
    ];
    final added = changedNew.skip(paired);
    // The prefix of the last line kept or changed: there is one if any is
    // added.
    String above() => paired > 0
        ? pairedLines.last.raw.substring(0, changedOld[paired - 1].start)
        : olds[head - 1].line.raw.substring(0, olds[head - 1].start);
    final abovePrefix = added.isEmpty ? '' : above();
    final firstAdded = head + paired;
    return [
      for (final line in olds.take(head)) line.line,
      ...pairedLines,
      for (final (index, content) in added.indexed)
        newLine(
          '${view.newLinePrefix(abovePrefix, afterBlank: contents.sublist(firstAdded, firstAdded + index).any((line) => line.trim().isEmpty))}$content',
        ),
      for (final line in olds.skip(olds.length - tail)) line.line,
    ];
  }

  /// [line] with [content] as its part: its prefix and what follows its
  /// part stay. A blank part gets a space before new content after a
  /// marker or quote mark, as Markdown needs.
  static MarkdownLine _withContent(ViewLine line, String content) {
    final raw = line.line.raw;
    final prefix = raw.substring(0, line.start);
    final spaced =
        line.start == line.end &&
        content.isNotEmpty &&
        prefix.isNotEmpty &&
        !prefix.endsWith(' ') &&
        !prefix.endsWith('\t');
    return line.line.withRaw(
      '$prefix${spaced ? ' ' : ''}$content${raw.substring(line.end)}',
    );
  }

  /// The caret at [offset] in [text], the new text of [view], which
  /// [written] lines now hold.
  static LineCaret _caretIn(
    List<MarkdownLine> written,
    EditView view,
    String text,
    int offset,
  ) {
    final before = text.substring(0, offset);
    final index = '\n'.allMatches(before).length;
    final inLine = offset - (before.lastIndexOf('\n') + 1);
    final line = written[index];
    final contentLength = text.split('\n')[index].length;
    return (line: line.id, offset: _contentEnd(line) - contentLength + inLine);
  }

  /// The index of the line [offset] is on in [text].
  static int _lineIndexAt(String text, int offset) =>
      '\n'.allMatches(text.substring(0, offset)).length;

  /// Where a line's part ends: before a carriage return that ends it.
  static int _contentEnd(MarkdownLine line) =>
      line.raw.endsWith('\r') ? line.raw.length - 1 : line.raw.length;
}

/// How many items [a] and [b] have equal at their start, at most [limit].
int _sameCount(Iterable<String> a, Iterable<String> b, int limit) =>
    IterableZip([a, b])
        .take(limit)
        .takeWhile((pair) => pair[0] == pair[1])
        .length;
