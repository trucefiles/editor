import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document_settings.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

import '../support.dart';

void main() {
  const shown = DocumentSettings(checkedItems: CheckedItems.inPlace);
  const hidden = DocumentSettings();
  final document = documentOf(
    folderAt(Directory.systemTemp),
    '# Shopping\n- [x] milk\n- [ ] eggs',
  );

  test('shows its title and previews', () {
    expect(document.title, 'Shopping');
    expect(document.preview(shown), '☑ milk\n☐ eggs');
    expect(document.preview(hidden), '☐ eggs\n+ 1 done');
  });

  test('works out its title and previews once', () {
    expect(identical(document.title, document.title), isTrue);
    expect(
      identical(document.preview(hidden), document.preview(hidden)),
      isTrue,
    );
  });

  test('a plain text shows by its own type', () {
    final plain = documentOf(
      folderAt(Directory.systemTemp),
      '# Not a heading\n- [x] milk',
      name: 'a.txt',
    );

    expect(plain.title, '# Not a heading');
    expect(plain.preview(hidden), '- [x] milk');
  });
}
