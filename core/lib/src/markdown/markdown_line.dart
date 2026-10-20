import 'line_id.dart';
import 'syntax/block_syntax.dart';

/// One line of [MarkdownLines]: a list item or any other line. Knows only
/// its own syntax; whether it is in a code block, where no list exists,
/// is the document's to say.
final class MarkdownLine {
  const MarkdownLine._(this.id, this.raw, this._item);

  /// [raw] as line [id].
  factory MarkdownLine.parse(LineId id, String raw) =>
      MarkdownLine._(id, raw, ItemSyntax.of(raw));

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

  final ItemSyntax? _item;

  /// The kind of list item this line is; `null` if it is none.
  ListKind? get listKind => _item?.kind;

  bool get isListItem => _item != null;

  bool get isCheckbox => listKind == ListKind.checkbox;

  /// The number written on a numbered item; `null` on any other line.
  int? get number => _item?.number;

  /// Whether this numbered item counts on from the numbered item [above],
  /// the item before it in its list: as in Markdown, only one written with
  /// the same delimiter (`.` or `)`) does.
  bool countsOnFrom(MarkdownLine above) =>
      listKind == ListKind.numbered &&
      above.listKind == ListKind.numbered &&
      _item!.delimiter == above._item!.delimiter;

  bool get isChecked => switch (_item) {
    ItemSyntax(kind: ListKind.checkbox, :final markIndex) =>
      raw[markIndex] != ' ',
    _ => false,
  };

  /// A list item's text after its marker (bullet, number, box); the whole
  /// line for other lines.
  String get text => switch (_item) {
    final item? => raw.substring(item.textStart),
    null => raw,
  };

  /// Whether this list item's marker ends the line with no space after
  /// it, as while one is being typed: `-`, `1.` or `- [ ]`.
  bool get markEndsLine => switch (_item) {
    final item? => !_endsInSpace(raw.substring(0, item.textStart)),
    null => false,
  };

  /// Leading whitespace.
  String get indent => raw.substring(0, raw.length - raw.trimLeft().length);

  /// Whether the line is empty or only whitespace.
  bool get isBlank => raw.trim().isEmpty;

  /// How far this item's content starts after its indent, in columns: past
  /// its marker and the spaces after it, as Markdown counts them. Lines
  /// under the item start at least this far in. Only for items.
  int get contentOffset => _item!.contentStart - indent.length;

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
