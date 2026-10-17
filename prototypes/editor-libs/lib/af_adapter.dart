import 'package:appflowy_editor/appflowy_editor.dart';

import 'checklist.dart';

/// PROTOTYPE: AppFlowy Editor as view/input on top of [Checklist].
const lineIdKey = 'lineId';

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
        attributes: {...node.attributes, lineIdKey: '${line.id}'},
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
    final seen = <String>{};
    void walk(Node node, int depth) {
      for (final child in node.children) {
        final text = child.delta?.toPlainText() ?? '';
        final lineId = child.attributes[lineIdKey] as String?;
        // A node copied from another (split) carries the same line id;
        // only the first one is that line.
        final id = lineId != null && seen.add(lineId) ? lineId : child.id;
        blocks.add(switch (child.type) {
          'todo_list' => ItemBlock(
            id,
            checked: child.attributes['checked'] == true,
            depth: depth,
            text: text,
          ),
          'paragraph' => TextBlock(id, text),
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
