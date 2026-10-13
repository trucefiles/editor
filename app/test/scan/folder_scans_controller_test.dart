import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';

import '../support.dart';

void main() {
  late ProviderContainer container;

  /// Starts the app's providers with [folders] saved as the folder list.
  Future<void> start(List<NoteFolder> folders) async {
    final storage = AppStorage(tempFolder().path);
    container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await container.read(folderSettingsStoreProvider).save(folders);
  }

  Future<FolderScans> scans() => container.read(folderScansProvider.future);

  void write(Directory dir, String name, String text, {DateTime? modified}) {
    final file = File('${dir.path}/$name')..writeAsStringSync(text);
    if (modified != null) file.setLastModifiedSync(modified);
  }

  test('finds the notes and conflicts of every folder', () async {
    final work = tempFolder();
    final home = tempFolder();
    write(work, 'plan.md', '# Plan');
    write(home, 'todo.md', '# Todo');
    write(home, 'todo.sync-conflict-20261003-134809-ABCDEFG.md', '# Old');
    await start([folderAt(work, id: 'work'), folderAt(home, id: 'home')]);

    final found = await scans();

    expect(found.notes.map((n) => n.title), unorderedEquals(['Plan', 'Todo']));
    final conflict = found.conflicts.all.single;
    expect(conflict.folder.id, 'home');
    expect(conflict.conflict.mainPath, path('todo.md'));
    expect(found.failedFolders, isEmpty);
  });

  test('lists notes newest first', () async {
    final dir = tempFolder();
    write(dir, 'old.md', '# Old', modified: DateTime(2020));
    write(dir, 'new.md', '# New', modified: DateTime(2025));
    await start([folderAt(dir)]);

    expect((await scans()).notes.map((n) => n.title), ['New', 'Old']);
  });

  test('reports a folder that cannot be read', () async {
    final gone = folderAt(Directory('${tempFolder().path}/gone'));
    await start([gone]);

    final found = await scans();

    expect(found.failedFolders, {gone: StoreError.notFound});
    expect(found.notes, isEmpty);
  });

  test('refresh shows a note written just before', () async {
    final dir = tempFolder();
    await start([folderAt(dir)]);
    await scans();

    write(dir, 'new.md', '# New');
    await container.read(folderScansProvider.notifier).refresh();

    expect((await scans()).notes.single.title, 'New');
  });
}
