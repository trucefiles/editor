import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_files/truce_files.dart';

import '../../support.dart';

void main() {
  final work = folderAt(Directory('/work'), id: 'work').copyWith(name: 'Work');
  final home = folderAt(Directory('/home'), id: 'home').copyWith(name: 'Home');

  ListedFile doc(String name, {int day = 1}) =>
      listedFile(work, name: name, modified: DateTime(2026, 1, day));

  group('recentOf', () {
    test('every pinned document, then the newest others up to the count', () {
      final pinned = doc('old.md');
      final files = [doc('c.md'), doc('b.md'), pinned, doc('a.md')];

      final recent = recentOf(
        files,
        isPinned: (file) => file == pinned,
        count: 2,
      );

      expect(recent.pinned, [pinned]);
      expect(recent.newest, [files[0], files[1]]);
      expect(recent.hidesSome, isTrue);
    });

    test('all others when fewer than the count, hiding none', () {
      final files = [doc('a.md')];

      final recent = recentOf(files, isPinned: (_) => false, count: 50);

      expect(recent.newest, files);
      expect(recent.hidesSome, isFalse);
    });

    test('hides none when the others fill the count exactly', () {
      final pinned = doc('old.md');
      final files = [doc('b.md'), pinned, doc('a.md')];

      final recent = recentOf(files, isPinned: (f) => f == pinned, count: 2);

      expect(recent.hidesSome, isFalse);
    });
  });

  group('sectionsByName', () {
    test('a section per folder and subfolder, by name', () {
      final top = doc('Top.md');
      final b = doc('work/b.md');
      final a10 = doc('work/A 10.md');
      final a9 = doc('work/a 9.md');
      final atHome = listedFile(home, name: 'x.md');

      final sections = sectionsByName([b, top, atHome, a10, a9]);

      expect(
        [
          for (final section in sections)
            (section.folder.id, section.subfolder?.value),
        ],
        [
          (folderId('home'), null),
          (folderId('work'), null),
          (folderId('work'), 'work'),
        ],
      );
      expect(sections.last.files, [a9, a10, b]);
    });
  });
}
