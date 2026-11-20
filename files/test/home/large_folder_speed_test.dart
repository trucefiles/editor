import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

import '../support/fake_shown_type.dart';

/// How many files a big photo folder holds, well past a normal one: a
/// camera folder of years of photos.
const _files = 50000;

/// The budget for what each listing of such a folder costs the screens:
/// the files shown, newest first. It took about 12 ms here; CI runners
/// are about three times slower, so this leaves a wide margin.
const _listBudget = Duration(milliseconds: 100);

/// The budget for Home's lists of those files: the filter, Recently
/// edited and All files by name. It took about 55 ms here; the same
/// margin as [_listBudget].
const _homeBudget = Duration(milliseconds: 400);

final _types = ShownFileTypes([const FakeShownType()]);

final _folder = Folder(
  id: folderId('camera'),
  name: 'Camera',
  color: 'teal',
  location: 'fake:camera',
);

/// [_files] files across 50 subfolders, a minute apart.
FolderState _listing() {
  final start = DateTime(2020);
  final entries = [
    for (var index = 0; index < _files; index++)
      FileEntry(
        path('${index % 50}/IMG_$index.md'),
        version: FileVersion(index),
        modified: start.add(Duration(minutes: index)),
      ),
  ];
  return FolderState({
    _folder.id: Listed(
      FolderFound(
        files: {for (final entry in entries) entry.path: entry},
        conflicts: const {},
        subfolders: {for (var index = 0; index < 50; index++) path('$index')},
        unreadable: const [],
        marks: MarksFiles.none,
      ),
      listedAt: Moment.now(),
    ),
  });
}

/// The fastest of five runs of [run].
Duration _fastest(void Function() run) => [
  for (var round = 0; round < 5; round++)
    () {
      final watch = Stopwatch()..start();
      run();
      return watch.elapsed;
    }(),
].min;

void main() {
  final state = _listing();
  FolderFiles listed() => FolderFiles(state, folders: [_folder], types: _types);

  test('a folder of $_files files is listed for the screens within budget', () {
    expect(listed().files, hasLength(_files));

    final took = _fastest(() => listed().files);

    expect(took, lessThan(_listBudget));
  });

  test("Home's lists of $_files files come within budget", () {
    final shown = listed();
    final files = shown.files;
    late Recent recent;
    late List<FileSection> sections;

    final took = _fastest(() {
      final filtered = HomeFilter(folders: {_folder.id}).of(files);
      recent = recentOf(
        filtered,
        isPinned: (file) => false,
        counts: (file) => true,
        count: 20,
      );
      sections = sectionsByName(filtered, folders: [_folder]);
      shown.findFile(files.last.key);
    });

    expect(recent.newest, hasLength(20));
    expect(sections, hasLength(50));
    expect(took, lessThan(_homeBudget));
  });
}
