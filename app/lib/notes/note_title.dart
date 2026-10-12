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

/// Up to [maxLines] non-empty lines after the title heading, for cards.
String notePreview(String text, {int maxLines = 6}) => text
    .split('\n')
    .where((line) => line.trim().isNotEmpty)
    .skipWhile((line) => _heading.hasMatch(line))
    .take(maxLines)
    .join('\n');
