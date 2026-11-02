import 'dart:convert';

/// One property line of an iCalendar text, `NAME;PARAM=VALUE:VALUE`, read
/// whole (unfolded). Keeps the [raw] lines it was read from, so it prints
/// back as it was; a line an edit made has none and prints fresh.
///
/// Own code, not a library: block-exact edits need each line's raw bytes,
/// and no maintained iCalendar package for Dart keeps them (they parse
/// into values and print anew). Repeats (`rrule`) and time zones
/// (`timezone`) do use trusted packages.
final class ContentLine {
  const ContentLine(this.name, this.value, {this.params = const {}, this.raw});

  /// The property's name, upper case.
  final String name;

  /// The parameters by upper-case name, their values without quotes.
  final Map<String, String> params;

  /// The value as written: still escaped where its kind escapes.
  final String value;

  /// The lines it was read from, folded as they were, without the last
  /// line break; `null` for a line made by an edit.
  final String? raw;

  /// The line in [unfolded], read from [raw]; `null` if it is no content
  /// line (no `:` after a name).
  static ContentLine? parse(String unfolded, {String? raw}) {
    final (:head, :value) = _splitValue(unfolded) ?? (head: '', value: '');
    if (head.isEmpty) return null;
    final [name, ...params] = _splitParams(head);
    return ContentLine(
      name.toUpperCase(),
      value,
      params: {
        for (final param in params)
          if (param.indexOf('=') case final at when at > 0)
            param.substring(0, at).toUpperCase(): _unquoted(
              param.substring(at + 1),
            ),
      },
      raw: raw,
    );
  }

  /// The line as printed: its [raw] lines, else fresh and folded.
  String get printed => raw ?? fold(unfolded);

  /// The line as one, unfolded.
  String get unfolded => [
    [
      name,
      for (final MapEntry(:key, :value) in params.entries)
        '$key=${_quoted(value)}',
    ].join(';'),
    value,
  ].join(':');

  /// The parameter [name], if given.
  String? param(String name) => params[name];

  /// [name] and [params] in the head, and the value after the first `:`
  /// outside quotes; `null` if there is none.
  static ({String head, String value})? _splitValue(String line) {
    var quoted = false;
    for (final (index, char) in line.split('').indexed) {
      if (char == '"') quoted = !quoted;
      if (char == ':' && !quoted) {
        return (
          head: line.substring(0, index),
          value: line.substring(index + 1),
        );
      }
    }
    return null;
  }

  /// [head] split at each `;` outside quotes.
  static List<String> _splitParams(String head) {
    final parts = <String>[];
    var quoted = false;
    var start = 0;
    for (final (index, char) in head.split('').indexed) {
      if (char == '"') quoted = !quoted;
      if (char == ';' && !quoted) {
        parts.add(head.substring(start, index));
        start = index + 1;
      }
    }
    return [...parts, head.substring(start)];
  }

  static String _unquoted(String value) =>
      value.length >= 2 && value.startsWith('"') && value.endsWith('"')
      ? value.substring(1, value.length - 1)
      : value;

  static String _quoted(String value) =>
      value.contains(RegExp('[:;,]')) ? '"$value"' : value;
}

/// The most octets a printed line holds, without its line break (RFC
/// 5545, 3.1).
const _maxOctets = 75;

/// [line] folded so no line holds more than 75 octets: each further line
/// starts with a space. Never splits a character.
String fold(String line) {
  final lines = <String>[];
  var current = StringBuffer();
  var octets = 0;
  for (final char in line.runes.map(String.fromCharCode)) {
    final size = utf8.encode(char).length;
    // A further line's leading space takes one octet.
    final limit = lines.isEmpty ? _maxOctets : _maxOctets - 1;
    if (octets + size > limit) {
      lines.add(current.toString());
      current = StringBuffer();
      octets = 0;
    }
    current.write(char);
    octets += size;
  }
  final parts = [...lines, current.toString()];
  return [parts.first, for (final part in parts.skip(1)) ' $part'].join('\n');
}

/// The logical lines of [text] (`\n` breaks): each unfolded, with the raw
/// lines it was read from. A line starting with a space or a tab goes on
/// the line before.
List<({String unfolded, String raw})> logicalLines(String text) {
  final physical = text.split('\n');
  // The text's last line break ends its last line; nothing follows it.
  if (physical.isNotEmpty && physical.last.isEmpty) physical.removeLast();
  final lines = <({String unfolded, String raw})>[];
  for (final line in physical) {
    final continues = line.startsWith(' ') || line.startsWith('\t');
    if (continues && lines.isNotEmpty) {
      final last = lines.removeLast();
      lines.add((
        unfolded: last.unfolded + line.substring(1),
        raw: '${last.raw}\n$line',
      ));
    } else {
      lines.add((unfolded: line, raw: line));
    }
  }
  return lines;
}

/// [value], a TEXT value as written, read: `\n`, `\,`, `\;` and `\\`
/// undone.
String unescapeText(String value) => value.replaceAllMapped(
  RegExp(r'\\(.)'),
  (match) => switch (match[1]!) {
    'n' || 'N' => '\n',
    final other => other,
  },
);

/// [text] as a TEXT value is written (RFC 5545, 3.3.11).
String escapeText(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\n', r'\n');

/// The parts of a TEXT list value (e.g. CATEGORIES), split at each `,`
/// not escaped, each read.
List<String> splitTextList(String value) => [
  for (final part in value.split(RegExp(r'(?<!\\),'))) unescapeText(part),
];
