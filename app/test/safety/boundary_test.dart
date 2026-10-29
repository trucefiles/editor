import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/backups/all_backups.dart';
import 'package:truce_editor/document_page/open_documents.dart';
import 'package:truce_editor/documents/document_actions.dart';
import 'package:truce_editor/documents/document_draft.dart';
import 'package:truce_editor/documents/document_drafts.dart';
import 'package:truce_editor/documents/document_files.dart';
import 'package:truce_editor/documents/document_steps.dart';
import 'package:truce_editor/documents/open_failure.dart';
import 'package:truce_editor/documents/previews/card_preview_controller.dart';
import 'package:truce_editor/folder_state/folder_contents.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_error.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/host_paths.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/search/search_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/sync_tool/sync_tools.dart';
import 'package:truce_test_support/truce_test_support.dart' show SpyFileStore;

import '../support.dart';

/// The boundary: the app touches nothing in a base folder outside what its
/// folders show. A spy at the file layer, below every other layer, sees
/// every path the app lists, reads, writes or deletes there.
void main() {
  late Directory dir;
  late ProviderContainer container;
  late SpyFileStore spy;

  /// Starts the app's providers with [folders] added.
  Future<void> start(List<DocumentFolder> folders) async {
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        hostPathsProvider.overrideWithValue(const SameHostPaths()),
        syncToolsProvider.overrideWith(
          (ref) => SyncTools([
            _SpiedTool(hostSyncthing(), (files) => spy = SpyFileStore(files)),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderListStoreProvider).save(folders);
    await container.read(foldersProvider.future);
  }

  void write(String name, String text) =>
      File('${dir.path}/$name').writeCreatingFolders(text);

  /// The paths touched that [selection] does not cover, without the
  /// folders a listing only walked through to reach it.
  Set<String> touchedOutside(Selection selection) => {
    for (final touched in spy.touched)
      if (!selection.covers(touched) &&
          !(Directory('${dir.path}/${touched.value}').existsSync() &&
              selection.reaches(touched)))
        touched.value,
  };

  Future<FolderContents> scanned() async {
    await container.read(folderContentsProvider.future);
    return (await container.read(folderContentsProvider.notifier).refresh())!;
  }

  setUp(() {
    dir = tempFolder();
    write('top.md', '# Top');
    write('home/b.md', '# B');
    write('home/picture.png', 'png');
    write('notes/work/a.md', '# A\n![](../../home/picture.png)');
    write('notes/work/inbox/c.md', '# C');
    write('notes/work/c.sync-conflict-20261003-134809-ABCDEFG.md', '# C2');
    write('notes/private/d.md', '# D');
  });

  final work = Selection.of([path('notes/work')]);

  test('every flow touches only what the folder shows', () async {
    final folder = folderAt(dir, selection: work);
    await start([folder]);
    final actions = container.read(documentActionsProvider);
    final files = container.read(documentFilesProvider(folder));
    final markdown = appDocumentTypes().forNew;

    final found = await scanned();
    expect([
      for (final document in found.documents) document.path.value,
    ], unorderedEquals(['notes/work/a.md', 'notes/work/inbox/c.md']));
    for (final document in found.documents) {
      await container.read(cardPreviewsProvider).read(document);
    }
    final search = container.listen(searchProvider, (_, _) {});
    await eventually(() => search.read().complete);
    search.close();
    final a = (await files.reload(
      found.documents.firstWhere(
        (document) => document.path.value == 'notes/work/a.md',
      ),
    )).value;
    final saved = (await files.save(a, '# A\nmore')).value;
    await files.backUpBeforeEdit(saved);
    expect(await files.bytesOf(path('home/picture.png')), isNull);
    final created = (await actions.create(
      (folder: folder, subfolder: path('notes/work')),
      type: markdown,
      title: 'New',
      text: '# New',
    )).value;
    await actions.setMark(created.document, const DocumentMark(color: 'teal'));
    final moved = (await actions.move(created, (
      folder: folder,
      subfolder: path('notes/work/inbox'),
    ))).value;
    final deleted = (await actions.delete(moved, '# New')).value;
    await actions.undoDelete(deleted);
    await container.read(allBackupsProvider.future);
    expect(
      (await files.open(path('home/b.md'))).error,
      const NotRead(StoreError.outside),
    );
    expect(
      (await files.open(path('top.md'))).error,
      const NotRead(StoreError.outside),
    );
    await scanned();

    expect(touchedOutside(work), isEmpty);
    expect(spy.touched, contains(path('notes/work/a.md')));
  });

  test(
    'narrowing a folder while a document is open keeps its edits, then '
    'touches nothing it no longer shows but the save the user made',
    () async {
      final both = Selection.of([path('notes/work'), path('home')]);
      final folder = folderAt(dir, selection: both);
      await start([folder]);
      final files = container.read(documentFilesProvider(folder));
      final b = (await files.open(path('home/b.md'))).value;
      final saved = (await files.save(b, '# B\nfirst')).value;
      // The open document's last edits, kept as the folder changes.
      var secured = false;
      container
          .read(openDocumentsProvider)
          .add(
            base: () => folder.base,
            secure: () async {
              secured = (await files.save(saved, '# B\nlast')) is Ok;
            },
          );
      final drafts = container.read(documentDraftsProvider(folder.base.id));
      await drafts.keep(
        DocumentDraft(id: 'left', path: path('home/b.md'), base: '', text: 'x'),
      );

      final changed = await container
          .read(foldersProvider.notifier)
          .change(folder.copyWith(selection: work));
      expect(changed, isA<Ok<void, FolderError>>());
      expect(secured, isTrue);
      spy.touched.clear();

      // The second save came within Syncthing's window: the old stack writes
      // the same bytes once more, as the user's own write.
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      final narrowed = container.read(foldersProvider).value!.single;
      expect(
        (await container
                .read(documentFilesProvider(narrowed))
                .open(path('home/b.md')))
            .error,
        const NotRead(StoreError.outside),
      );
      await scanned();
      await container
          .read(documentStepsProvider)
          .recoverDrafts(before: DateTime.now().add(const Duration(days: 1)));

      expect(File('${dir.path}/home/b.md').readAsStringSync(), '# B\nlast');
      expect(touchedOutside(work), anyOf(isEmpty, {'home/b.md'}));
      expect(
        [
          for (final draft in await drafts.all(before: DateTime(9999)))
            draft.id,
        ],
        ['left'],
      );
    },
  );
}

/// [_tool] with each place's files seen through [_spy], below every other
/// layer.
final class _SpiedTool implements SyncTool {
  _SpiedTool(this._tool, this._spy);

  final SyncTool _tool;
  final FileStore Function(FileStore files) _spy;

  @override
  String get id => _tool.id;

  @override
  String get name => _tool.name;

  @override
  bool isToolFolder(List<String> names) => _tool.isToolFolder(names);

  @override
  Future<SyncStatus> recognize(Uri address) => _tool.recognize(address);

  @override
  Future<bool> missesOldVersions(Uri address) =>
      _tool.missesOldVersions(address);

  @override
  ToolPlace place(Uri address) => _SpiedPlace(_tool.place(address), _spy);
}

final class _SpiedPlace implements ToolPlace {
  _SpiedPlace(this._place, FileStore Function(FileStore files) spy)
    : files = spy(_place.files);

  final ToolPlace _place;

  @override
  final FileStore files;

  @override
  LiveChanges? get changes => _place.changes;

  @override
  SubfolderNames get subfolders => _place.subfolders;

  @override
  bool showsFolder(RelPath folder) => _place.showsFolder(folder);

  @override
  SyncedFolder open(BoundedPlace bounded) => _place.open(bounded);
}
