import 'package:truce_core/truce_core.dart';

import 'note_file_name.dart';

/// Displayed title: the first level-1 heading in no other block, as
/// plain words, else the file name without its extension.
String noteTitle(String text, RelPath path) =>
    noteTitleIn(MarkdownDocument.parse(text), path);

/// [noteTitle] of a parsed [document].
String noteTitleIn(MarkdownDocument document, RelPath path) =>
    switch (_titleOf(document)) {
      final title? => document.plainTextOf(title).trim(),
      null => splitFileName(path.name).base,
    };

/// The first level-1 heading with text in no other block, if any.
HeadingBlock? _titleOf(MarkdownDocument document) => document.root.children
    .whereType<HeadingBlock>()
    .where(
      (heading) =>
          heading.level == 1 && document.plainTextOf(heading).trim().isNotEmpty,
    )
    .firstOrNull;

/// The first non-empty line of [text] as plain words, without Markdown
/// marks or a checkbox; empty if there is none. Names new notes.
String noteTitleLine(String text) {
  final document = MarkdownDocument.parse(text);
  return document.leaves
          .map((leaf) => document.plainTextOf(leaf))
          .expand((text) => text.split('\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .firstOrNull ??
      '';
}

/// Up to [maxLines] non-empty lines of [document] after the title heading,
/// for cards, in file order, as plain words: items at their level,
/// checkbox items as `☐ text` or `☑ text`, bullet items as `• text`. With
/// [hideDone], checked items and their subitems are left out and counted
/// in a last line, e.g. `+ 3 done`.
String notePreviewIn(
  MarkdownDocument document, {
  required int maxLines,
  bool hideDone = false,
}) {
  final outline = document.outline;
  final done = hideDone ? outline.doneIds : const <LineId>{};
  final title = _titleOf(document);
  final shown = document.leaves
      .skipWhile((leaf) => title != null && leaf != title)
      .skip(title == null ? 0 : 1)
      .where((leaf) => !done.contains(leaf.id))
      .expand((leaf) => _previewLines(document, leaf));
  final checked = outline.items.where(
    (item) => item.isChecked && done.contains(item.markerLine),
  );
  if (checked.isEmpty) return shown.take(maxLines).join('\n');
  return [...shown.take(maxLines - 1), '+ ${checked.length} done'].join('\n');
}

/// The non-empty lines of [leaf] for a preview: indented by the items it
/// is in, the item's marker before the first line of the item; a
/// horizontal line drawn as [_rule], so lines that separate show.
Iterable<String> _previewLines(MarkdownDocument document, LeafBlock leaf) {
  final item = document.outline.itemOf(leaf.id);
  final depth = item == null ? 0 : document.outline.depthOf(item);
  final marker = item != null && item.leaves.first == leaf
      ? switch (item.kind) {
          ListKind.checkbox => item.isChecked ? '☑ ' : '☐ ',
          ListKind.bullet => '• ',
          ListKind.numbered => '${document.outline.numberOf(item)}. ',
        }
      : null;
  final text = switch (leaf) {
    RuleBlock() => _rule,
    _ => document.plainTextOf(leaf),
  };
  final lines = text.split('\n').where((line) => line.trim().isNotEmpty);
  return [
    for (final (index, line) in lines.indexed)
      '${'  ' * depth}${index == 0 ? marker ?? '' : ''}${line.trim()}',
  ];
}

/// A horizontal line in a preview.
const _rule = '─────';
