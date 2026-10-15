import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/ui/refresh_dialog.dart';

void main() {
  late RefreshSettings? chosen;

  Future<void> open(
    WidgetTester tester, {
    RefreshSettings current = RefreshSettings.standard,
    bool liveAvailable = true,
  }) async {
    chosen = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await showRefreshDialog(
              context,
              current: current,
              liveAvailable: liveAvailable,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('picks a mode and an interval', (tester) async {
    await open(tester);

    await tester.tap(find.text('Periodic'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<Duration>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every 1 min').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      chosen,
      const RefreshSettings(
        mode: RefreshMode.periodic,
        interval: Duration(minutes: 1),
      ),
    );
  });

  testWidgets('offers live updates only where possible', (tester) async {
    await open(tester, liveAvailable: false);

    expect(find.text('Live'), findsNothing);
    expect(find.text('Periodic'), findsOne);
  });

  testWidgets('the interval is off for manual refresh', (tester) async {
    await open(
      tester,
      current: RefreshSettings.standard.copyWith(mode: RefreshMode.manual),
    );

    final menu = tester.widget<DropdownMenu<Duration>>(
      find.byType(DropdownMenu<Duration>),
    );
    expect(menu.enabled, isFalse);
  });

  testWidgets('cancel keeps the setting', (tester) async {
    await open(tester);

    await tester.tap(find.text('Manual'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(chosen, isNull);
  });
}
