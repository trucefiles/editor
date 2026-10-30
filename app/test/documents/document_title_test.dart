import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart' show FileTypeSupport;
import 'package:truce_documents/truce_documents.dart';

import '../support.dart';

// How titles and first lines are read is tested in the markdown
// package (`DocumentSummary`); here only what the app adds.
void main() {
  final types = appDocumentTypes();
  String titleOf(String text, String name) =>
      documentTitle(text, path(name), types.of(path(name))!.support);

  test('documentTitle takes the first level-1 heading', () {
    expect(titleOf('intro\n## Sub\n# Shopping \n# Later', 'a.md'), 'Shopping');
  });

  test('documentTitle falls back to the file name without extension', () {
    expect(titleOf('## Sub\ntext', 'lists/Groceries.md'), 'Groceries');
  });

  String firstLine(String text, FileTypeSupport<Object?> support) =>
      support.summary(text, maxLines: 0).firstLine;

  test('the first line names a document, as plain words', () {
    expect(
      firstLine('\n  Milk and eggs \nmore', types.forNew.support),
      'Milk and eggs',
    );
    expect(firstLine(' \n', types.forNew.support), '');
  });

  test('the first line is read by the type', () {
    const text = '# Shopping\nmilk';

    expect(firstLine(text, types.forNew.support), 'Shopping');
    expect(firstLine(text, types.of(path('a.txt'))!.support), '# Shopping');
  });

  test('documentTitle of a text file is its first line as written', () {
    expect(titleOf('# Shopping\nmilk', 'a.txt'), '# Shopping');
  });
}
