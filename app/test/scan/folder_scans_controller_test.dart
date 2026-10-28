import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document_draft.dart';
import 'package:truce_editor/documents/document_drafts.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

import '../support.dart';

void main() {
  late ProviderContainer container;
  late AppStorage storage;

  /// Starts the app's providers with [folders] saved as the folder list.
  Future<void> start(List<DocumentFolder> folders) async {
    storage = AppStorage(tempFolder().path);
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderListStoreProvider).save(folders);
  }

  Future<FolderScans> scans() => container.read(folderScansProvider.future);

  void write(Directory dir, String name, String text, {DateTime? modified}) {
    final file = File('${dir.path}/$name')..writeCreatingFolders(text);
    if (modified != null) file.setLastModifiedSync(modified);
  }

  test('finds the documents and conflicts of every folder', () async {
    final work = tempFolder();
    final home = tempFolder();
    write(work, 'plan.md', '# Plan');
    write(home, 'todo.md', '# Todo');
    write(home, 'todo.sync-conflict-20261003-134809-ABCDEFG.md', '# Old');
    await start([folderAt(work, id: 'work'), folderAt(home, id: 'home')]);

    final found = await scans();

    expect(
      found.documents.map((n) => n.title),
      unorderedEquals(['Plan', 'Todo']),
    );
    final conflict = found.conflicts.all.single;
    expect(conflict.folder.id, 'home');
    expect(conflict.conflict.mainPath, path('todo.md'));
    expect(found.failedFolders, isEmpty);
  });

  test('a refresh still running when the app ends does no harm', () async {
    await start([folderAt(tempFolder(), id: 'a'), folderAt(tempFolder())]);
    await scans();
    final controller = container.read(folderScansProvider.notifier);

    final refreshes = [controller.refresh(), controller.refresh()];
    container.dispose();

    await Future.wait(refreshes);
  });

  test('a refresh while the folders load waits for them', () async {
    final dir = tempFolder();
    write(dir, 'plan.md', '# Plan');
    await start([folderAt(dir)]);
    container.listen(folderScansProvider, (_, _) {});

    final refreshed = container.read(folderScansProvider.notifier).refresh();
    final first = await scans();
    await refreshed;

    expect(first.documents.map((n) => n.title), ['Plan']);
    expect((await scans()).documents.map((n) => n.title), ['Plan']);
  });

  test('the first scan shows edits left by the last run', () async {
    final dir = tempFolder();
    write(dir, 'plan.md', '# Plan\nv1\n');
    await start([folderAt(dir, id: 'f1')]);
    final drafts = DocumentDrafts(Directory(storage.draftsPath('f1')));
    await drafts.keep(
      DocumentDraft(
        id: '1',
        path: path('plan.md'),
        base: '# Plan\nv1\n',
        text: '# Plan\nmine\n',
      ),
    );
    // Written before this run started.
    File('${storage.draftsPath('f1')}/1.json')
        .setLastModifiedSync(DateTime(2000));

    final found = await scans();

    expect(found.documents.single.file.text, '# Plan\nmine\n');
    expect(await drafts.all(before: DateTime.now()), isEmpty);
  });

  test('finds documents, marks and conflicts several levels deep', () async {
    final dir = tempFolder();
    write(dir, 'todo.md', '# Root');
    write(dir, 'a/todo.md', '# A');
    write(dir, 'a/b/c/todo.md', '# Deep');
    write(dir, 'a/b/c/todo.sync-conflict-20261003-134809-ABCDEFG.md', '# Old');
    final folder = folderAt(dir);
    await servicesFor(folder).marks
        .set(path('a/b/c/todo.md'), const DocumentMark(color: 'teal'));
    await start([folder]);

    final found = await scans();

    expect(
      found.documents.map((n) => n.path.value),
      unorderedEquals(['todo.md', 'a/todo.md', 'a/b/c/todo.md']),
    );
    final deep = (baseId: folder.base.id, path: path('a/b/c/todo.md'));
    final shallow = (baseId: folder.base.id, path: path('a/todo.md'));
    expect(found.markOf(deep).color, 'teal');
    expect(found.markOf(shallow), DocumentMark.none);
    expect(found.conflicts.forNote(deep), isNotNull);
    expect(found.conflicts.forNote(shallow), isNull);
  });

  test('lists every subfolder per folder, empty ones too', () async {
    final dir = tempFolder();
    final other = tempFolder();
    write(dir, 'root.md', '# Root');
    write(dir, 'a/b/c/deep.md', '# Deep');
    write(dir, 'a/b/c/deeper.md', '# Deeper');
    write(dir, 'x/document.md', '# X');
    write(dir, 'y/photo.jpg', 'not a document');
    write(other, 'z/document.md', '# Z');
    Directory('${dir.path}/empty/deeper').createSync(recursive: true);
    write(dir, '.hidden/document.md', '# Hidden');
    await start([folderAt(dir, id: 'one'), folderAt(other, id: 'two')]);

    final found = await scans();

    expect(found.subfoldersOf('one').map((p) => p.value), [
      'a',
      'a/b',
      'a/b/c',
      'empty',
      'empty/deeper',
      'x',
      'y',
    ]);
    expect(found.subfoldersOf('two').map((p) => p.value), ['z']);
  });

  test('lists documents newest first', () async {
    final dir = tempFolder();
    write(dir, 'old.md', '# Old', modified: DateTime(2020));
    write(dir, 'new.md', '# New', modified: DateTime(2025));
    await start([folderAt(dir)]);

    expect((await scans()).documents.map((n) => n.title), ['New', 'Old']);
  });

  test('lists documents with the same time by path', () async {
    final dir = tempFolder();
    for (final name in ['c.md', 'a.md', 'b.md']) {
      write(dir, name, '# ${name[0]}', modified: DateTime(2025));
    }
    await start([folderAt(dir)]);

    expect((await scans()).documents.map((n) => n.path.value), [
      'a.md',
      'b.md',
      'c.md',
    ]);
  });

  test(
    'lists the newest documents first and keeps marks by document',
    () async {
      final dir = tempFolder();
      write(dir, 'old.md', '# Old', modified: DateTime(2020));
      write(dir, 'new.md', '# New', modified: DateTime(2025));
      final folder = folderAt(dir);
      final marks = servicesFor(folder).marks;
      await marks.set(path('new.md'), const DocumentMark(color: 'teal'));
      await start([folder]);

      final found = await scans();

      expect(found.documents.map((n) => n.title), ['New', 'Old']);
      expect(
        found.markOf((baseId: folder.base.id, path: path('new.md'))),
        const DocumentMark(color: 'teal'),
      );
    },
  );

  test('reports a folder that cannot be read', () async {
    final gone = folderAt(Directory('${tempFolder().path}/gone'));
    await start([gone]);

    final found = await scans();

    expect(found.failedFolders, {gone: StoreError.notFound});
    expect(found.documents, isEmpty);
  });

  test(
    'shows the last version of a document it could not read, uncovered',
    () async {
      final dir = tempFolder();
      write(dir, 'plan.md', '# Plan\nv1\n');
      await start([folderAt(dir, id: 'f1')]);
      await scans();
      // No longer text: the version read before is all the scan knows.
      File('${dir.path}/plan.md').writeAsBytesSync([0xFF, 0xFE]);

      await container.read(folderScansProvider.notifier).refresh();
      final found = await scans();

      final key = (baseId: 'f1', path: path('plan.md'));
      expect(found.findNote(key)?.file.text, '# Plan\nv1\n');
      expect(found.unreadNotes, {key});
      expect(found.covers(key), isFalse);
    },
  );

  test('refresh shows a document written just before', () async {
    final dir = tempFolder();
    await start([folderAt(dir)]);
    await scans();

    write(dir, 'new.md', '# New');
    await container.read(folderScansProvider.notifier).refresh();

    expect((await scans()).documents.single.title, 'New');
  });

  test('shows a renamed folder on its documents', () async {
    final dir = tempFolder();
    write(dir, 'todo.md', '# Todo');
    final folder = folderAt(dir);
    await start([folder]);
    await scans();

    await container
        .read(foldersProvider.notifier)
        .change(folder.copyWith(name: 'Renamed'));
    await container.read(folderScansProvider.notifier).refresh();

    expect((await scans()).documents.single.folder.name, 'Renamed');
  });
}
