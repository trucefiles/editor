import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/load.dart';
import '../edit/commands/items.dart';
import '../tree/inlines.dart';
import '../visible/visible_text.dart';

/// What lists of documents show of one: its title and a preview of its
/// first lines, as plain words. Read from one load of the text; each
/// part is worked out when first asked.
final class DocumentSummary {
  /// The summary of [text], with previews of up to [maxLines] lines.
  DocumentSummary.of(String text, {this.maxLines = 10})
    : _doc = loadMarkdown(text).doc;

  final DocTree _doc;

  /// The most lines a preview holds.
  final int maxLines;

  late final HeadingNode? _title = _titleOf(_doc);

  /// The first level-1 heading with text in no other block; `null` if
  /// there is none.
  late final String? title = switch (_title) {
    final title? => _plain(title.text).trim(),
    null => null,
  };

  /// The first line with text, without marks or a box; empty if there is
  /// none. Names new documents.
  late final String firstLine =
      leavesIn(_doc.root)
          .where((leaf) => leaf is! DividerNode)
          .expand((leaf) => _textOf(leaf).split('\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .firstOrNull ??
      '';

  /// Up to [maxLines] lines after the title, in file order: items at
  /// their level, boxes as `☐ text` or `☑ text`, bullets as `• text`,
  /// numbers as `2. text`, a divider as a line.
  late final String preview = _preview(
    _doc,
    _title,
    maxLines: maxLines,
    hideDone: false,
  );

  /// [preview] without the checked items at a list's top level (those a
  /// Done section shows) and their subitems, counted in a last line, e.g.
  /// `+ 3 done`.
  late final String previewHidingDone = _preview(
    _doc,
    _title,
    maxLines: maxLines,
    hideDone: true,
  );
}

HeadingNode? _titleOf(DocTree doc) => doc.root.children
    .whereType<HeadingNode>()
    .where((heading) => heading.level == 1 && _plain(heading.text).trim() != '')
    .firstOrNull;

String _preview(
  DocTree doc,
  HeadingNode? title, {
  required int maxLines,
  required bool hideDone,
}) {
  final done = hideDone ? checkedItems(doc) : const <ItemNode>[];
  final hidden = {for (final item in done) item.id};
  final lines = _Lines(hidden)
      .of(doc.root, depth: 0)
      .skipWhile((line) => title != null && line.leaf != title.id)
      .skip(title == null ? 0 : 1)
      .map((line) => line.text);
  if (done.isEmpty) return lines.take(maxLines).join('\n');
  return [...lines.take(maxLines - 1), '+ ${done.length} done'].join('\n');
}

/// One line of a preview, and the leaf it shows.
typedef _Line = ({NodeId leaf, String text});

/// The preview lines of a document, without the items [_hidden].
final class _Lines {
  _Lines(this._hidden);

  final Set<NodeId> _hidden;

  Iterable<_Line> of(DocBlock block, {required int depth, String? marker}) =>
      switch (block) {
        final ListNode list =>
          list.items.indexed
              .where((entry) => !_hidden.contains(entry.$2.id))
              .expand((entry) => _item(list, entry.$1, entry.$2, depth: depth)),
        DocContainer(:final children) => children.expand(
          (child) => of(child, depth: depth),
        ),
        final DocLeaf leaf => _leaf(leaf, depth: depth, marker: marker),
      };

  Iterable<_Line> _item(
    ListNode list,
    int index,
    ItemNode item, {
    required int depth,
  }) {
    final marker = switch ((item.checked, list.numberAt(index))) {
      (true, _) => '☑ ',
      (false, _) => '☐ ',
      (null, final number?) => '$number. ',
      (null, null) => '• ',
    };
    return item.children.indexed.expand(
      (entry) => switch (entry) {
        (_, final ListNode sublist) => of(sublist, depth: depth + 1),
        (0, final child) => of(child, depth: depth, marker: marker),
        (_, final child) => of(child, depth: depth),
      },
    );
  }

  Iterable<_Line> _leaf(
    DocLeaf leaf, {
    required int depth,
    required String? marker,
  }) {
    final lines = _textOf(leaf)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return [
      for (final (index, line) in lines.indexed)
        (
          leaf: leaf.id,
          text: '${'  ' * depth}${index == 0 ? marker ?? '' : ''}$line',
        ),
    ];
  }
}

/// What [leaf] shows as plain words; nothing for HTML, link definitions
/// or front matter.
String _textOf(DocLeaf leaf) => switch (leaf) {
  TextNode(:final text) => _plain(text),
  CodeNode(:final code) => code,
  DividerNode() => _divider,
  TableNode(:final raw) => raw,
  RawNode() => '',
};

/// [text] as plain words, in its lines as in the file: an image as its
/// description, inline HTML left out.
String _plain(VisibleText text) => text.pieces
    .map(
      (piece) => switch (piece) {
        ObjectPiece(inline: final ImageInline image) => image.description,
        ObjectPiece() => '',
        SoftBreakPiece() => '\n',
        _ => piece.shown,
      },
    )
    .join();

/// A divider in a preview.
const _divider = '─────';
