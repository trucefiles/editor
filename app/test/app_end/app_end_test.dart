import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/app_end/app_end.dart';
import 'package:truce_editor/app_end/app_end_source.dart';

void main() {
  /// What the app's end did, in order.
  late List<String> done;

  /// Completes the keep under way.
  late Completer<void> keeping;

  late AppEnd end;

  setUp(() {
    done = [];
    keeping = Completer<void>();
    end = AppEnd(
      keepAll: () {
        done.add('keep');
        return keeping.future;
      },
      quit: () async => done.add('quit'),
    );
  });

  test('a stop asked keeps every edit first, then quits', () async {
    final ended = end.ended(AppEndKind.stopAsked);
    await pumpEventQueue();
    expect(done, ['keep']);

    keeping.complete();
    await ended;
    expect(done, ['keep', 'quit']);
  });

  test(
    'a session ending keeps every edit, and the app keeps running',
    () async {
      keeping.complete();
      await end.ended(AppEndKind.sessionEnding);
      expect(done, ['keep']);
    },
  );

  test(
    'ends that come meanwhile join the keep under way; it quits once',
    () async {
      final first = end.ended(AppEndKind.sessionEnding);
      final second = end.ended(AppEndKind.stopAsked);
      final third = end.ended(AppEndKind.stopAsked);
      keeping.complete();
      await Future.wait([first, second, third]);
      expect(done, ['keep', 'quit']);
    },
  );

  test('an end after the last one was kept keeps again', () async {
    keeping.complete();
    await end.ended(AppEndKind.sessionEnding);
    await end.ended(AppEndKind.sessionEnding);
    expect(done, ['keep', 'keep']);
  });
}
