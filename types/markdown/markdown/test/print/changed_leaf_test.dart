import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/print/changed_leaf.dart';
import 'package:truce_markdown/src/print/printer.dart';

void main() {
  /// [text] read and printed, and its leaves in order.
  (PrintedMarkdown, List<NodeId>) printed(String text) {
    final read = loadMarkdown(text);
    return (
      printMarkdown(read.doc, read.origin),
      [for (final leaf in leavesIn(read.doc.root)) leaf.id],
    );
  }

  const shop = '# Shop\n\n- [ ] milk\n- [ ] eggs\n- [ ] oats\n\nend';

  test('nothing changed: no leaf', () {
    final (before, _) = printed(shop);
    final (after, _) = printed(shop);
    expect(firstChangedLeaf(before, after), isNull);
  });

  test('the leaf on the first changed line, also of a tree read anew', () {
    final (before, _) = printed(shop);
    for (final (text, leaf) in [
      (shop.replaceFirst('eggs', 'egg'), 2),
      (shop.replaceFirst('[ ] oats', '[x] oats'), 3),
      (shop.replaceFirst('- [ ] eggs', '  - [ ] eggs'), 2),
      (shop.replaceFirst('- [ ] eggs\n', ''), 2),
    ]) {
      final (after, leaves) = printed(text);
      expect(firstChangedLeaf(before, after), leaves[leaf], reason: text);
    }
  });

  test('lines gone at the end: the last leaf', () {
    final (before, _) = printed('a\n\nb\n\nc');
    final (after, leaves) = printed('a\n\nb');
    expect(firstChangedLeaf(before, after), leaves.last);
  });
}
