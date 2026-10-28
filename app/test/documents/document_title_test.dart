import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document_title.dart';

import '../support.dart';

// How titles and first lines are read is tested in the markdown
// package (`DocumentSummary`); here only what the app adds.
void main() {
  final types = appDocumentTypes();
  String titleOf(String text, String name) =>
      documentTitle(text, path(name), types.of(path(name))!);

  test('documentTitle takes the first level-1 heading', () {
    expect(titleOf('intro\n## Sub\n# Shopping \n# Later', 'a.md'), 'Shopping');
  });

  test('documentTitle falls back to the file name without extension', () {
    expect(titleOf('## Sub\ntext', 'lists/Groceries.md'), 'Groceries');
  });

  test('documentTitleLine takes the first line as plain words', () {
    expect(
      documentTitleLine('\n  Milk and eggs \nmore', types.forNew),
      'Milk and eggs',
    );
    expect(documentTitleLine(' \n', types.forNew), '');
  });

  test('documentTitleLine reads the text by its type', () {
    const text = '# Shopping\nmilk';

    expect(documentTitleLine(text, types.forNew), 'Shopping');
    expect(documentTitleLine(text, types.of(path('a.txt'))!), '# Shopping');
  });

  test('documentTitle of a text file is its first line as written', () {
    expect(titleOf('# Shopping\nmilk', 'a.txt'), '# Shopping');
  });
}
