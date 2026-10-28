import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/search/document_search.dart';

import '../support.dart';

final _folder = folderAt(Directory('/documents'));

Document document(String name, String text) =>
    documentOf(_folder, text, name: name, modified: DateTime(2026));

void main() {
  final shopping = document('a.md', '# Shopping\n- [ ] Milk');
  final milk = document('b.md', '# Milk run\nshopping later');
  final other = document('c.md', '# Other\nnothing');
  final documents = [shopping, milk, other];

  test('finds every word, ignoring case', () {
    expect(searchNotes(documents, 'MILK shopping'), [shopping, milk]);
  });

  test('puts title matches first', () {
    expect(searchNotes(documents, 'milk'), [milk, shopping]);
  });

  test('finds a title taken from the file name', () {
    final named = document('Groceries.md', '- [ ] milk');

    expect(searchNotes([named], 'groceries'), [named]);
  });

  test('finds nothing for an empty query', () {
    expect(searchNotes(documents, '  '), isEmpty);
  });
}
