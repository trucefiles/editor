import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_editor/alerts/alarm_controls.dart';
import 'package:truce_editor/alerts/alert_tap.dart';
import 'package:truce_editor/alerts/ui/alarm_screen.dart';

import '../alert_samples.dart';

/// Controls that keep what they were asked.
final class _Controls implements AlarmControls {
  final asked = <String>[];

  @override
  Future<void> showOverLock({required bool show}) async =>
      asked.add(show ? 'over lock' : 'not over lock');

  @override
  Future<void> snooze(AlertTap alarm) async => asked.add('snooze');

  @override
  Future<void> stop(AlertTap alarm) async => asked.add('stop');
}

void main() {
  setUpAll(initializeDateFormatting);

  final alarm = AlertTap(
    eventAlert('Dentist', at: DateTime(2026, 11, 17, 8, 45)),
    number: 1,
    shown: AlertShown.alarm,
  );

  /// Shows the alarm screen over a page; what it closed with comes to
  /// [closed].
  Future<void> show(
    WidgetTester tester,
    _Controls controls,
    List<bool?> closed,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => closed.add(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AlarmScreen(alarm, controls: controls),
                  ),
                ),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
  }

  for (final (button, asked, open) in [
    ('Dismiss', 'stop', false),
    ('Snooze 10 min', 'snooze', false),
    ('Open', 'stop', true),
  ]) {
    testWidgets('$button stops the ringing, closes the screen and tells '
        'whether to open the alert', (tester) async {
      final (controls, closed) = (_Controls(), <bool?>[]);
      await show(tester, controls, closed);
      expect(find.text('Dentist'), findsOneWidget);

      await tester.tap(find.text(button));
      await tester.pumpAndSettle();

      expect(controls.asked, ['over lock', asked, 'not over lock']);
      expect(closed, [open]);
    });
  }

  testWidgets('back is Dismiss: the ringing stops as the screen closes', (
    tester,
  ) async {
    final (controls, closed) = (_Controls(), <bool?>[]);
    await show(tester, controls, closed);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(controls.asked, ['over lock', 'stop', 'not over lock']);
    expect(closed, [false]);
  });
}
