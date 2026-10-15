import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/backups/all_backups.dart';
import 'package:truce_editor/backups/restore_controller.dart';
import 'package:truce_editor/folders/folder_services.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/platform/device_id.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;
  late NoteBackups backups;

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

  File note() => File('${dir.path}/todo.md');

  late NotifierProvider<RestoreController, RestoreState> provider;

  /// Backs up [text] as the note before editing, then opens that backup
  /// from the list of all backups and waits until it is loaded.
  Future<RestoreController> open(String text) async {
    await backups.saveBeforeEdit(
      at: DateTime.now(),
      notePath: path('todo.md'),
      bytes: utf8.encode(text),
    );
    // Kept alive like the backups screen does.
    container.listen(allBackupsProvider, (_, _) {});
    final backup = (await container.read(allBackupsProvider.future)).single;
    provider = restoreProvider(backup);
    final loaded = Completer<void>();
    container.listen(provider, (_, state) {
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
    expect(listed.single.backup.notePath, path('todo.md'));
  });

  test('loads the backup next to the note', () async {
    note().writeAsStringSync('# Todo\nnow\n');

    await open('# Todo\nbackup\n');

    final choice = current().choice!.value;
    expect(String.fromCharCodes(choice.bytes), '# Todo\nbackup\n');
    expect(String.fromCharCodes(choice.current!.bytes), '# Todo\nnow\n');
  });

  test('restores the backup', () async {
    note().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');

    final kept = await controller.keep(const KeepOther());

    expect(kept, isA<Ok<void, ResolveError>>());
    expect(note().readAsStringSync(), '# Todo\nbackup\n');
  });

  test('loads the note again if it changed meanwhile', () async {
    note().writeAsStringSync('# Todo\nnow\n');
    final controller = await open('# Todo\nbackup\n');
    note().writeAsStringSync('# Todo\nchanged elsewhere\n');

    final kept = await controller.keep(const KeepOther());

    expect(kept!.error, ResolveError.changedSinceScan);
    expect(note().readAsStringSync(), '# Todo\nchanged elsewhere\n');
    expect(
      String.fromCharCodes(current().choice!.value.current!.bytes),
      '# Todo\nchanged elsewhere\n',
    );
    expect(current().busy, isFalse);
  });
}
