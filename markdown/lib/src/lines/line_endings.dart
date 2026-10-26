import '../common/most_used.dart';

/// A line's text and the line ending after it.
typedef TextLine = ({String text, String ending});

/// The line ending used where a document has none to follow.
const standardEnding = '\n';

/// The byte order mark a document may start with.
const byteOrderMarkCharacter = '\uFEFF';

/// [text]'s lines as CommonMark reads them: ended by `\n`, `\r\n` or a
/// lone `\r`. The last line has no ending; it is empty when [text] ends
/// with one. Always at least one line.
List<TextLine> splitLines(String text) {
  final lines = <TextLine>[];
  var start = 0;
  for (final end in _lineEnd.allMatches(text)) {
    lines.add((text: text.substring(start, end.start), ending: end[0]!));
    start = end.end;
  }
  return [...lines, (text: text.substring(start), ending: '')];
}

/// The ending most of [endings] are, else [standardEnding].
String dominantEnding(Iterable<String> endings) =>
    mostUsed(endings.where((ending) => ending.isNotEmpty)) ?? standardEnding;

final _lineEnd = RegExp(r'\r\n?|\n');
