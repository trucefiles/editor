import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/backups/all_backups.dart';
import 'package:truce_editor/files/file_actions.dart';
import 'package:truce_editor/files/files_wiring.dart';
import 'package:truce_editor/files/previews/card_preview_controller.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/plugins/plugins_wiring.dart';
import 'package:truce_editor/search/search_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart' show SpyFileStore;

import '../support.dart';

/// The boundary: the app touches nothing on disk outside a folder's own
/// directory, and inside it only the files of the types it handles, their
/// conflict copies and the marks. A spy at the file layer, below every
/// other layer, sees every path the app lists, reads, writes or deletes.
void main() {
  late Directory dir;
  late ProviderContainer container;
  late SpyFileStore spy;
  late SyncthingPlugin syncthing;

  /// Starts the app's providers with the folder [inside] the directory
  /// [dir] added, its files seen through [spy]; the folder.
  Future<Folder> start(String inside) async {
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        folderPluginsProvider.overrideWith(
          (ref) => FolderPlugins([
            _SpiedPlugin(
              syncthing = SyncthingPlugin(ref.watch(localDiskProvider)),
              (files) => spy = SpyFileStore(files),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final plugins = container.read(folderPluginsProvider);
    return addFolderOf(
      container,
      plugins.of('syncthing'),
      syncthing.candidate(
        Uri.directory(dir.path),
        Uri.directory(dir.path),
        path(inside),
      ),
    );
  }

  void write(String name, String text) =>
      File('${dir.path}/$name').writeCreatingFolders(text);

  /// The paths touched that are none of a handled file, a conflict copy,
  /// the marks, or a folder a listing walked through.
  Set<String> touchedBeyondFiles() => {
    for (final touched in spy.touched)
      if (!appFileTypes().handles(touched) &&
          !touched.value.split('/').contains('.truce') &&
          !Directory('${dir.path}/notes/work/${touched.value}').existsSync())
        touched.value,
  };

  /// The bytes of every file outside the folder's directory.
  Map<String, String> outside() => {
    for (final file in Directory(dir.path).listSync(recursive: true))
      if (file is File && !file.path.contains('/notes/work/'))
        file.path: file.readAsStringSync(),
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

  test('every flow touches only what the folder shows', () async {
    final before = outside();
    final folder = await start('notes/work');
    final actions = container.read(fileActionsProvider);
    final files = container.read(fileAccessProvider).of(folder);
    final markdown = appFileTypes().forNew;

    final found = await scanned();
    expect([
      for (final file in found.files) file.path.value,
    ], unorderedEquals(['a.md', 'inbox/c.md']));
    for (final file in found.files) {
      await container.read(cardPreviewsProvider).read(file);
    }
    final search = container.listen(searchProvider, (_, _) {});
    await eventually(() => search.read().complete);
    search.close();
    final a = (await files.reload(
      found.files.firstWhere((file) => file.path.value == 'a.md'),
    )).value;
    final saved = (await files.save(a, '# A\nmore')).value;
    await files.backUpBeforeEdit(saved);
    final created = (await actions.create(
      (folder: folder, subfolder: null),
      type: markdown,
      title: 'New',
      text: '# New',
    )).value;
    await actions.setMark(created.listed, const FileMark(color: 'teal'));
    final moved = (await actions.move(created, (
      folder: folder,
      subfolder: path('inbox'),
    ))).value;
    final deleted = (await actions.delete(moved, '# New')).value;
    await actions.undoDelete(deleted);
    await container.read(allBackupsProvider.future);
    await scanned();

    expect(touchedBeyondFiles(), isEmpty);
    expect(spy.touched, contains(path('a.md')));
    expect(outside(), before);
  });

  test('removing a folder while a file is open keeps its edits first, then '
      'the folder takes no write', () async {
    final folder = await start('notes/work');
    final files = container.read(fileAccessProvider).of(folder);
    final a = (await files.open(path('a.md'))).value;
    var secured = false;
    container
        .read(openFilesProvider)
        .add(
          folder: () => folder.id,
          secure: (_) async {
            secured = (await files.save(a, '# A\nlast')) is Ok;
          },
        );

    final removed = await container
        .read(foldersProvider.notifier)
        .remove(folder);
    expect(removed, isA<Ok<void, FolderError>>());
    expect(secured, isTrue);
    // Syncthing may write the same bytes once more, as the user's own.
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    spy.touched.clear();

    expect((await files.save(a, '# A\nlate')).error, StoreError.closed);
    expect(spy.touched, isEmpty);
    expect(File('${dir.path}/notes/work/a.md').readAsStringSync(), '# A\nlast');
  });
}

/// [_plugin] with each folder's files seen through [_spy], below every
/// other layer.
final class _SpiedPlugin implements FolderPlugin {
  _SpiedPlugin(this._plugin, this._spy);

  final FolderPlugin _plugin;
  final FileStore Function(FileStore files) _spy;

  @override
  String get id => _plugin.id;

  @override
  String get name => _plugin.name;

  @override
  String get helpLine => _plugin.helpLine;

  @override
  bool load(Object? blob) => _plugin.load(blob);

  @override
  Object? get blob => _plugin.blob;

  @override
  List<PluginFolder> get folders => _plugin.folders;

  @override
  Result<List<PluginFolder>, AddRefused> add(
    List<PluginFolderCandidate> candidates,
  ) => _plugin.add(candidates);

  @override
  void forget(String id) => _plugin.forget(id);

  @override
  RawFolder open(String id) => _SpiedFolder(_plugin.open(id), _spy);
}

final class _SpiedFolder implements RawFolder {
  _SpiedFolder(this._folder, FileStore Function(FileStore files) spy)
    : files = spy(_folder.files);

  final RawFolder _folder;

  @override
  final FileStore files;

  @override
  LiveChanges? get changes => _folder.changes;

  @override
  OpenFolder open(BoundedPlace bounded) => _folder.open(bounded);
}
