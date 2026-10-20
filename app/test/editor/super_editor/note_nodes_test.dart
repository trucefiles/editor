import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/super_editor/display_nodes.dart';
import 'package:truce_editor/editor/super_editor/note_nodes.dart';

/// The editor nodes that show a note's display entries.
void main() {
  /// The node of the [index]th entry of [text] in Visual edit.
  DocumentNode nodeAt(String text, {int index = 0}) {
    final document = MarkdownDocument.parse(text);
    final entry = const Arrangement.blocks().of(document)[index];
    final view = switch (entry) {
      LeafEntry(:final leaf) || TableEntry(:final leaf) => LeafView.of(
        document,
        document.leafById(leaf)!,
      ),
      _ => null,
    };
    return nodeOf(entry, view, document);
  }

  test('a block shows as a paragraph of its text, inside its frames', () {
    final node = nodeAt('- a\n  - [x] b', index: 1) as ParagraphNode;

    expect(node.text.toPlainText(), 'b');
    expect(node.getMetadataValue(framesKey), [
      isA<ItemFrame>(),
      isA<ItemFrame>().having((frame) => frame.checked, 'checked', isTrue),
    ]);
  });

  test('a line as it is in the file shows inside no frames', () {
    final document = MarkdownDocument.parse('> q');
    final line = document.lines.single;
    final node = nodeOf(
      LineEntry(line.id),
      RawLineView.of(document, line),
      document,
    );

    expect((node as ParagraphNode).text.toPlainText(), '> q');
    expect(node.getMetadataValue(framesKey), isEmpty);
  });

  test('a table shows drawn', () {
    expect(nodeAt('| a |\n|---|'), isA<DrawnTableNode>());
  });

  test('node ids stay with the first line of what they show', () {
    final document = MarkdownDocument.parse('a\nb');
    final again = document.reparse('a\nbc');
    String idOf(MarkdownDocument document) =>
        nodeIdOf(const Arrangement.blocks().of(document).single);

    expect(idOf(again), idOf(document));
  });
}
