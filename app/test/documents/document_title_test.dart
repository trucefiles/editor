import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document_title.dart';
import 'package:truce_editor/file_types/document_types.dart';

import '../support.dart';

// How titles and first lines are read is tested in the markdown
// package (`DocumentSummary`); here only what the app adds.
void main() {
  test('documentTitle takes the first level-1 heading', () {
    expect(
      documentTitle('intro\n## Sub\n# Shopping \n# Later', path('a.md')),
      'Shopping',
    );
  });

  test('documentTitle falls back to the file name without extension', () {
    expect(
      documentTitle('## Sub\ntext', path('lists/Groceries.md')),
      'Groceries',
    );
  });

  test('documentTitleLine takes the first line as plain words', () {
    expect(
      documentTitleLine('\n  Milk and eggs \nmore', newDocumentType),
      'Milk and eggs',
    );
    expect(documentTitleLine(' \n', newDocumentType), '');
  });

  test('documentTitleLine reads the text by its type', () {
    const text = '# Shopping\nmilk';

    expect(documentTitleLine(text, newDocumentType), 'Shopping');
    expect(
      documentTitleLine(text, documentTypes.of(path('a.txt'))),
      '# Shopping',
    );
  });

  test('documentTitle of a text file is its first line as written', () {
    expect(documentTitle('# Shopping\nmilk', path('a.txt')), '# Shopping');
  });
}
