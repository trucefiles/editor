import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  Folder folder(String name) =>
      Folder(id: folderId(name), name: name, color: 'teal', location: name);
  final work = folder('work');
  final home = folder('home');
  const other = FileType('other');

  ListedFile file(Folder folder, String name) => ListedFile(
    folder: folder,
    path: path(name),
    type: const FakeFileType(),
    version: const FileVersion(0),
    modified: DateTime(2026),
  );
  final atWork = file(work, 'a.md');
  final atHome = file(home, 'b.md');
  final files = [atWork, atHome];

  FolderConflict orphan(Folder folder, String name) => FolderConflict(
    folder,
    Conflict(mainPath: path(name), main: null, copies: const []),
  );
  final known = orphan(work, 'a.md');
  final unknown = orphan(work, 'b.unknown');
  final orphans = [known, unknown];
  FileType? typeOf(RelPath path) =>
      path.name.endsWith('.md') ? FakeFileType.id : null;

  group('of', () {
    test('every file when nothing is picked', () {
      expect(const HomeFilter().of(files), files);
    });

    test('the files of the folders picked', () {
      expect(HomeFilter(folders: {home.id}).of(files), [atHome]);
      expect(HomeFilter(folders: {home.id, work.id}).of(files), files);
    });

    test('the files of the types picked', () {
      expect(const HomeFilter(types: {FakeFileType.id}).of(files), files);
      expect(const HomeFilter(types: {other}).of(files), isEmpty);
      expect(
        const HomeFilter(types: {other, FakeFileType.id}).of(files),
        files,
      );
    });

    test('the files of both a folder and a type picked', () {
      expect(
        HomeFilter(
          folders: {work.id},
          types: const {FakeFileType.id},
        ).of(files),
        [atWork],
      );
    });
  });

  group('orphansOf', () {
    test('every orphan when nothing is picked, of a known type or not', () {
      expect(const HomeFilter().orphansOf(orphans, typeOf: typeOf), orphans);
    });

    test('by the type of their main file; none of no known type', () {
      expect(
        const HomeFilter(types: {FakeFileType.id})
            .orphansOf(orphans, typeOf: typeOf),
        [known],
      );
    });

    test('by folder', () {
      expect(
        HomeFilter(folders: {home.id}).orphansOf(orphans, typeOf: typeOf),
        isEmpty,
      );
    });
  });
}
