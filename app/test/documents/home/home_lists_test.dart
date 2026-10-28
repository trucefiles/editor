import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/home/home_lists.dart';

import '../../support.dart';

void main() {
  final work = folderAt(Directory('/work'), id: 'work').copyWith(name: 'Work');
  final home = folderAt(Directory('/home'), id: 'home').copyWith(name: 'Home');

  Document doc(String name, {int day = 1}) =>
      listedDocument(work, name: name, modified: DateTime(2026, 1, day));

  group('recentOf', () {
    test('every pinned document, then the newest others up to the count', () {
      final pinned = doc('old.md');
      final documents = [doc('c.md'), doc('b.md'), pinned, doc('a.md')];

      final recent = recentOf(
        documents,
        isPinned: (document) => document == pinned,
        count: 2,
      );

      expect(recent.pinned, [pinned]);
      expect(recent.newest, [documents[0], documents[1]]);
    });

    test('all others when fewer than the count', () {
      final documents = [doc('a.md')];

      expect(
        recentOf(documents, isPinned: (_) => false, count: 50).newest,
        documents,
      );
    });
  });

  group('sectionsByName', () {
    test('a section per folder and subfolder, by name', () {
      final top = doc('Top.md');
      final b = doc('work/b.md');
      final a10 = doc('work/A 10.md');
      final a9 = doc('work/a 9.md');
      final atHome = listedDocument(home, name: 'x.md');

      final sections = sectionsByName([b, top, atHome, a10, a9]);

      expect(
        [
          for (final section in sections)
            (section.folder.id, section.subfolder?.value),
        ],
        [('home', null), ('work', null), ('work', 'work')],
      );
      expect(sections.last.documents, [a9, a10, b]);
    });
  });

  test('filteredBy keeps the documents of the folder chosen, or all', () {
    final atWork = doc('a.md');
    final atHome = listedDocument(home, name: 'b.md');

    expect(filteredBy('home', [atWork, atHome]), [atHome]);
    expect(filteredBy(null, [atWork, atHome]), [atWork, atHome]);
  });
}
