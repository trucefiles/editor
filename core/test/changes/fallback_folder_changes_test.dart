import 'dart:async';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  test('goes on with the fallback once the primary ends, after asking '
      'to list again', () async {
    final changes = FallbackFolderChanges(
      _FixedChanges(['a.md']),
      _FixedChanges(['b.md']),
    );

    expect(await changes.changes.toList(), [
      PathChanged(path('a.md')),
      const ListAgain(),
      PathChanged(path('b.md')),
    ]);
  });

  test('tells when it is on the fallback', () async {
    final primary = StreamController<ChangeHint>();
    final changes = FallbackFolderChanges(
      _StreamChanges(primary),
      _FixedChanges([]),
    );
    final done = changes.changes.toList();
    await Future<void>.delayed(Duration.zero);
    expect(changes.isOnFallback, isFalse);

    await primary.close();
    await done;

    expect(changes.isOnFallback, isTrue);
  });

  test('never starts the fallback while the primary runs', () async {
    final primary = StreamController<ChangeHint>();
    final fallback = StreamController<ChangeHint>();
    final changes = FallbackFolderChanges(
      _StreamChanges(primary),
      _StreamChanges(fallback),
    );

    final subscription = changes.changes.listen((_) {});
    primary.add(PathChanged(path('a.md')));
    await Future<void>.delayed(Duration.zero);

    expect(fallback.hasListener, isFalse);
    expect(changes.isOnFallback, isFalse);
    await subscription.cancel();
    expect(primary.hasListener, isFalse);
  });
}

/// Emits [paths], then ends.
final class _FixedChanges implements FolderChanges {
  _FixedChanges(this.paths);

  final List<String> paths;

  @override
  Stream<ChangeHint> get changes =>
      Stream.fromIterable(paths.map((name) => PathChanged(path(name))));
}

final class _StreamChanges implements FolderChanges {
  _StreamChanges(this._controller);

  final StreamController<ChangeHint> _controller;

  @override
  Stream<ChangeHint> get changes => _controller.stream;
}
