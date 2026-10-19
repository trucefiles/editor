import 'line_id.dart';

/// The kinds of list items.
enum ListKind {
  /// `- [ ] text`, with a box to check.
  checkbox,

  /// `- text`.
  bullet,

  /// `1. text`.
  numbered,
}

/// One line of [MarkdownLines]: a list item or any other line. Knows only
/// its own syntax; whether it is in a code block, where no list exists,
/// is the document's to say.
final class MarkdownLine {
  const MarkdownLine._(this.id, this.raw, this._item);

  /// [raw] as line [id].
  factory MarkdownLine.parse(LineId id, String raw) =>
      MarkdownLine._(id, raw, _ItemParts.of(raw));

  /// A new unchecked item [id] of [kind], with [indent] and [text].
  factory MarkdownLine.newItem(
    LineId id,
    ListKind kind,
    String text, {
    String indent = '',
  }) => MarkdownLine.parse(
    id,
    '$indent${_prefixOf(kind, bullet: '-', number: 1)}${oneLine(text)}',
  );

  final LineId id;

  /// The line as in the file, without its line break.
  final String raw;

  final _ItemParts? _item;

  /// The kind of list item this line is; `null` if it is none.
  ListKind? get listKind => _item?.kind;

  bool get isListItem => _item != null;

  bool get isCheckbox => listKind == ListKind.checkbox;

  bool get isChecked => switch (_item) {
    _ItemParts(kind: ListKind.checkbox, :final markIndex) =>
      raw[markIndex] != ' ',
    _ => false,
  };

  /// A list item's text after its marker (bullet, number, box); the whole
  /// line for other lines.
  String get text => switch (_item) {
    final item? => raw.substring(item.textStart),
    null => raw,
  };

  /// Leading whitespace.
  String get indent => raw.substring(0, raw.length - raw.trimLeft().length);

  /// The checkbox item with its box checked if it was not, else unchecked.
  MarkdownLine toggled() {
    final item = _item!;
    assert(item.kind == ListKind.checkbox, 'only a checkbox toggles');
    final mark = isChecked ? ' ' : 'x';
    return MarkdownLine._(
      id,
      raw.replaceRange(item.markIndex, item.markIndex + 1, mark),
      item,
    );
  }

  /// The list item with [text] after its marker. Keeps the prefix as
  /// written; a marker at the end of the line gets a space before its
  /// first text.
  MarkdownLine withText(String text) {
    var prefix = raw.substring(0, _item!.textStart);
    if (text.isNotEmpty && !_endsInSpace(prefix)) prefix = '$prefix ';
    return MarkdownLine.parse(id, '$prefix${oneLine(text)}');
  }

  /// The line with [indent] as its leading whitespace.
  MarkdownLine withIndent(String indent) =>
      MarkdownLine.parse(id, '$indent${raw.substring(this.indent.length)}');

  /// The list item turned into an unchecked one of [kind] with [text],
  /// keeping its indent and bullet character.
  MarkdownLine withKind(ListKind kind, String text) {
    final prefix = _prefixOf(kind, bullet: _item!.bullet ?? '-', number: 1);
    return MarkdownLine.parse(id, '$indent$prefix${oneLine(text)}');
  }

  /// A new unchecked item [id] at this item's level, of [kind] (this
  /// item's own if `null`), in this item's style: its bullet character, or
  /// the number after its own.
  MarkdownLine newSibling(LineId id, String text, {ListKind? kind}) {
    final item = _item!;
    final prefix = _prefixOf(
      kind ?? item.kind,
      bullet: item.bullet ?? '-',
      number: (item.number ?? 0) + 1,
      delimiter: item.delimiter ?? '.',
    );
    return MarkdownLine.parse(id, '$indent$prefix${oneLine(text)}');
  }

  /// [text] with line breaks as spaces: a line is one line, and pasted
  /// text can hold breaks (`\r`, U+2028) that a text field lets through.
  static String oneLine(String text) => text.replaceAll(_lineBreaks, ' ');

  static final _lineBreaks = RegExp('\r\n|[\r\n  ]');

  static String _prefixOf(
    ListKind kind, {
    required String bullet,
    required int number,
    String delimiter = '.',
  }) => switch (kind) {
    ListKind.checkbox => '$bullet [ ] ',
    ListKind.bullet => '$bullet ',
    ListKind.numbered => '$number$delimiter ',
  };

  static bool _endsInSpace(String prefix) =>
      prefix.endsWith(' ') || prefix.endsWith('\t');
}

/// Where the parts of a list item's line are.
final class _ItemParts {
  const _ItemParts({
    required this.kind,
    required this.textStart,
    this.markIndex = -1,
    this.bullet,
    this.number,
    this.delimiter,
  });

  /// The parts of [raw] if it is a list item.
  static _ItemParts? of(String raw) {
    if (_thematicBreak.hasMatch(raw)) return null;
    if (_checkbox.firstMatch(raw) case final match?) {
      return _ItemParts(
        kind: ListKind.checkbox,
        textStart: raw.length - match[3]!.length,
        markIndex: match[1]!.length + match[2]!.length + 1,
        bullet: match[2]!.trim(),
      );
    }
    if (_bullet.firstMatch(raw) case final match?) {
      return _ItemParts(
        kind: ListKind.bullet,
        textStart: raw.length - match[3]!.length,
        bullet: match[2],
      );
    }
    if (_numbered.firstMatch(raw) case final match?) {
      return _ItemParts(
        kind: ListKind.numbered,
        textStart: raw.length - match[4]!.length,
        number: int.parse(match[2]!),
        delimiter: match[3],
      );
    }
    return null;
  }

  /// `- [ ] text`, also with `*` or `+` bullets and `[x]` or `[X]`; as in
  /// GitHub Flavored Markdown, the box is followed by whitespace or the
  /// end of the line, so `- [x](url)` is a bulleted link.
  static final _checkbox = RegExp(
    r'^([ \t]*)([-*+][ \t]+)\[[ xX]\](?:[ \t]|$)(.*)$',
  );

  static final _bullet = RegExp(r'^([ \t]*)([-*+])(?:[ \t]+|$)(.*)$');

  static final _numbered = RegExp(r'^([ \t]*)(\d{1,9})([.)])(?:[ \t]+|$)(.*)$');

  /// `---`, `* * *` and the like: a line, not a list item.
  static final _thematicBreak = RegExp(
    r'^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$',
  );

  final ListKind kind;

  /// Start of the item text.
  final int textStart;

  /// Index of the character between `[` and `]` of a checkbox.
  final int markIndex;

  /// The bullet character of a checkbox or bullet item.
  final String? bullet;

  /// The number and the character after it of a numbered item.
  final int? number;
  final String? delimiter;
}
