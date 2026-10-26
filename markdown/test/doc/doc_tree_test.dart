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
}
