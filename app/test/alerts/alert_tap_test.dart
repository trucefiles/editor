import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/alerts/alert_tap.dart';

import 'alert_samples.dart';

void main() {
  test("a tap's payload reads back as the same tap", () {
    final alert = eventAlert('Dentist', at: DateTime.utc(2026, 11, 17, 9));
    final tap = AlertTap(alert, number: 7, shown: AlertShown.alarm);

    final read = AlertTap.fromPayload(tap.payload)!;

    expect((read.alert, read.number, read.shown), (alert, 7, AlertShown.alarm));
  });

  test('a payload that is none of ours is no tap', () {
    for (final payload in [null, '', 'not json', '{"number": 1}', '[]']) {
      expect(AlertTap.fromPayload(payload), isNull, reason: payload);
    }
  });
}
