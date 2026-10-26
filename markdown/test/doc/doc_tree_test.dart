import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/load.dart';

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
}
