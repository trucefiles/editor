import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/test_helpers.dart';

void main() {
  test('passes on note changes and new conflict copies', () async {
    final changes = SyncthingFolderChanges(
      _FixedChanges([
        'a.md',
        'sub/b.md',
        'a.sync-conflict-20261003-134809-ABCDEFG.md',
      ]),
    );

    expect(await changes.changes.toList(), [
      path('a.md'),
      path('sub/b.md'),
      path('a.sync-conflict-20261003-134809-ABCDEFG.md'),
    ]);
  });

  test("drops Syncthing's own files and every temp file", () async {
    final changes = SyncthingFolderChanges(
      _FixedChanges([
        '.syncthing.a.md.tmp',
        '.syncthing.truce-0123abcd.tmp',
        '~syncthing~a.md.tmp',
        '.stfolder/x',
        '.stversions/a~20261003-134809.md',
        '.stversions/a.sync-conflict-20261003-134809-ABCDEFG.md',
      ]),
    );

    expect(await changes.changes.toList(), isEmpty);
  });
}

/// Emits [paths], then ends.
final class _FixedChanges implements FolderChanges {
  _FixedChanges(this.paths);

  final List<String> paths;

  @override
  Stream<RelPath> get changes => Stream.fromIterable(paths.map(path));
}
