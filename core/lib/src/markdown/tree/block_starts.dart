/// The line patterns that start or end blocks, as CommonMark and GitHub
/// Flavored Markdown define them. The one owner of these patterns.
library;

/// An ATX heading's opening marks: up to three spaces are before the
/// rest, which starts with 1 to 6 `#` and then whitespace or the end.
final atxHeading = RegExp(r'#{1,6}(?:[ \t]+|$)');

/// A code fence: three or more backticks or tildes.
final codeFence = RegExp(r'`{3,}(?!.*`)|~{3,}');

/// A closing code fence of at least [length] of [char], alone with
/// trailing spaces.
bool closesFence(String rest, String char, int length) =>
    RegExp('^${RegExp.escape(char)}{$length,}[ \t]*\$').hasMatch(rest);

/// A thematic break: three or more `-`, `*` or `_`, spaces between.
final thematicBreak = RegExp(
  r'(?:(?:\*[ \t]*){3,}|(?:_[ \t]*){3,}|(?:-[ \t]*){3,})$',
);

/// A setext heading's underline: `=` or `-` only, trailing spaces.
final setextUnderline = RegExp(r'(?:=+|-+)[ \t]*$');

/// A bullet list marker followed by whitespace or the end.
final bulletMarker = RegExp(r'[*+-](?=[ \t]|$)');

/// A numbered list marker: one to nine digits and `.` or `)`.
final numberedMarker = RegExp(r'(\d{1,9})([.)])(?=[ \t]|$)');

/// A task list box after an item's marker: `[ ]`, `[x]` or `[X]`, then
/// whitespace or the end of the line.
final taskBox = RegExp(r'\[([ xX])\](?=[ \t]|$)');

/// A table's delimiter row: cells of dashes, colons at their ends.
final tableDelimiterRow = RegExp(
  r'^\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$',
);

/// Front matter's fence line: exactly `---`, trailing spaces.
final frontMatterFence = RegExp(r'^---[ \t]*$');

/// The closing line of front matter: `---` or `...`.
final frontMatterEnd = RegExp(r'^(?:---|\.\.\.)[ \t]*$');

/// The first line inside front matter: a YAML key, so a note that only
/// starts with a rule is no front matter.
final frontMatterKey = RegExp(r'^[A-Za-z0-9_-]+:(?:[ \t]|$)');

/// HTML block start conditions 1 to 7, by their number; condition 7
/// cannot interrupt a paragraph.
final htmlBlockStarts = <int, RegExp>{
  1: RegExp(r'<(?:script|pre|textarea|style)(?:\s|>|$)', caseSensitive: false),
  2: RegExp(r'<!--'),
  3: RegExp(r'<[?]'),
  4: RegExp(r'<![A-Za-z]'),
  5: RegExp(r'<!\[CDATA\['),
  6: RegExp(
    r'<[/]?(?:address|article|aside|base|basefont|blockquote|body|caption|'
    r'center|col|colgroup|dd|details|dialog|dir|div|dl|dt|fieldset|'
    r'figcaption|figure|footer|form|frame|frameset|h[123456]|head|header|'
    r'hr|html|iframe|legend|li|link|main|menu|menuitem|nav|noframes|ol|'
    r'optgroup|option|p|param|search|section|summary|table|tbody|td|tfoot|'
    r'th|thead|title|tr|track|ul)(?:\s|[/]?[>]|$)',
    caseSensitive: false,
  ),
  7: RegExp('^(?:$_openTag|$_closingTag)\\s*\$', caseSensitive: false),
};

/// HTML block end conditions 1 to 5; 6 and 7 end at a blank line.
final htmlBlockEnds = <int, RegExp>{
  1: RegExp(r'</(?:script|pre|textarea|style)>', caseSensitive: false),
  2: RegExp(r'-->'),
  3: RegExp(r'\?>'),
  4: RegExp(r'>'),
  5: RegExp(r'\]\]>'),
};

const _tagName = '[A-Za-z][A-Za-z0-9-]*';
const _attributeName = '[a-zA-Z_:][a-zA-Z0-9:._-]*';
const _unquotedValue = '[^"\'=<>`\\x00-\\x20]+';
const _singleQuoted = "'[^']*'";
const _doubleQuoted = '"[^"]*"';
const _attributeValue = '(?:$_unquotedValue|$_singleQuoted|$_doubleQuoted)';
const _attributeValueSpec = '(?:\\s*=\\s*$_attributeValue)';
const _attribute = '(?:\\s+$_attributeName$_attributeValueSpec?)';

/// An HTML open tag, as inline raw HTML and HTML blocks read it.
const htmlOpenTag = '<$_tagName$_attribute*\\s*/?>';

/// An HTML closing tag.
const htmlClosingTag = '</$_tagName\\s*[>]';

const _openTag = htmlOpenTag;
const _closingTag = htmlClosingTag;
