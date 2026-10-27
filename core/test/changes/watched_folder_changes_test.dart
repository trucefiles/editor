import 'dart:io';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('truce_watch_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<StreamQueue<RelPath>> watch() async {
    final queue = StreamQueue(
      WatchedFolderChanges(root.path, followed: const _Documents()).changes,
    );
    addTearDown(queue.cancel);
    // Lets the watcher start before files change.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return queue;
  }

  void write(String relPath) {
    File('${root.path}/$relPath').writeCreatingFolders('text');
  }

  test('reports files relative to the folder', () async {
    final queue = await watch();

    write('a.md');

    expect(await queue.next, path('a.md'));
  });

  test('follows subfolders created after it started', () async {
    final queue = await watch();

    write('new/deep/b.md');

    expect(await queue.next, path('new/deep/b.md'));
  });

  test('drops the changes of files it does not follow', () async {
    final queue = await watch();

    write('.git/HEAD');
    write('a.md~');
    write('b.md');

    expect(await queue.next, path('b.md'));
  });

  test('ends when the folder is deleted', () async {
    final all = WatchedFolderChanges(
      root.path,
      followed: const _Documents(),
    ).changes.toList();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await root.delete(recursive: true);

    await expectLater(all, completes);
  });

  test('ends at once if the folder is missing', () async {
    await root.delete();

    final changes = WatchedFolderChanges(
      root.path,
      followed: const _Documents(),
    ).changes;

    expect(await changes.toList(), isEmpty);
  });
}

/// Follows `.md` files outside hidden folders.
final class _Documents implements FileFilter {
  const _Documents();

  @override
  bool includesFolder(RelPath folder) => !folder.name.startsWith('.');

  @override
  bool includesFile(RelPath file) => file.name.endsWith('.md');
}
