import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/fresh_runs.dart';

void main() {
  late List<Completer<int>> runs;
  late FreshRuns<int> fresh;

  setUp(() {
    runs = [];
    fresh = FreshRuns(() {
      final run = Completer<int>();
      runs.add(run);
      return run.future;
    });
  });

  test('runs the task when idle', () async {
    final result = fresh.run();
    runs.single.complete(1);

    expect(await result, 1);
  });

  test('a call during a run gets a follow-up run', () async {
    final first = fresh.run();
    final second = fresh.run();
    await pumpEventQueue();
    expect(runs, hasLength(1));

    runs[0].complete(1);
    await pumpEventQueue();
    expect(runs, hasLength(2));
    runs[1].complete(2);

    expect(await first, 1);
    expect(await second, 2);
  });

  test('calls during one run share the follow-up run', () async {
    final first = fresh.run();
    final second = fresh.run();
    final third = fresh.run();

    runs[0].complete(1);
    await pumpEventQueue();
    runs[1].complete(2);

    expect(await first, 1);
    expect(await second, 2);
    expect(await third, 2);
    expect(runs, hasLength(2));
  });

  test('a failed run does not stop the follow-up run', () async {
    final first = fresh.run();
    final second = fresh.run();

    runs[0].completeError(StateError('failed'));
    await expectLater(first, throwsStateError);
    await pumpEventQueue();
    runs[1].complete(2);

    expect(await second, 2);
  });
}
