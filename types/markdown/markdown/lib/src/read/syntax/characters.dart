/// Character classes and text helpers as CommonMark defines them; the one
/// owner of these rules for block and inline reading.
library;

import 'package:html/parser.dart' as html;

/// Whether [char] is a space or a tab.
bool isSpaceOrTab(String char) => char == ' ' || char == '\t';

/// Whether [text] holds only spaces and tabs (or is empty).
bool isBlankText(String text) => _blank.hasMatch(text);

/// Whether [char] is Unicode whitespace: the Zs class, tab, line feed,
/// form feed or carriage return.
bool isUnicodeWhitespace(String char) => _whitespace.hasMatch(char);

/// Whether [char] is a Unicode punctuation character: in the P or S
/// general categories.
bool isUnicodePunctuation(String char) => _punctuation.hasMatch(char);

/// Whether [char] is an ASCII punctuation character, which a backslash
/// can escape.
bool isAsciiPunctuation(String char) =>
    char.length == 1 && _asciiPunctuation.contains(char);

/// The character (a whole code point) of [text] that starts at [index].
String codePointAt(String text, int index) {
  final pair =
      index + 1 < text.length &&
      _isHighSurrogate(text.codeUnitAt(index)) &&
      _isLowSurrogate(text.codeUnitAt(index + 1));
  return text.substring(index, pair ? index + 2 : index + 1);
}

/// The character (a whole code point) of [text] that ends at [index].
String codePointBefore(String text, int index) {
  final low = text.codeUnitAt(index - 1);
  final pair =
      index >= 2 &&
      _isLowSurrogate(low) &&
      _isHighSurrogate(text.codeUnitAt(index - 2));
  return text.substring(pair ? index - 2 : index - 1, index);
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// The column [text] ends at, from column [from]: a tab goes on to the
/// next multiple of four.
int columnsOf(String text, [int from = 0]) => text.runes.fold(
  from,
  (column, rune) => rune == 0x09 ? column + 4 - column % 4 : column + 1,
);

/// The character a numeric or named character reference stands for, as
/// HTML5 reads it; `null` if [reference] (`&...;`) stands for none.
String? decodeEntity(String reference) {
  if (!_entity.hasMatch(reference)) return null;
  if (reference.startsWith('&#')) return _numeric(reference);
  final decoded = html.parseFragment(reference).text;
  // HTML5 also takes a known name's prefix (`&ampx;` as `&x;`), which
  // leaves the name's end and the `;`; CommonMark needs the whole name.
  final unread = reference.substring(reference.length - 2);
  return decoded == null || decoded.endsWith(unread) ? null : decoded;
}

String _numeric(String reference) {
  final hex = reference[2] == 'x' || reference[2] == 'X';
  final digits = reference.substring(hex ? 3 : 2, reference.length - 1);
  final code = int.parse(digits, radix: hex ? 16 : 10);
  final valid =
      code > 0 && code <= 0x10FFFF && (code < 0xD800 || code > 0xDFFF);
  return String.fromCharCode(valid ? code : 0xFFFD);
}

/// [text] with backslash escapes and character references replaced by
/// what they stand for, e.g. in a link destination or code info string.
String unescapeText(String text) => text.replaceAllMapped(
  _escapeOrEntity,
  (match) => switch (match[0]!) {
    final escape when escape.startsWith(r'\') => escape.substring(1),
    final reference => decodeEntity(reference) ?? reference,
  },
);

/// [label] as link labels compare: trimmed, inner whitespace collapsed,
/// case-folded (`ß` folds to `SS`, which Dart's upper case keeps).
String normalizeLabel(String label) => label
    .trim()
    .replaceAll(_whitespaceRun, ' ')
    .toLowerCase()
    .toUpperCase()
    .replaceAll('ß', 'SS');

const _asciiPunctuation = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';

final _blank = RegExp(r'^[ \t]*$');
final _whitespace = RegExp(r'^[\t\n\f\r\p{Zs}]$', unicode: true);
final _punctuation = RegExp(r'^[\p{P}\p{S}]$', unicode: true);
final _whitespaceRun = RegExp(r'[ \t\r\n]+');
final _entity = RegExp(
  r'^&(?:#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|[A-Za-z][A-Za-z0-9]{1,31});$',
);
final _escapeOrEntity = RegExp(
  r'''\\[!"#$%&'()*+,\-./:;<=>?@\[\\\]^_`{|}~]|&(?:#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|[A-Za-z][A-Za-z0-9]{1,31});''',
);
