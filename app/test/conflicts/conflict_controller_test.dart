import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/conflicts/conflict_controller.dart';
import 'package:truce_editor/conflicts/conflict_sides.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

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
    await container.read(folderListStoreProvider).save([folderAt(dir)]);
  });

  void write(String name, String text) =>
      File('${dir.path}/$name')..writeCreatingFolders(text);

  List<String> files() =>
      [for (final entry in dir.listSync()) entry.uri.pathSegments.last]..sort();

  late ProviderSubscription<ConflictState> watching;
  late NotifierProvider<ConflictController, ConflictState> provider;

  ConflictState current() => container.read(provider);

  /// Watches the screen of [conflict], as the screen does.
  void watch(FolderConflict conflict) {
    provider = conflictProvider(conflict);
    watching = container.listen(provider, (_, _) {});
  }

  /// Waits until the sides shown loaded, or failed to.
  Future<ConflictState> loaded() async {
    final done = Completer<ConflictState>();
    final waiting = container.listen(provider, (_, state) {
      if (state is! CompareLoading && !done.isCompleted) done.complete(state);
    }, fireImmediately: true);
    final state = await done.future;
    waiting.close();
    return state;
  }

  /// The sides shown.
  ConflictSides sides() => switch (current()) {
    CompareShowing(:final sides) => sides,
    final other => throw StateError('no sides show: $other'),
  };

  /// Opens the scanned conflict and waits until its sides are loaded.
  Future<ConflictController> open() async {
    final scans = await container.read(folderContentsProvider.future);
    watch(scans.conflicts.all.single);
    await loaded();
    return container.read(provider.notifier);
  }

  test('loads both sides of the oldest copy', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    write(second, '# Todo\nsecond\n');

    await open();

    expect(sides().current, '# Todo\nmine\n');
    expect(sides().other, '# Todo\nfirst\n');
  });

  test('resolves and rescans when the screen closes meanwhile', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    final controller = await open();

    final kept = controller.keep(const KeepCurrent());
    watching.close();

    expect(await kept, isNull, reason: 'the screen closed first');
    final scans = await container.read(folderContentsProvider.future);
    expect(scans.conflicts.all, isEmpty);
  });

  test('moves on to the next copy, then is done', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    write(second, '# Todo\nsecond\n');
    final controller = await open();

    final kept = await controller.keep(const KeepCurrent());

    expect(kept, isA<KeepAnswer>().having((a) => a.done, 'done', isFalse));
    expect(kept!.error, isNull);
    await loaded();
    expect(sides().other, '# Todo\nsecond\n');

    final last = await controller.keep(const KeepCurrent());

    expect(last!.done, isTrue);
    expect(last.error, isNull);
    expect(files(), ['todo.md']);
    expect(File('${dir.path}/todo.md').readAsStringSync(), '# Todo\nmine\n');
  });

  test('keeps the other version', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    final controller = await open();

    final kept = await controller.keep(const KeepOther());

    expect(kept!.done, isTrue);
    expect(File('${dir.path}/todo.md').readAsStringSync(), '# Todo\nfirst\n');
  });

  test('resolves a conflict several levels deep', () async {
    write('a/b/c/todo.md', '# Todo\nmine\n');
    write('a/b/c/$first', '# Todo\nfirst\n');
    write('todo.md', '# Root todo\n');
    final controller = await open();

    final kept = await controller.keep(const KeepOther());

    expect(kept!.done, isTrue);
    final deep = Directory('${dir.path}/a/b/c');
    expect(deep.listSync().map((e) => e.uri.pathSegments.last), ['todo.md']);
    expect(File('${deep.path}/todo.md').readAsStringSync(), '# Todo\nfirst\n');
    expect(File('${dir.path}/todo.md').readAsStringSync(), '# Root todo\n');
  });

  test('restores a document deleted several levels deep', () async {
    write('a/b/c/$first', '# Todo\nfirst\n');
    final controller = await open();
    expect(sides().current, isNull);

    final kept = await controller.keep(const KeepOther());

    expect(kept!.done, isTrue);
    final deep = Directory('${dir.path}/a/b/c');
    expect(deep.listSync().map((e) => e.uri.pathSegments.last), ['todo.md']);
    expect(File('${deep.path}/todo.md').readAsStringSync(), '# Todo\nfirst\n');
  });

  test('reports files changed since the scan and reloads them', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    final controller = await open();
    write('todo.md', '# Todo\nchanged elsewhere\n');

    final kept = await controller.keep(const KeepOther());

    expect(kept!.error, ResolveError.changedSinceScan);
    expect(kept.done, isFalse);
    await loaded();
    expect(sides().current, '# Todo\nchanged elsewhere\n');
    expect(files(), [first, 'todo.md']..sort());
  });

  test('loads the sides again at the next scan after they failed', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    final scans = await container.read(folderContentsProvider.future);
    // Changed since the scan, so the sides can't be loaded from it.
    write('todo.md', '# Todo\nchanged\n');
    watch(scans.conflicts.all.single);
    expect(
      await loaded(),
      isA<CompareLoadFailed<FolderConflict, ConflictSides>>().having(
        (s) => s.error,
        'error',
        StoreError.changedSinceRead,
      ),
    );

    await container.read(folderContentsProvider.notifier).refresh();
    await loaded();

    expect(sides().current, '# Todo\nchanged\n');
  });

  test('shows why the sides cannot be read', () async {
    write('todo.md', '# Todo\nmine\n');
    write(first, '# Todo\nfirst\n');
    final scans = await container.read(folderContentsProvider.future);
    final FolderConflict conflict = scans.conflicts.all.single;
    File('${dir.path}/$first').deleteSync();
    watch(conflict);

    final state = await loaded();

    expect(
      state,
      isA<CompareLoadFailed<FolderConflict, ConflictSides>>().having(
        (s) => s.error,
        'error',
        StoreError.notFound,
      ),
    );
  });
}
