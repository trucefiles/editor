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

  Future<StreamQueue<ChangeHint>> watch() async {
    final queue = StreamQueue(WatchedLiveChanges(root.path).below(null));
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

    expect(await queue.next, PathChanged(path('a.md')));
  });

  test('follows subfolders created after it started', () async {
    final queue = await watch();

    write('new/deep/b.md');

    expect(await queue.next, PathChanged(path('new/deep/b.md')));
  });

  test('watches only its subfolder, with paths in the folder', () async {
    Directory('${root.path}/work').createSync();
    final queue = StreamQueue(
      WatchedLiveChanges(root.path).below(path('work')),
    );
    addTearDown(queue.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    write('other.md');
    write('work/a.md');

    expect(await queue.next, PathChanged(path('work/a.md')));
  });

  test('ends when the folder is deleted', () async {
    final all = WatchedLiveChanges(root.path).below(null).toList();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await root.delete(recursive: true);

    await expectLater(all, completes);
  });

  test('ends at once if the folder is missing', () async {
    await root.delete();

    final changes = WatchedLiveChanges(root.path).below(null);

    expect(await changes.toList(), isEmpty);
  });
}
