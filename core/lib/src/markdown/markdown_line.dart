import 'line_id.dart';

/// One line of [MarkdownLines]: a checkbox item or any other line.
final class MarkdownLine {
  const MarkdownLine._(this.id, this.raw, this._item);

  /// [raw] as line [id].
  factory MarkdownLine.parse(LineId id, String raw) {
    final match = _itemPattern.firstMatch(raw);
    return MarkdownLine._(
      id,
      raw,
      match == null
          ? null
          : _ItemParts(
              indentEnd: match.group(1)!.length,
              markIndex: match.group(1)!.length + match.group(2)!.length + 1,
              textStart: raw.length - match.group(3)!.length,
            ),
    );
  }

  /// `- [ ] text`, also with `*` or `+` bullets and `[x]` or `[X]`; as in
  /// GitHub Flavored Markdown, the box is followed by whitespace or the end
  /// of the line, so `- [x](url)` is a bulleted link, not an item.
  static final _itemPattern = RegExp(
    r'^([ \t]*)([-*+][ \t]+)\[[ xX]\](?:[ \t]|$)(.*)$',
  );

  final LineId id;

  /// The line as in the file, without its line break.
  final String raw;

  final _ItemParts? _item;

  bool get isItem => _item != null;

  bool get isChecked => switch (_item) {
    final item? => raw[item.markIndex] != ' ',
    null => false,
  };

  /// The item's text after the checkbox; the whole line for other lines.
  String get text => switch (_item) {
    final item? => raw.substring(item.textStart),
    null => raw,
  };

  /// Leading whitespace.
  String get indent => switch (_item) {
    final item? => raw.substring(0, item.indentEnd),
    null => raw.substring(0, raw.length - raw.trimLeft().length),
  };

  /// The item with its box checked if it was not, else unchecked.
  MarkdownLine toggled() {
    final item = _item!;
    final mark = isChecked ? ' ' : 'x';
    return MarkdownLine._(
      id,
      raw.replaceRange(item.markIndex, item.markIndex + 1, mark),
      item,
    );
  }

  /// The item with [text] after its box. Keeps the prefix as written; a
  /// box at the end of the line gets a space before its first text.
  MarkdownLine withText(String text) {
    final item = _item!;
    var prefix = raw.substring(0, item.textStart);
    if (text.isNotEmpty && prefix.endsWith(']')) prefix = '$prefix ';
    return MarkdownLine.parse(id, '$prefix${oneLine(text)}');
  }

  /// The line with [indent] as its leading whitespace.
  MarkdownLine withIndent(String indent) =>
      MarkdownLine.parse(id, '$indent${raw.substring(this.indent.length)}');

  /// An unchecked item [id] at this item's level, with its bullet style.
  MarkdownLine newSibling(LineId id, String text) {
    final item = _item!;
    final prefix = raw.substring(0, item.markIndex - 1);
    return MarkdownLine.parse(id, '$prefix[ ] ${oneLine(text)}');
  }

  /// [text] with line breaks as spaces: an item is one line, and pasted
  /// text can hold breaks (`\r`, U+2028) that a text field lets through.
  static String oneLine(String text) => text.replaceAll(_lineBreaks, ' ');

  static final _lineBreaks = RegExp('\r\n|[\r\n\u2028\u2029]');
}

final class _ItemParts {
  const _ItemParts({
    required this.indentEnd,
    required this.markIndex,
    required this.textStart,
  });

  /// End of leading whitespace.
  final int indentEnd;

  /// Index of the character between `[` and `]`.
  final int markIndex;

  /// Start of the item text.
  final int textStart;
}
