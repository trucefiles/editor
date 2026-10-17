import 'package:appflowy_editor/appflowy_editor.dart';

import 'checklist.dart';

/// PROTOTYPE: AppFlowy Editor as view/input on top of [Checklist].
class AfChecklist {
  AfChecklist(String text) : _list = Checklist.parse(text) {
    editorState = EditorState(document: Document(root: _root()));
    editorState.transactionStream.listen((value) {
      if (value.$1 == TransactionTime.after) _readBack();
    });
  }

  late final EditorState editorState;
  Checklist _list;
  final _aliases = <String, int>{};
  final writes = <String>[];

  String get text => _list.text;

  /// Nesting is a tree in AppFlowy; our lines are flat with indents.
  Node _root() {
    final root = pageNode(children: []);
    final stack = <(int, Node)>[(-1, root)];
    for (final line in _list.lines) {
      final depth = line.isItem ? _list.depthOf(line) : 0;
      final node = line.isItem
          ? (todoListNode(checked: line.isChecked, text: line.text)..id)
          : paragraphNode(text: line.raw);
      final withId = Node(
        type: node.type,
        id: '${line.id}',
        attributes: node.attributes,
      );
      while (stack.last.$1 >= depth) {
        stack.removeLast();
      }
      stack.last.$2.insert(withId);
      if (line.isItem) stack.add((depth, withId));
    }
    return root;
  }

  void _readBack() {
    final blocks = <Block>[];
    void walk(Node node, int depth) {
      for (final child in node.children) {
        final text = child.delta?.toPlainText() ?? '';
        blocks.add(switch (child.type) {
          'todo_list' => ItemBlock(
            child.id,
            checked: child.attributes['checked'] == true,
            depth: depth,
            text: text,
          ),
          'paragraph' => TextBlock(child.id, text),
          _ => throw StateError('unsupported ${child.type}'),
        });
        walk(child, depth + 1);
      }
    }

    walk(editorState.document.root, 0);
    final (list, newIds) = _list.applyBlocks(
      blocks,
      shown: {for (final l in _list.lines) l.id},
      aliases: _aliases,
    );
    _aliases.addAll(newIds);
    final changed = list.text != _list.text;
    _list = list;
    if (changed) writes.add(list.text);
  }
}
