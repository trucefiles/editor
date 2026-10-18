import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/notes/draft_recovery.dart';
import 'package:truce_editor/notes/note_draft.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_files.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late NoteDrafts drafts;
  late FolderServices services;
  late DraftRecovery recovery;
  final later = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    dir = tempFolder();
    final folder = folderAt(dir);
    drafts = tempDrafts();
    services = servicesFor(folder);
    recovery = DraftRecovery(drafts, NoteFiles(folder, services));
  });

  File note() => File('${dir.path}/a.md');

  List<String> conflictCopies() => [
    for (final file in dir.listSync().whereType<File>())
      if (file.path.contains('.sync-conflict-')) file.readAsStringSync(),
  ];

  Future<void> leaveDraft(String text) => drafts.keep(
    NoteDraft(id: '1', path: path('a.md'), base: '# a\nv1\n', text: text),
  );

  test('writes the edits into an unchanged file', () async {
    note().writeAsStringSync('# a\nv1\n');
    await leaveDraft('# a\nmine\n');

    expect(await recovery.recover(before: later), 1);

    expect(note().readAsStringSync(), '# a\nmine\n');
    expect(conflictCopies(), isEmpty);
    expect(await drafts.all(before: later), isEmpty);
  });

  test('backs up the file before writing the edits', () async {
    note().writeAsStringSync('# a\nv1\n');
    await leaveDraft('# a\nmine\n');

    await recovery.recover(before: later);

    final backup = (await services.backups.list()).value.single;
    expect(backup.filePath, path('a.md'));
    expect(backup.kind, BackupKind.beforeEdit);
    expect(
      String.fromCharCodes((await services.backups.read(backup)).value),
      '# a\nv1\n',
    );
  });

  test('keeps the edits as a conflict copy if the file changed', () async {
    note().writeAsStringSync('# a\ntheirs\n');
    await leaveDraft('# a\nmine\n');

    expect(await recovery.recover(before: later), 1);

    expect(note().readAsStringSync(), '# a\ntheirs\n');
    expect(conflictCopies(), ['# a\nmine\n']);
    expect(await drafts.all(before: later), isEmpty);
  });

  test('drops a draft the file already holds', () async {
    note().writeAsStringSync('# a\nmine\n');
    await leaveDraft('# a\nmine\n');

    expect(await recovery.recover(before: later), 1);

    expect(dir.listSync(), hasLength(1));
    expect(await drafts.all(before: later), isEmpty);
  });

  test('keeps the edits of a deleted note as a conflict copy', () async {
    await leaveDraft('# a\nmine\n');

    expect(await recovery.recover(before: later), 1);

    expect(note().existsSync(), isFalse);
    expect(conflictCopies(), ['# a\nmine\n']);
  });

  test('leaves drafts written since the app started', () async {
    note().writeAsStringSync('# a\nv1\n');
    await leaveDraft('# a\nmine\n');

    expect(await recovery.recover(before: DateTime(2000)), 0);

    expect(note().readAsStringSync(), '# a\nv1\n');
    expect(await drafts.all(before: later), hasLength(1));
  });

  group('a new note', () {
    Future<void> leaveNew(String file, String text) =>
        drafts.keep(NoteDraft(id: '2', path: path(file), text: text));

    test('gets its file', () async {
      await leaveNew('Milk.md', 'Milk\n');

      expect(await recovery.recover(before: later), 1);

      expect(File('${dir.path}/Milk.md').readAsStringSync(), 'Milk\n');
      expect(await drafts.all(before: later), isEmpty);
    });

    test(
      'goes into its subfolder, with a number if the name is taken',
      () async {
        File('${dir.path}/inbox/Milk.md').writeCreatingFolders('other');
        await leaveNew('inbox/Milk.md', 'Milk\n');

        await recovery.recover(before: later);

        expect(
          File('${dir.path}/inbox/Milk 2.md').readAsStringSync(),
          'Milk\n',
        );
      },
    );

    test('goes to the top level if its subfolder is gone', () async {
      await leaveNew('gone/Milk.md', 'Milk\n');

      expect(await recovery.recover(before: later), 1);

      expect(File('${dir.path}/Milk.md').readAsStringSync(), 'Milk\n');
      expect(Directory('${dir.path}/gone').existsSync(), isFalse);
    });

    test('created before the app was ended is not created again', () async {
      File('${dir.path}/Milk.md').writeAsStringSync('Milk\n');
      await leaveNew('Milk.md', 'Milk\n');

      expect(await recovery.recover(before: later), 1);

      expect(dir.listSync().whereType<File>(), hasLength(1));
    });
  });
}
