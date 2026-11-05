/// A line break: `\n`, `\r\n` or a lone `\r`, as CommonMark reads them.
final anyLineBreak = RegExp(r'\r\n?|\n');

/// [text]'s lines, without their breaks ([anyLineBreak]). The last line is
/// empty when [text] ends with a break. Always at least one line.
List<String> splitLines(String text) => text.split(anyLineBreak);

/// Where line [line] (from 0) of [text], a `\n` text, starts; its end if
/// it has fewer lines.
int lineStart(String text, int line) => line == 0
    ? 0
    : switch ('\n'.allMatches(text).elementAtOrNull(line - 1)) {
        final lineBreak? => lineBreak.end,
        null => text.length,
      };

/// The line (from 0) of [text], a `\n` text, that [offset] is on.
int lineAt(String text, int offset) => '\n'
    .allMatches(text)
    .takeWhile((lineBreak) => lineBreak.start < offset)
    .length;
