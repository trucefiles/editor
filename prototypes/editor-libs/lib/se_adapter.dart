import 'package:super_editor/super_editor.dart';

import 'checklist.dart';

/// PROTOTYPE: super_editor as view/input on top of [Checklist].
///
/// The library edits its own document; after each transaction the document
/// is read back as library-neutral [Block]s and our model writes the lines.
class SeChecklist {
  SeChecklist(String text, {this.shownFilter}) : _list = Checklist.parse(text) {
    document = MutableDocument(nodes: _nodes());
    composer = MutableDocumentComposer();
    editor = Editor(
      editables: {
        Editor.documentKey: document,
        Editor.composerKey: composer,
      },
      requestHandlers: List.from(defaultRequestHandlers),
      // No markdown shortcut conversions: lines stay as typed.
      reactionPipeline: [UpdateSubTaskIndentAfterTaskDeletionReaction()],
    );
    editor.addListener(FunctionalEditListener((_) => _readBack()));
  }

  /// Which lines are shown; all if null (e.g. open items only).
  final bool Function(ChecklistLine line, Checklist list)? shownFilter;

  late final MutableDocument document;
  late final MutableDocumentComposer composer;
  late final Editor editor;
  Checklist _list;
  final _aliases = <String, int>{};
  final writes = <String>[];

  String get text => _list.text;

  bool _isShown(ChecklistLine line) => shownFilter?.call(line, _list) ?? true;

  List<DocumentNode> _nodes() => [
    for (final line in _list.lines)
      if (_isShown(line))
        line.isItem
            ? TaskNode(
                id: '${line.id}',
                text: AttributedText(line.text),
                isComplete: line.isChecked,
                indent: _list.depthOf(line),
              )
            : ParagraphNode(id: '${line.id}', text: AttributedText(line.raw)),
  ];

  void _readBack() {
    final blocks = [
      for (final node in document)
        switch (node) {
          TaskNode() => ItemBlock(
            node.id,
            checked: node.isComplete,
            depth: node.indent,
            text: node.text.toPlainText(),
          ),
          TextNode() => TextBlock(node.id, node.text.toPlainText()),
          _ => throw StateError('unsupported node ${node.runtimeType}'),
        },
    ];
    final shown = {
      for (final line in _list.lines)
        if (_isShown(line)) line.id,
    };
    final (list, newIds) = _list.applyBlocks(
      blocks,
      shown: shown,
      aliases: _aliases,
    );
    _aliases.addAll(newIds);
    if (list.text == _list.text) {
      _list = list;
      return;
    }
    _list = list;
    writes.add(list.text);
  }
}
