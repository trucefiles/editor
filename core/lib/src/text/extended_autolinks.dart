/// GitHub Flavored Markdown's extended autolinks: `www.` addresses,
/// `http://`, `https://` and `ftp://` urls and email addresses in plain
/// text. The one owner of these rules.
library;

/// An autolink found in text: from [start] to [end], leading to
/// [destination].
typedef FoundLink = ({int start, int end, String destination});

/// The extended autolinks in [text] from [start] to [end], in order.
List<FoundLink> findExtendedAutolinks(String text, int start, int end) {
  final found = <FoundLink>[];
  var index = start;
  while (index < end) {
    final link = _urlAt(text, index, end) ?? _emailAt(text, index, end, start);
    if (link == null) {
      index++;
      continue;
    }
    found.add(link);
    index = link.end;
  }
  return found;
}

/// A `www.` or scheme url starting at [index], where one may start: at a
/// line's start, after whitespace, or after `*`, `_`, `~` or `(`.
FoundLink? _urlAt(String text, int index, int end) {
  if (index > 0 && !_mayPrecede.hasMatch(text[index - 1])) return null;
  final rest = text.substring(index, end);
  final scheme = _scheme.matchAsPrefix(rest);
  final www = rest.startsWith('www.');
  if (scheme == null && !www) return null;
  final domainStart = scheme?.end ?? 0;
  final domainEnd = _domainEnd(rest, domainStart);
  if (!_validDomain(rest.substring(domainStart, domainEnd))) return null;
  final pathEnd = _pathEnd(rest, domainEnd);
  final linkEnd = _trimmedEnd(rest.substring(0, pathEnd));
  if (linkEnd <= domainStart) return null;
  final link = rest.substring(0, linkEnd);
  return (
    start: index,
    end: index + linkEnd,
    destination: www && scheme == null ? 'http://$link' : link,
  );
}

/// An email address whose `@` is at [index]; its local part may start
/// no earlier than [start].
FoundLink? _emailAt(String text, int index, int end, int start) {
  if (text[index] != '@') return null;
  var localStart = index;
  while (localStart > start && _localChar.hasMatch(text[localStart - 1])) {
    localStart--;
  }
  if (localStart == index) return null;
  var domainEnd = index + 1;
  while (domainEnd < end && _emailDomainChar.hasMatch(text[domainEnd])) {
    domainEnd++;
  }
  while (domainEnd > index + 1 && text[domainEnd - 1] == '.') {
    domainEnd--;
  }
  final domain = text.substring(index + 1, domainEnd);
  if (!domain.contains('.') || domain.endsWith('-') || domain.endsWith('_')) {
    return null;
  }
  final address = text.substring(localStart, domainEnd);
  return (start: localStart, end: domainEnd, destination: 'mailto:$address');
}

int _domainEnd(String rest, int from) {
  var index = from;
  while (index < rest.length && _domainChar.hasMatch(rest[index])) {
    index++;
  }
  return index;
}

/// Segments of letters, digits, `_` and `-` separated by periods, at least
/// one period, no `_` in the last two segments.
bool _validDomain(String domain) {
  final segments = domain.replaceAll(_trailingPeriods, '').split('.');
  return segments.length >= 2 &&
      segments.reversed.take(2).every((segment) => !segment.contains('_'));
}

final _trailingPeriods = RegExp(r'\.+$');

int _pathEnd(String rest, int from) {
  var index = from;
  while (index < rest.length && !_pathStop.hasMatch(rest[index])) {
    index++;
  }
  return index;
}

/// The end of [link] without trailing punctuation, unmatched closing
/// parentheses or a trailing character reference.
int _trimmedEnd(String link) {
  var end = link.length;
  while (end > 0) {
    final last = link[end - 1];
    if ('?!.,:*_~'.contains(last)) {
      end--;
    } else if (last == ')' && _unmatchedClosing(link.substring(0, end))) {
      end--;
    } else if (last == ';') {
      final entity = _trailingEntity.firstMatch(link.substring(0, end));
      if (entity == null) break;
      end = entity.start;
    } else {
      break;
    }
  }
  return end;
}

bool _unmatchedClosing(String link) =>
    ')'.allMatches(link).length > '('.allMatches(link).length;

final _mayPrecede = RegExp(r'[\s*_~(]');
final _scheme = RegExp(r'(?:https?|ftp)://');
final _domainChar = RegExp(r'[A-Za-z0-9_.\-]');
final _emailDomainChar = RegExp(r'[A-Za-z0-9_.\-]');
final _localChar = RegExp(r'[A-Za-z0-9.+_\-]');
final _pathStop = RegExp(r'[\s<]');
final _trailingEntity = RegExp(r'&[A-Za-z0-9]+;$');
