import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

Folder _folder(String id) =>
    Folder(id: folderId(id), name: id, color: 'teal', location: 'fake:$id');

final _home = _folder('home');
final _work = _folder('work');
final _later = DateTime.now().add(const Duration(days: 1));

void main() {
  late Map<FolderId, FileDrafts> drafts;
  late Set<FolderId> refused;
  late PageDraft draft;

  /// Drafts in a place that is a file, so none can be kept there.
  FileDrafts refusing() => FileDrafts(
    Directory('${(File('${tempFolder().path}/file')..createSync()).path}/d'),
  );

  FileDrafts draftsOf(Folder folder) => refused.contains(folder.id)
      ? refusing()
      : drafts.putIfAbsent(
          folder.id,
          () => FileDrafts(Directory('${tempFolder().path}/drafts')),
        );

  Draft named(String name) => Draft(
    DraftHead(id: draft.id, path: path(name), of: const NewFileDraft()),
    Uint8List.fromList([1]),
  );

  Future<List<RelPath>> pathsIn(Folder folder) async => [
    for (final head in await draftsOf(folder).heads(before: _later)) head.path,
  ];

  setUp(() {
    drafts = {};
    refused = {};
    draft = PageDraft(draftsOf);
  });

  test('kept in another folder, it is dropped where it was', () async {
    await draft.keep(_home, named('a.md'));

    expect(await draft.keep(_work, named('b.md')), isTrue);

    expect(await pathsIn(_home), isEmpty);
    expect(await pathsIn(_work), [path('b.md')]);
  });

  test('not kept in another folder, it stays where it was', () async {
    await draft.keep(_home, named('a.md'));
    refused.add(_work.id);

    expect(await draft.keep(_work, named('b.md')), isFalse);

    expect(await pathsIn(_home), [path('a.md')]);
  });

  test('a later keep anywhere drops the copies left behind', () async {
    await draft.keep(_home, named('a.md'));
    refused.add(_work.id);
    await draft.keep(_work, named('b.md'));
    refused.clear();

    await draft.keep(_work, named('b.md'));

    expect(await pathsIn(_home), isEmpty);
  });

  test('dropped, it goes from every folder', () async {
    await draft.keep(_home, named('a.md'));
    refused.add(_work.id);
    await draft.keep(_work, named('b.md'));
    refused.clear();

    await draft.drop();

    expect(await pathsIn(_home), isEmpty);
    expect(await pathsIn(_work), isEmpty);
  });

  test('keeps asked one after another land in that order', () async {
    final first = draft.keep(_home, named('a.md'));
    final second = draft.keep(_work, named('b.md'));
    await Future.wait([first, second]);

    expect(await pathsIn(_home), isEmpty);
    expect(await pathsIn(_work), [path('b.md')]);
  });
}
