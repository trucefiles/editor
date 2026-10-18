import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note_actions.dart';
import 'package:truce_editor/notes/quick/quick_note_controller.dart';
import 'package:truce_editor/notes/quick/quick_note_draft.dart';
import 'package:truce_editor/notes/quick/quick_note_drafts_provider.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

import '../../support.dart';

void main() {
  late ProviderContainer container;
  late Directory work;
  late Directory home;
  late List<NoteFolder> folders;
  late QuickNoteDrafts drafts;

  setUp(() async {
    work = tempFolder();
    home = tempFolder();
    folders = [folderAt(work, id: 'work'), folderAt(home, id: 'home')];
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderSettingsStoreProvider).save(folders);
    await container.read(folderScansProvider.future);
    drafts = container.read(quickNoteDraftsProvider);
  });

  QuickNoteController controller() {
    final controller = QuickNoteController(
      drafts,
      container.read(noteActionsProvider),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  File file(Directory dir, String name) => File('${dir.path}/$name');

  test('keeps the text on this device until it is filed', () async {
    final quick = controller();
    await quick.start();

    quick.edit('Milk\nEggs\n');
    await quick.secure();

    expect(await drafts.load(), const QuickNoteDraft(text: 'Milk\nEggs\n'));
    expect(work.listSync(), isEmpty);
  });

  test('files into the default folder, named after the first line', () async {
    final quick = controller();
    await quick.start();
    quick.edit('Milk\nEggs\n');

    final note = (await quick.file(folders)).value!;

    expect(note.path.value, 'Milk.md');
    expect(file(work, 'Milk.md').readAsStringSync(), 'Milk\nEggs\n');
    expect(await drafts.load(), isNull);
  });

  test('files into the picked place', () async {
    Directory('${home.path}/inbox').createSync();
    await container.read(folderScansProvider.notifier).refresh();
    final quick = controller();
    await quick.start();
    quick
      ..edit('Call Bob')
      ..pick((folder: folders[1], subfolder: path('inbox')));

    await quick.file(folders);

    expect(file(home, 'inbox/Call Bob.md').readAsStringSync(), 'Call Bob');
  });

  test('a picked subfolder deleted meanwhile is not made again', () async {
    Directory('${home.path}/inbox').createSync();
    await container.read(folderScansProvider.notifier).refresh();
    final quick = controller();
    await quick.start();
    quick
      ..edit('Call Bob')
      ..pick((folder: folders[1], subfolder: path('inbox')));
    Directory('${home.path}/inbox').deleteSync();
    await container.read(folderScansProvider.notifier).refresh();

    await quick.file(folders);

    expect(file(home, 'Call Bob.md').existsSync(), isTrue);
    expect(Directory('${home.path}/inbox').existsSync(), isFalse);
  });

  test('an empty note is dropped, nothing written', () async {
    final quick = controller();
    await quick.start();
    quick.edit(' \n');

    expect((await quick.file(folders)).value, isNull);

    expect(work.listSync(), isEmpty);
    expect(await drafts.load(), isNull);
  });

  test('goes on with the note left from before', () async {
    await drafts.keep(
      const QuickNoteDraft(
        text: 'Left',
        place: (folderId: 'home', subfolder: null),
      ),
    );
    final quick = controller();

    expect(await quick.start(), 'Left');
    await quick.file(folders);

    expect(file(home, 'Left.md').readAsStringSync(), 'Left');
  });

  test('stays on this device when the folder cannot take it', () async {
    final quick = controller();
    await quick.start();
    quick.edit('Milk');
    work.deleteSync(recursive: true);

    expect(await quick.file(folders), isA<Err<Object?, StoreError>>());

    expect(await drafts.load(), const QuickNoteDraft(text: 'Milk'));
    expect(work.existsSync(), isFalse);
    work.createSync();
  });

  test('nothing is kept again once filed', () async {
    final quick = QuickNoteController(
      drafts,
      container.read(noteActionsProvider),
    );
    await quick.start();
    quick.edit('Milk');
    await quick.file(folders);

    quick.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(await drafts.load(), isNull);
  });
}
