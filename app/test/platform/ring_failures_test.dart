import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:truce_editor/platform/ring_failures.dart';

void main() {
  test('a platform failure skips the alert and is logged', () async {
    final logged = <String>[];
    final records = Logger.root.onRecord.listen(
      (record) => logged.add(record.message),
    );
    addTearDown(records.cancel);

    await orSkip(
      'show alert 3',
      () async => throw Exception('no notification service'),
    );

    expect(logged, [
      "Couldn't show alert 3: Exception: no notification service",
    ]);
  });

  test('a bug still ends the call', () async {
    await expectLater(
      orSkip('show alert 3', () async => throw StateError('bug')),
      throwsStateError,
    );
  });
}
