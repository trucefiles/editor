import 'package:collection/collection.dart';

import 'editable_lines.dart';
import 'line.dart';
import 'line_change.dart';
import 'line_endings.dart';

/// A text as its lines, each with its own line ending and an id that
/// stays with it across changes, so a line editor can follow a line while
/// its text changes. A byte order mark is kept apart from the lines.
/// Immutable: a change gives new lines; ids are unique among the lines
/// changed from one [TextLines.read].
final class TextLines implements EditableLines<TextLines> {
  TextLines._(List<Line> lines, this._nextLineId, {required this.byteOrderMark})
    : lines = List.unmodifiable(lines);

  /// [text], with its lines ended by `\n`, `\r\n` or `\r`.
  factory TextLines.read(String text) {
    final bom = text.startsWith(byteOrderMarkCharacter);
    final lines = [
      for (final (index, line) in splitLines(
        bom ? text.substring(1) : text,
      ).indexed)
        Line(LineId(index), line.text, line.ending),
    ];
    return TextLines._(lines, lines.length, byteOrderMark: bom);
  }

  @override
  final List<Line> lines;

  /// Whether the text starts with a byte order mark.
  final bool byteOrderMark;

  final int _nextLineId;

  @override
  late final String text = [
    if (byteOrderMark) byteOrderMarkCharacter,
    for (final line in lines) ...[line.text, line.ending],
  ].join();

  /// The ending most of its lines have, for lines it gets.
  late final String lineEnding = dominantEnding(
    lines.map((line) => line.ending),
  );

  late final Map<LineId, int> _indexes = {
    for (final (index, line) in lines.indexed) line.id: index,
  };

  @override
  int indexOf(LineId id) =>
      _indexes[id] ?? (throw ArgumentError.value(id, 'id', 'no such line'));

  /// The line [id]; `null` if there is none.
  Line? lineOf(LineId id) => switch (_indexes[id]) {
    final index? => lines[index],
    null => null,
  };

  /// These lines with [change] made; at least one line stays.
  TextLines changed(LineChange change) {
    assert(
      change.lines.isNotEmpty || change.end - change.start < lines.length,
      'a change leaves a text without lines',
    );
    assert(() {
      final kept = change.lines.map((line) => line.id).nonNulls.toList();
      final others = {
        for (final line in [
          ...lines.take(change.start),
          ...lines.skip(change.end),
        ])
          line.id,
      };
      return kept.toSet().length == kept.length && !kept.any(others.contains);
    }(), 'line ids stay unique');
    assert(() {
      final endings = [
        ...lines.take(change.start).map((line) => line.ending),
        ...change.lines.map((line) => line.ending),
        ...lines.skip(change.end).map((line) => line.ending),
      ];
      return endings.last.isEmpty &&
          endings.take(endings.length - 1).every((e) => e.isNotEmpty);
    }(), 'every line but the last ends with a line ending');
    var nextLineId = _nextLineId;
    final added = [
      for (final line in change.lines)
        Line(line.id ?? LineId(nextLineId++), line.text, line.ending),
    ];
    return TextLines._(
      [...lines.take(change.start), ...added, ...lines.skip(change.end)],
      nextLineId,
      byteOrderMark: byteOrderMark,
    );
  }

  /// The change that puts [lines], as a line editor holds them, in place
  /// of the lines from [start] to [end]: a line that keeps its id keeps
  /// its line ending, a new one ends as most lines do; the last line ends
  /// with none. A text with line breaks in it (e.g. pasted lines) becomes
  /// as many lines, the first one keeping the id; the new ones end as
  /// most lines do.
  LineChange changeOf(
    int start,
    int end,
    List<({LineId? id, String text})> lines,
  ) {
    // The line before becomes the last one: it loses its ending.
    if (end == this.lines.length && lines.isEmpty && start > 0) {
      final before = this.lines[start - 1];
      return changeOf(start - 1, end, [(id: before.id, text: before.text)]);
    }
    final atEnd = end == this.lines.length;
    return LineChange(start, end, [
      for (final (index, (:id, :text)) in lines.indexed)
        ..._parts(
          id,
          splitLines(text),
          last: atEnd && index == lines.length - 1,
        ),
    ]);
  }

  /// The lines a line editor's line [id] holds, as [parts]: the last
  /// ends as the line did, inner ones as new lines do.
  List<NewLine> _parts(
    LineId? id,
    List<TextLine> parts, {
    required bool last,
  }) => [
    for (final (index, part) in parts.indexed)
      (
        id: index == 0 ? id : null,
        text: part.text,
        ending: switch (index == parts.length - 1) {
          false => lineEnding,
          true when last => '',
          true => switch (id == null ? null : lineOf(id)?.ending) {
            final ending? when ending.isNotEmpty => ending,
            _ => lineEnding,
          },
        },
      ),
  ];

  /// The change to [text] (without its byte order mark): the unchanged
  /// lines at the start and end keep their ids; all others are new
  /// lines.
  LineChange changeTo(String text) {
    final news = splitLines(_withoutMark(text));
    final olds = [
      for (final line in lines) (text: line.text, ending: line.ending),
    ];
    final head = _sameAtStart(news, olds);
    final tail = _sameAtStart(
      news.skip(head).toList().reversed,
      olds.skip(head).toList().reversed,
    );
    return LineChange(head, olds.length - tail, [
      for (final line in news.sublist(head, news.length - tail))
        (id: null, text: line.text, ending: line.ending),
    ]);
  }

  /// These lines with [lines] from [start] to [end] (see [changeOf]).
  @override
  TextLines withLines(
    int start,
    int end,
    List<({LineId? id, String text})> lines,
  ) => changed(changeOf(start, end, lines));

  /// These lines with [text] instead (see [changeTo]).
  @override
  TextLines withText(String text) => changed(changeTo(text)).withMarkOf(text);

  /// These lines, starting with a byte order mark if [text] does.
  TextLines withMarkOf(String text) {
    final mark = text.startsWith(byteOrderMarkCharacter);
    return mark == byteOrderMark
        ? this
        : TextLines._(lines, _nextLineId, byteOrderMark: mark);
  }

  static String _withoutMark(String text) =>
      text.startsWith(byteOrderMarkCharacter) ? text.substring(1) : text;
}

/// How many items [a] and [b] have equal at their start.
int _sameAtStart<T>(Iterable<T> a, Iterable<T> b) =>
    IterableZip([a, b]).takeWhile((pair) => pair[0] == pair[1]).length;
