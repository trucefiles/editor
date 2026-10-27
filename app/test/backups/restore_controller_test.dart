import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/backups/all_backups.dart';
import 'package:truce_editor/backups/restore_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';

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
    await container.read(folderSettingsStoreProvider).save([folder]);
    backups = container.read(folderServicesProvider(folder.location)).backups;
  });

  File document() => File('${dir.path}/todo.md');

  late ProviderSubscription<RestoreState> watching;
  late NotifierProvider<RestoreController, RestoreState> provider;

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
    final backup = (await container.read(allBackupsProvider.future)).single;
    provider = restoreProvider(backup);
    final loaded = Completer<void>();
    watching = container.listen(provider, (_, state) {
      if (state.choice != null && !loaded.isCompleted) loaded.complete();
    }, fireImmediately: true);
    await loaded.future;
    return container.read(provider.notifier);
  }

  RestoreState current() => container.read(provider);

  test('lists the backups of every folder', () async {
    await open('# Todo\nbackup\n');

    final listed = await container.read(allBackupsProvider.future);

    expect(listed.single.folder.path, dir.path);
    expect(listed.single.backup.filePath, path('todo.md'));
  });

  test('restores and rescans when the screen closes meanwhile', () async {
    document().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');

    final kept = controller.keep(const KeepOther());
    watching.close();

    expect(await kept, isA<Ok<void, ResolveError>>());
    final scans = await container.read(folderScansProvider.future);
    expect(scans.documents.single.file.text, '# Todo\nbackup\n');
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
    provider = restoreProvider(backup);
    var loaded = Completer<void>();
    container.listen(provider, (_, state) {
      if (state.choice != null && !loaded.isCompleted) loaded.complete();
    }, fireImmediately: true);
    await loaded.future;
    expect(current().choice!.error, StoreError.notFound);

    away.renameSync(kept.path);
    loaded = Completer<void>();
    await container.read(folderScansProvider.notifier).refresh();
    await loaded.future;

    expect(current().choice!.value.bytes, utf8.encode('# Todo\nbackup\n'));
  });

  test('loads the backup next to the document', () async {
    document().writeAsStringSync('# Todo\nnow\n');

    await open('# Todo\nbackup\n');

    final choice = current().choice!.value;
    expect(String.fromCharCodes(choice.bytes), '# Todo\nbackup\n');
    expect(String.fromCharCodes(choice.current!.bytes), '# Todo\nnow\n');
  });

  test('restores the backup', () async {
    document().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');

    final kept = await controller.keep(const KeepOther());

    expect(kept, isA<Ok<void, ResolveError>>());
    expect(document().readAsStringSync(), '# Todo\nbackup\n');
  });

  test('loads the document again if it changed meanwhile', () async {
    document().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');
    document().writeAsStringSync('# Todo\nchanged elsewhere\n');

    final kept = await controller.keep(const KeepOther());

    expect(kept!.error, ResolveError.changedSinceScan);
    expect(document().readAsStringSync(), '# Todo\nchanged elsewhere\n');
    expect(
      String.fromCharCodes(current().choice!.value.current!.bytes),
      '# Todo\nchanged elsewhere\n',
    );
    expect(current().busy, isFalse);
  });
}
