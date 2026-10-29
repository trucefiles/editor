import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_editor/backups/all_backups.dart';
import 'package:truce_editor/backups/restore_controller.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/sync_tool/base_folder_wiring.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;
  late FileBackups backups;

  setUp(() async {
    dir = tempFolder();
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    final folder = folderAt(dir);
    await container.read(folderListStoreProvider).save([folder]);
    backups = container.read(baseFolderServicesProvider(folder.base)).backups;
  });

  File document() => File('${dir.path}/todo.md');

  late ProviderSubscription<RestoreState> watching;
  late NotifierProvider<RestoreController, RestoreState> provider;

  RestoreState current() => container.read(provider);

  /// Watches the screen of [backup], as the screen does.
  void watch(FolderBackup backup) {
    provider = restoreProvider(backup);
    watching = container.listen(provider, (_, _) {});
  }

  /// Waits until the versions shown loaded, or failed to.
  Future<RestoreState> loaded() async {
    final done = Completer<RestoreState>();
    final waiting = container.listen(provider, (_, state) {
      if (state is! CompareLoading && !done.isCompleted) done.complete(state);
    }, fireImmediately: true);
    final state = await done.future;
    waiting.close();
    return state;
  }

  /// The backup and the file shown.
  RestoreChoice choice() => switch (current()) {
    CompareShowing(:final sides) => sides,
    final other => throw StateError('nothing shows: $other'),
  };

  /// Backs up [text] as the document before editing, then opens that backup
  /// from the list of all backups and waits until it is loaded.
  Future<RestoreController> open(String text) async {
    await backups.saveBeforeEdit(
      at: DateTime.now(),
      filePath: path('todo.md'),
      bytes: utf8.encode(text),
    );
    // Kept alive like the backups screen does.
    container.listen(allBackupsProvider, (_, _) {});
    watch((await container.read(allBackupsProvider.future)).single);
    await loaded();
    return container.read(provider.notifier);
  }

  test('lists the backups of every folder', () async {
    await open('# Todo\nbackup\n');

    final listed = await container.read(allBackupsProvider.future);

    expect(listed.single.folder.base.address, Uri.file(dir.path));
    expect(listed.single.backup.filePath, path('todo.md'));
  });

  test('restores and rescans when the screen closes meanwhile', () async {
    document().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');

    final kept = controller.keep(const KeepOther());
    watching.close();

    expect(await kept, isNull, reason: 'the screen closed first');
    expect(document().readAsStringSync(), '# Todo\nbackup\n');
  });

  test('loads again at the next scan after loading failed', () async {
    document().writeAsStringSync('# Todo\nnow\n');
    await backups.saveBeforeEdit(
      at: DateTime.now(),
      filePath: path('todo.md'),
      bytes: utf8.encode('# Todo\nbackup\n'),
    );
    container.listen(allBackupsProvider, (_, _) {});
    final backup = (await container.read(allBackupsProvider.future)).single;
    final kept = File(
      '${container.read(appStorageProvider).backupsPath(backup.folder.id)}'
      '/${backup.backup.storePath.value}',
    );
    final away = kept.renameSync('${kept.path}-away');
    watch(backup);
    expect(
      await loaded(),
      isA<CompareLoadFailed<FolderBackup, RestoreChoice>>().having(
        (s) => s.error,
        'error',
        StoreError.notFound,
      ),
    );

    away.renameSync(kept.path);
    await container.read(folderContentsProvider.notifier).refresh();
    await loaded();

    expect(choice().bytes, utf8.encode('# Todo\nbackup\n'));
  });

  test('loads the backup next to the document', () async {
    document().writeAsStringSync('# Todo\nnow\n');

    await open('# Todo\nbackup\n');

    expect(String.fromCharCodes(choice().bytes), '# Todo\nbackup\n');
    expect(String.fromCharCodes(choice().current!.bytes), '# Todo\nnow\n');
  });

  test('restores the backup', () async {
    document().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');

    final kept = await controller.keep(const KeepOther());

    expect(kept!.error, isNull);
    expect(kept.done, isTrue);
    expect(document().readAsStringSync(), '# Todo\nbackup\n');
  });

  test('lists the backup of the file it replaced', () async {
    document().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');

    await controller.keep(const KeepOther());

    expect(await container.read(allBackupsProvider.future), hasLength(2));
  });

  test('loads the document again if it changed meanwhile', () async {
    document().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');
    document().writeAsStringSync('# Todo\nchanged elsewhere\n');

    final kept = await controller.keep(const KeepOther());

    expect(kept!.error, ResolveError.changedSinceScan);
    expect(kept.done, isFalse);
    expect(document().readAsStringSync(), '# Todo\nchanged elsewhere\n');
    await loaded();
    expect(
      String.fromCharCodes(choice().current!.bytes),
      '# Todo\nchanged elsewhere\n',
    );
  });
}
