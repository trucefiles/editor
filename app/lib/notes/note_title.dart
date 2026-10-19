import 'package:truce_core/truce_core.dart';

import 'note_file_name.dart';

/// Displayed title: the first level-1 heading, else the file name without
/// its extension.
String noteTitle(String text, RelPath path) {
  final document = MarkdownLines.parse(text);
  for (final line in document.lines) {
    if (_titleOf(document, line) case final title?) return title;
  }
  return splitFileName(path.name).base;
}

/// The text of [line] if it is a level-1 heading with text.
String? _titleOf(MarkdownLines document, MarkdownLine line) {
  if (document.kindOf(line) != LineKind.plain) return null;
  if (headingMark(line.raw) case (level: 1, :final textStart)) {
    final title = line.raw.substring(textStart).trim();
    if (title.isNotEmpty) return title;
  }
  return null;
}

/// The first non-empty line of [text] as plain words, without Markdown
/// block markers or a checkbox; empty if there is none. Names new notes.
String noteTitleLine(String text) {
  final line = MarkdownLines.parse(text).lines
      .where((line) => line.raw.trim().isNotEmpty)
      .firstOrNull;
  if (line == null) return '';
  if (line.isCheckbox) return line.text.trim();
  return _withoutBlockMarkers(line.raw, bullet: '').trim();
}

/// Up to [maxLines] non-empty lines after the title heading, for cards, in
/// file order: checkbox items as `☐ text` or `☑ text` at their level, other
/// lines without their Markdown block markers. With [hideDone], checked
/// items and their subitems are left out and counted in a last line, e.g.
/// `+ 3 done`.
String notePreview(String text, {int maxLines = 6, bool hideDone = false}) {
  final list = MarkdownLines.parse(text);
  final done = hideDone ? list.doneIds : const <LineId>{};
  final shown = list.lines
      .where((line) => line.raw.trim().isNotEmpty && !done.contains(line.id))
      .skipWhile((line) => _titleOf(list, line) != null)
      .map(
        (line) => line.isCheckbox
            ? '${'  ' * list.depthOf(line)}${line.isChecked ? '☑' : '☐'} '
                  '${line.text}'
            : _withoutBlockMarkers(line.raw, bullet: '• '),
      );
  final checked = list.lines.where(
    (line) => done.contains(line.id) && line.isChecked,
  );
  if (checked.isEmpty) return shown.take(maxLines).join('\n');
  return [...shown.take(maxLines - 1), '+ ${checked.length} done'].join('\n');
}

/// [line] without its heading and quote markers; a bullet item's marker
/// becomes [bullet], after its indent.
String _withoutBlockMarkers(String line, {required String bullet}) {
  var rest = line;
  if (headingMark(rest) case (level: _, :final textStart)) {
    rest = rest.substring(textStart);
  }
  if (quoteTextStart(rest) case final textStart?) {
    rest = rest.substring(textStart);
  }
  if (itemMark(rest) case (
    kind: ListKind.bullet,
    :final markStart,
    :final textStart,
  )) {
    return '${rest.substring(0, markStart)}$bullet${rest.substring(textStart)}';
  }
  return rest;
}
