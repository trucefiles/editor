import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/conflicts/conflict_controller.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/platform/device_id.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';

import '../support.dart';

void main() {
  const first = 'todo.sync-conflict-20261003-134809-ABCDEFG.md';
  const second = 'todo.sync-conflict-20261004-080000-ABCDEFG.md';
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    dir = tempFolder();
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderSettingsStoreProvider).save([folderAt(dir)]);
  });

  void write(String name, String text) => File('${dir.path}/$name')
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  List<String> files() =>
      [for (final entry in dir.listSync()) entry.uri.pathSegments.last]..sort();

  late NotifierProvider<ConflictController, ConflictState> provider;

  /// Opens the scanned conflict and waits until its sides are loaded.
  Future<ConflictController> open() async {
    final scans = await container.read(folderScansProvider.future);
    final conflict = scans.conflicts.all.single;
    provider = conflictProvider(conflict);
    final loaded = Completer<void>();
    container.listen(provider, (_, state) {
      if (state.sides != null && !loaded.isCompleted) loaded.complete();
    }, fireImmediately: true);
    await loaded.future;
    return container.read(provider.notifier);
  }

  ConflictState current() => container.read(provider);

  test('loads both sides of the oldest copy', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    write(second, '# Todo\nsecond\n');

    await open();

    final sides = current().sides!.value;
    expect(sides.current, '# Todo\nmine\n');
    expect(sides.other, '# Todo\nfirst\n');
  });

  test('moves on to the next copy, then is done', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    write(second, '# Todo\nsecond\n');
    final controller = await open();

    final kept = await controller.keep(const KeepCurrent());

    expect(kept, (error: null, done: false));
    expect(current().sides!.value.other, '# Todo\nsecond\n');
    expect(current().busy, isFalse);

    final last = await controller.keep(const KeepCurrent());

    expect(last, (error: null, done: true));
    expect(files(), ['todo.md']);
    expect(File('${dir.path}/todo.md').readAsStringSync(), '# Todo\nmine\n');
  });

  test('keeps the other version', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    final controller = await open();

    final kept = await controller.keep(const KeepOther());

    expect(kept.done, isTrue);
    expect(File('${dir.path}/todo.md').readAsStringSync(), '# Todo\nfirst\n');
  });

  test('resolves a conflict several levels deep', () async {
    write('a/b/c/todo.md', '# Todo\nmine\n');
    write('a/b/c/$first', '# Todo\nfirst\n');
    write('todo.md', '# Root todo\n');
    final controller = await open();

    final kept = await controller.keep(const KeepOther());

    expect(kept.done, isTrue);
    final deep = Directory('${dir.path}/a/b/c');
    expect(deep.listSync().map((e) => e.uri.pathSegments.last), ['todo.md']);
    expect(File('${deep.path}/todo.md').readAsStringSync(), '# Todo\nfirst\n');
    expect(File('${dir.path}/todo.md').readAsStringSync(), '# Root todo\n');
  });

  test('reports files changed since the scan and reloads them', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    final controller = await open();
    write('todo.md', '# Todo\nchanged elsewhere\n');

    final kept = await controller.keep(const KeepOther());

    expect(kept, (error: ResolveError.changedSinceScan, done: false));
    expect(current().sides!.value.current, '# Todo\nchanged elsewhere\n');
    expect(files(), [first, 'todo.md']..sort());
  });

  test('shows why the sides cannot be read', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    final scans = await container.read(folderScansProvider.future);
    final FolderConflict conflict = scans.conflicts.all.single;
    File('${dir.path}/$first').deleteSync();
    final loaded = Completer<ConflictState>();
    container.listen(conflictProvider(conflict), (_, state) {
      if (state.sides != null && !loaded.isCompleted) loaded.complete(state);
    }, fireImmediately: true);

    final state = await loaded.future;

    expect(state.sides!.error, StoreError.notFound);
  });
}
