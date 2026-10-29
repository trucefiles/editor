/// A line break: `\n`, `\r\n` or a lone `\r`, as CommonMark reads them.
final anyLineBreak = RegExp(r'\r\n?|\n');

/// [text]'s lines, without their breaks ([anyLineBreak]). The last line is
/// empty when [text] ends with a break. Always at least one line.
List<String> splitLines(String text) => text.split(anyLineBreak);
