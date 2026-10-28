import 'dart:async';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  test('passes on the changes of every part', () async {
    final a = StreamController<RelPath>();
    final b = StreamController<RelPath>();
    final queue = StreamQueue(
      MergedFolderChanges([_Changes(a.stream), _Changes(b.stream)]).changes,
    );
    addTearDown(queue.cancel);

    a.add(path('a.md'));
    b.add(path('b.md'));

    expect(await queue.take(2), [path('a.md'), path('b.md')]);
  });

  test('ends once one part ends, and stops the others', () async {
    final a = StreamController<RelPath>();
    var bCancelled = false;
    final b = StreamController<RelPath>(onCancel: () => bCancelled = true);
    final queue = StreamQueue(
      MergedFolderChanges([_Changes(a.stream), _Changes(b.stream)]).changes,
    );

    final hasNext = queue.hasNext;
    unawaited(a.close());

    expect(await hasNext, isFalse);
    expect(bCancelled, isTrue);
  });

  test('no parts end at once', () async {
    expect(await const MergedFolderChanges([]).changes.isEmpty, isTrue);
  });
}

final class _Changes implements FolderChanges {
  const _Changes(this.changes);

  @override
  final Stream<RelPath> changes;
}
