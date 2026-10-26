/// The syntax of link labels, destinations and titles, which link
/// reference definitions and inline links share. The one owner of these
/// rules.
library;

import '../../tree/blocks.dart';
import 'characters.dart';

/// The autolink (`<...>`, a URI or an email address) at [start] of
/// [text]: its destination.
Read<String>? readAutolink(String text, int start) {
  if (_emailAutolink.matchAsPrefix(text, start) case final match?) {
    return (value: 'mailto:${match[1]}', end: match.end);
  }
  if (_uriAutolink.matchAsPrefix(text, start) case final match?) {
    return (value: match[1]!, end: match.end);
  }
  return null;
}

/// The destination of an autolink whose text is [text]; `null` if no
/// autolink shows it.
String? autolinkDestination(String text) =>
    switch (readAutolink('<$text>', 0)) {
      (:final value, :final end) when end == text.length + 2 => value,
      _ => null,
    };

final _emailAutolink = RegExp(
  r"<([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*)>",
);
final _uriAutolink = RegExp(
  r'<([A-Za-z][A-Za-z0-9.+-]{1,31}:[^<>\x00-\x20]*)>',
);

/// A value read from text, and the index right after it.
typedef Read<T> = ({T value, int end});

/// The link label (`[...]`) at [start] of [text]: its raw inner text.
Read<String>? readLinkLabel(String text, int start) {
  final match = _label.matchAsPrefix(text, start);
  if (match == null) return null;
  final inner = text.substring(start + 1, match.end - 1);
  if (inner.length > 999 || isBlankText(inner.replaceAll('\n', ''))) {
    return null;
  }
  return (value: inner, end: match.end);
}

/// The link destination at [start] of [text], unescaped: `<...>`, or
/// text without spaces or control characters and with balanced
/// parentheses.
Read<String>? readLinkDestination(String text, int start) {
  if (_bracedDestination.matchAsPrefix(text, start) case final match?) {
    return (
      value: unescapeText(text.substring(start + 1, match.end - 1)),
      end: match.end,
    );
  }
  if (start < text.length && text[start] == '<') return null;
  var depth = 0;
  var index = start;
  while (index < text.length) {
    final char = text[index];
    if (char == r'\' &&
        index + 1 < text.length &&
        isAsciiPunctuation(text[index + 1])) {
      index += 2;
    } else if (char == '(') {
      depth++;
      index++;
    } else if (char == ')') {
      if (depth == 0) break;
      depth--;
      index++;
    } else if (_spaceOrControl.hasMatch(char)) {
      break;
    } else {
      index++;
    }
  }
  if (index == start && (index >= text.length || text[index] != ')')) {
    return null;
  }
  if (depth != 0) return null;
  return (value: unescapeText(text.substring(start, index)), end: index);
}

/// The link title at [start] of [text], unescaped: `"..."`, `'...'` or
/// `(...)`.
Read<String>? readLinkTitle(String text, int start) {
  final match = _title.matchAsPrefix(text, start);
  if (match == null) return null;
  return (
    value: unescapeText(text.substring(start + 1, match.end - 1)),
    end: match.end,
  );
}

/// The index after spaces and tabs with at most one line break among
/// them, from [start] of [text].
int skipSpaceAndNewline(String text, int start) =>
    _spaceNewline.matchAsPrefix(text, start)!.end;

/// The link reference definition at [start] of [text], which must end
/// at a line end: the definition and the index after its line break.
Read<LinkDefinition>? readLinkDefinition(String text, int start) {
  final label = readLinkLabel(text, start);
  if (label == null) return null;
  var index = label.end;
  if (index >= text.length || text[index] != ':') return null;
  index = skipSpaceAndNewline(text, index + 1);
  final destination = readLinkDestination(text, index);
  if (destination == null) return null;
  final beforeTitle = destination.end;
  final titleStart = skipSpaceAndNewline(text, beforeTitle);
  final title = titleStart == beforeTitle
      ? null
      : readLinkTitle(text, titleStart);
  final end = switch (title) {
    final title? => _lineEnd(text, title.end),
    null => null,
  };
  final (definedTitle, lineEnd) = end != null
      ? (title!.value, end)
      : (null, _lineEnd(text, beforeTitle));
  if (lineEnd == null || normalizeLabel(label.value).isEmpty) return null;
  return (
    value: (
      label: label.value,
      destination: destination.value,
      title: definedTitle,
    ),
    end: lineEnd,
  );
}

/// The index after spaces, tabs and a line break at [start], if only
/// they are there before the line ends.
int? _lineEnd(String text, int start) =>
    _spaceAtLineEnd.matchAsPrefix(text, start)?.end;

final _label = RegExp(r'\[(?:[^\\\[\]]|\\.){0,1000}\]', dotAll: true);
final _bracedDestination = RegExp(r'<(?:[^<>\n\\\x00]|\\.)*>');
final _spaceOrControl = RegExp(r'[\x00-\x20\x7f]');
final _title = RegExp(
  r'''"(?:\\.|[^"\\\x00])*"|'(?:\\.|[^'\\\x00])*'|\((?:\\.|[^()\\\x00])*\)''',
  dotAll: true,
);
final _spaceNewline = RegExp(r'[ \t]*(?:\n[ \t]*)?');
final _spaceAtLineEnd = RegExp(r'[ \t]*(?:\n|$)');
