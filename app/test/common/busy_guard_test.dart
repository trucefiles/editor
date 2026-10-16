import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/busy_guard.dart';

void main() {
  late BusyGuard guard;

  setUp(() => guard = BusyGuard());

  test('runs an action when idle', () async {
    expect(await guard.run(() async => 1), 1);
    expect(guard.busy, isFalse);
  });

  test('drops a call while an action runs', () async {
    final first = Completer<int>();
    final running = guard.run(() => first.future);
    var secondRan = false;

    final second = await guard.run(() async => secondRan = true);
    expect(guard.busy, isTrue);
    first.complete(1);

    expect(await running, 1);
    expect(second, isNull);
    expect(secondRan, isFalse);
    expect(guard.busy, isFalse);
  });

  test('is free again after an action failed', () async {
    await expectLater(
      guard.run<void>(() async => throw StateError('bug')),
      throwsStateError,
    );

    expect(await guard.run(() async => 2), 2);
  });
}
