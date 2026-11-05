import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

void main() {
  test('a document is empty with no block or one empty paragraph', () {
    expect(loadMarkdown('').doc.isEmpty, isTrue);
    expect(loadMarkdown('\n\n').doc.isEmpty, isTrue);
    expect(loadMarkdown('a').doc.isEmpty, isFalse);
    expect(loadMarkdown('- ').doc.isEmpty, isFalse);
    expect(loadMarkdown('---').doc.isEmpty, isFalse);
  });

  test('a document has checkboxes with a checklist item anywhere', () {
    expect(loadMarkdown('- a\n  - [ ] b').doc.hasCheckboxes, isTrue);
    expect(loadMarkdown('> - [x] a').doc.hasCheckboxes, isTrue);
    expect(loadMarkdown('- a\n1. b').doc.hasCheckboxes, isFalse);
  });

  group('a tree holds the same as another', () {
    final doc = loadMarkdown('# Shop\n\n- [ ] milk\n- [x] eggs').doc;
    final item = nodesIn(doc.root).whereType<ItemNode>().first;
    final milk = leavesIn(item).whereType<ParagraphNode>().single;

    test('with its nodes built anew alike', () {
      final again = doc
          .withNode(milk.withText(VisibleText(milk.text.pieces)))
          .withNode(item.withBox(false));
      expect(identical(again.root, doc.root), isFalse);
      expect(again.holdsSameAs(doc), isTrue);
    });

    test('not with other text or a box changed', () {
      expect(
        doc
            .withNode(milk.withText(VisibleText([TextPiece('oats')])))
            .holdsSameAs(doc),
        isFalse,
      );
      expect(doc.withNode(item.withBox(true)).holdsSameAs(doc), isFalse);
    });
  });
}
