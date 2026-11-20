import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

import '../support/fake_shown_type.dart';

final _types = ShownFileTypes([const FakeShownType()]);

void main() {
  late FakeFolder raw;
  late FilesOfFolder files;
  late FileDrafts drafts;
  final later = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    final folder = Folder(
      id: folderId('f1'),
      name: 'Files',
      color: 'teal',
      location: 'fake:f1',
    );
    raw = FakePlugin().folder(folder.id.folder);
    final services = folderServices(
      raw,
      reach: folderReach(raw.files),
      handles: _types.handles,
      keptApart: (_) => false,
      checkEvery: () => const Duration(seconds: 1),
      backupsPath: tempFolder().path,
      deviceId: '0123456789abcdef',
      wrote: (_) {},
    );
    files = FilesOfFolder(folder, services, _types);
    drafts = FileDrafts(Directory('${tempFolder().path}/drafts'));
  });

  Future<void> leave(String file, String text, {DraftOf? of}) => drafts.keep(
    Draft(
      DraftHead(
        id: DraftHead.newId(),
        path: path(file),
        of: of ?? const NewFileDraft(),
      ),
      utf8.encode(text),
    ),
  );

  /// The own drafts handed to the user's step, which keeps them if
  /// [keeps].
  final handed = <String>[];
  Future<void> recover({bool keeps = true, DateTime? before}) =>
      recoverFolderDrafts(
        drafts,
        files,
        recoverOwn: (_, draft, own) async {
          handed.add('${draft.head.path.value}:${own.part}');
          return keeps;
        },
        before: before ?? later,
      );

  tearDown(handed.clear);

  group('a new file', () {
    test('gets its file, and its draft goes', () async {
      await leave('Milk.md', 'Milk\n');

      await recover();

      expect(raw.files.textOf('Milk.md'), 'Milk\n');
      expect(await drafts.heads(before: later), isEmpty);
    });

    test(
      'goes into its subfolder, with a number if the name is taken',
      () async {
        raw.files.put('inbox/Milk.md', 'other');
        await leave('inbox/Milk.md', 'Milk\n');

        await recover();

        expect(raw.files.textOf('inbox/Milk 2.md'), 'Milk\n');
      },
    );

    test('makes its new subfolder', () async {
      await leave(
        'new/Milk.md',
        'Milk\n',
        of: const NewFileDraft(newSubfolder: true),
      );

      await recover();

      expect(raw.files.textOf('new/Milk.md'), 'Milk\n');
    });

    test('goes to the top level if its subfolder is gone', () async {
      await leave('gone/Milk.md', 'Milk\n');

      await recover();

      expect(raw.files.textOf('Milk.md'), 'Milk\n');
    });

    test('written before the app was ended is not written again', () async {
      raw.files
        ..put('Milk.md', 'other')
        ..put('Milk 2.md', 'Milk\n');
      await leave('Milk.md', 'Milk\n');

      await recover();

      expect(raw.files.textOf('Milk 3.md'), isNull);
      expect(await drafts.heads(before: later), isEmpty);
    });
  });

  test("hands an own draft to its user's step", () async {
    await leave('a.md', 'mine', of: const OwnDraft('v1'));

    await recover();

    expect(handed, ['a.md:v1']);
    expect(await drafts.heads(before: later), isEmpty);
  });

  test('keeps a draft its user could not keep yet', () async {
    await leave('a.md', 'mine', of: const OwnDraft('v1'));

    await recover(keeps: false);

    expect(await drafts.heads(before: later), hasLength(1));
  });

  test('leaves drafts written since the app started', () async {
    await leave('Milk.md', 'Milk\n');

    await recover(before: DateTime(2000));

    expect(raw.files.textOf('Milk.md'), isNull);
    expect(await drafts.heads(before: later), hasLength(1));
  });
}
