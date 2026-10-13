import 'package:truce_core/truce_core.dart';

final _heading = RegExp(r'^#[ \t]+(.*\S)', multiLine: true);

/// Displayed title: the first level-1 heading, else the file name without
/// its extension.
String noteTitle(String text, RelPath path) {
  if (_heading.firstMatch(text) case final match?) return match.group(1)!;
  final name = path.name;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

/// Up to [maxLines] non-empty lines after the title heading, for cards, in
/// file order: checkbox items as `☐ text` or `☑ text` at their level, other
/// lines without their Markdown block markers.
String notePreview(String text, {int maxLines = 6}) {
  final list = Checklist.parse(text);
  return list.lines
      .where((line) => line.raw.trim().isNotEmpty)
      .skipWhile((line) => _heading.hasMatch(line.raw))
      .take(maxLines)
      .map(
        (line) => line.isItem
            ? '${'  ' * list.depthOf(line)}${line.isChecked ? '☑' : '☐'} '
                  '${line.text}'
            : _withoutBlockMarkers(line.raw),
      )
      .join('\n');
}

final _headingMarker = RegExp(r'^\s*#{1,6}[ \t]+');
final _quoteMarker = RegExp(r'^\s*>[ \t]?');
final _bulletMarker = RegExp(r'^(\s*)[-*+][ \t]+');

/// [line] without heading, quote and bullet markers; bullets become `•`.
String _withoutBlockMarkers(String line) => line
    .replaceFirst(_headingMarker, '')
    .replaceFirst(_quoteMarker, '')
    .replaceFirstMapped(_bulletMarker, (match) => '${match[1]}• ');
