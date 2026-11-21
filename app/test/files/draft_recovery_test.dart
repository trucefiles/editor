import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import '../support.dart';

/// The recovery of edits left as drafts of saved text files, on the
/// app's real files and types, and of drafts an older app version left.
void main() {
  late Directory dir;
  late Directory draftsDir;
  late FileDrafts drafts;
  late FolderServices services;
  late FilesOfFolder files;
  final later = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    dir = tempFolder();
    final folder = folderAt(dir);
    draftsDir = tempFolder();
    drafts = FileDrafts(draftsDir);
    services = servicesFor(folder);
    files = FilesOfFolder(folder, services, appFileTypes());
  });

  File diskFile() => File('${dir.path}/a.md');

  List<String> conflictCopies() => [
    for (final file in dir.listSync().whereType<File>())
      if (file.path.contains('.sync-conflict-')) file.readAsStringSync(),
  ];

  Future<void> recover() => recoverFolderDrafts(
    drafts,
    files,
    recoverOwn: recoverEdits,
    before: later,
  );

  /// Leaves [text] as the draft of `a.md`, edited from [base].
  Future<void> leaveDraft(String text, {String base = '# a\nv1\n'}) =>
      drafts.keep(
        Draft(
          DraftHead(
            id: '1',
            path: path('a.md'),
            of: OwnDraft(fingerprintOf(utf8.encode(base))),
          ),
          utf8.encode(text),
        ),
      );

  test('writes the edits into an unchanged file', () async {
    diskFile().writeAsStringSync('# a\nv1\n');
    await leaveDraft('# a\nmine\n');

    await recover();

    expect(diskFile().readAsStringSync(), '# a\nmine\n');
    expect(conflictCopies(), isEmpty);
    expect(await drafts.heads(before: later), isEmpty);
  });

  test('backs up the file before writing the edits', () async {
    diskFile().writeAsStringSync('# a\nv1\n');
    await leaveDraft('# a\nmine\n');

    await recover();

    final backup = (await services.backups.list()).value.single;
    expect(backup.kind, BackupKind.beforeEdit);
    expect(
      String.fromCharCodes((await services.backups.read(backup)).value),
      '# a\nv1\n',
    );
  });

  test('keeps the edits as a conflict copy if the file changed', () async {
    diskFile().writeAsStringSync('# a\ntheirs\n');
    await leaveDraft('# a\nmine\n');

    await recover();

    expect(diskFile().readAsStringSync(), '# a\ntheirs\n');
    expect(conflictCopies(), ['# a\nmine\n']);
    expect(await drafts.heads(before: later), isEmpty);
  });

  test('a change elsewhere only in line breaks is a change too', () async {
    diskFile().writeAsStringSync('# a\r\nv1\r\n');
    await leaveDraft('# a\nmine\n');

    await recover();

    expect(diskFile().readAsStringSync(), '# a\r\nv1\r\n');
    expect(conflictCopies(), ['# a\nmine\n']);
  });

  test('drops a draft the file already holds', () async {
    diskFile().writeAsStringSync('# a\nmine\n');
    await leaveDraft('# a\nmine\n');

    await recover();

    expect(dir.listSync(), hasLength(1));
    expect(await drafts.heads(before: later), isEmpty);
  });

  test('keeps the edits of a deleted document as a conflict copy', () async {
    await leaveDraft('# a\nmine\n');

    await recover();

    expect(diskFile().existsSync(), isFalse);
    expect(conflictCopies(), ['# a\nmine\n']);
  });

  group('a draft of an older app version', () {
    Future<void> leaveOld(Map<String, Object> json) async =>
        File('${draftsDir.path}/9.json').writeAsStringSync(jsonEncode(json));

    Future<void> recoverOld() => recoverOldDraftsWith(
      (_) => OldDrafts(draftsDir),
      appFileTypes(),
    )(files, before: later);

    test('goes into its unchanged file, and then goes', () async {
      diskFile().writeAsStringSync('# a\nv1\n');
      await leaveOld({'path': 'a.md', 'base': '# a\nv1\n', 'text': '# a\nB\n'});

      await recoverOld();

      expect(diskFile().readAsStringSync(), '# a\nB\n');
      expect(await OldDrafts(draftsDir).count(), 0);
    });

    test('goes into a conflict copy if its file changed', () async {
      diskFile().writeAsStringSync('# a\ntheirs\n');
      await leaveOld({'path': 'a.md', 'base': '# a\nv1\n', 'text': '# a\nB\n'});

      await recoverOld();

      expect(conflictCopies(), ['# a\nB\n']);
    });

    test('of a new document gets its file', () async {
      await leaveOld({'path': 'Milk.md', 'text': 'Milk\n'});

      await recoverOld();

      expect(File('${dir.path}/Milk.md').readAsStringSync(), 'Milk\n');
    });
  });
}
