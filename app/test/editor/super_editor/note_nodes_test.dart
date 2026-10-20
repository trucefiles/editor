import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/super_editor/display_nodes.dart';
import 'package:truce_editor/editor/super_editor/note_nodes.dart';

/// The editor nodes that show a note's lines and display entries.
void main() {
  DocumentNode nodeOf(String text, {int index = 0}) {
    final document = MarkdownLines.parse(text);
    final view = LineView.of(document, document.lines[index], blocks: true);
    return lineNode('n', view, AttributedText(view.text));
  }

  test('an item shows as its kind of list node, at its level', () {
    final task = nodeOf('- a\n  - [x] b', index: 1);
    final numbered = nodeOf('3. c');

    expect(task, isA<TaskNode>());
    expect(((task as TaskNode).isComplete, task.indent), (true, 1));
    expect(numbered, isA<ListItemNode>());
    expect(numbered.getMetadataValue(listNumberKey), 3);
  });

  test('other lines show as paragraphs, a quote as one', () {
    final quote = nodeOf('> q') as ParagraphNode;

    expect(
      quote.getMetadataValue(NodeMetadata.blockType),
      blockquoteAttribution,
    );
    expect(
      nodeOf('text').getMetadataValue(NodeMetadata.blockType),
      paragraphAttribution,
    );
  });

  test('only list nodes show an item text after its marker', () {
    expect(showsItemText(nodeOf('- a')), isTrue);
    expect(showsItemText(nodeOf('- [ ] a')), isTrue);
    expect(showsItemText(nodeOf('a')), isFalse);
  });

  test('blockOf reads back what a line node shows', () {
    expect(
      blockOf(nodeOf('  - [x] b\n', index: 0)),
      isA<ItemBlock>()
          .having((block) => block.checked, 'checked', isTrue)
          .having((block) => block.text, 'text', 'b'),
    );
    expect(blockOf(nodeOf('text')), isA<TextBlock>());
  });

  test('display entries show as their display nodes', () {
    final document = MarkdownLines.parse('| a |\n|---|');
    final byId = {for (final line in document.lines) line.id: line};
    final table = TableEntry([for (final line in document.lines) line.id]);

    expect(displayNode(table, byId), isA<DrawnTableNode>());
  });
}
