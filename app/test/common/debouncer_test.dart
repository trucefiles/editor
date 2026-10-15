import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/debouncer.dart';

void main() {
  late int runs;
  late Debouncer debouncer;

  const settle = Duration(milliseconds: 50);
  const maxWait = Duration(milliseconds: 300);

  setUp(() {
    runs = 0;
    debouncer = Debouncer(() => runs++, settle: settle, maxWait: maxWait);
    addTearDown(debouncer.cancel);
  });

  Future<void> wait(Duration duration) => Future<void>.delayed(duration);

  test('runs once after calls stop', () async {
    debouncer
      ..call()
      ..call()
      ..call();
    await wait(settle * 2);

    expect(runs, 1);
  });

  test('waits while calls keep coming, at most for the longest wait', () async {
    for (var i = 0; i < 4; i++) {
      debouncer();
      await wait(settle ~/ 2);
    }
    expect(runs, 0);

    for (var i = 0; i < 8; i++) {
      debouncer();
      await wait(settle ~/ 2);
    }
    expect(runs, 1);
  });

  test('runs again for later calls', () async {
    debouncer();
    await wait(settle * 2);
    debouncer();
    await wait(settle * 2);

    expect(runs, 2);
  });

  test('a cancelled run never happens', () async {
    debouncer
      ..call()
      ..cancel();
    await wait(settle * 2);

    expect(runs, 0);
  });
}
