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
/// lines without their Markdown block markers. With [hideDone], checked
/// items and their subitems are left out and counted in a last line, e.g.
/// `+ 3 done`.
String notePreview(String text, {int maxLines = 6, bool hideDone = false}) {
  final list = Checklist.parse(text);
  final done = hideDone ? list.doneIds : const <int>{};
  final shown = list.lines
      .where((line) => line.raw.trim().isNotEmpty && !done.contains(line.id))
      .skipWhile((line) => _heading.hasMatch(line.raw))
      .map(
        (line) => line.isItem
            ? '${'  ' * list.depthOf(line)}${line.isChecked ? '☑' : '☐'} '
                  '${line.text}'
            : _withoutBlockMarkers(line.raw),
      );
  final checked = list.lines.where(
    (line) => done.contains(line.id) && line.isChecked,
  );
  if (checked.isEmpty) return shown.take(maxLines).join('\n');
  return [...shown.take(maxLines - 1), '+ ${checked.length} done'].join('\n');
}

final _headingMarker = RegExp(r'^\s*#{1,6}[ \t]+');
final _quoteMarker = RegExp(r'^\s*>[ \t]?');
final _bulletMarker = RegExp(r'^(\s*)[-*+][ \t]+');

/// [line] without heading, quote and bullet markers; bullets become `•`.
String _withoutBlockMarkers(String line) => line
    .replaceFirst(_headingMarker, '')
    .replaceFirst(_quoteMarker, '')
    .replaceFirstMapped(_bulletMarker, (match) => '${match[1]}• ');
