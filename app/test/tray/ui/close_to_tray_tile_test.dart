import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/ui/settings_screen.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/tray/close_to_tray_controller.dart';

import '../../support.dart';
import '../fakes.dart';

void main() {
  late FakeTray tray;
  late FakeWindow window;

  setUp(() {
    tray = FakeTray();
    window = FakeWindow();
  });

  final settings = find.byType(SettingsScreen);

  /// Lets file reads and writes finish, which complete outside the test's
  /// fake time, until [until] holds; then renders the result.
  Future<void> settle(
    WidgetTester tester, {
    required bool Function() until,
  }) async {
    for (var step = 0; step < 100 && !until(); step++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpSettings(WidgetTester tester, {bool withTray = true}) async {
    final storage = AppStorage(tempFolder().path);
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(storage),
            systemTrayProvider.overrideWithValue(withTray ? tray : null),
            appWindowProvider.overrideWithValue(window),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      ),
    );
    await settle(
      tester,
      until: () =>
          settings.evaluate().isNotEmpty &&
          ProviderScope.containerOf(tester.element(settings))
              .read(closeToTrayProvider)
              .hasValue,
    );
  }

  /// Taps the setting and lets its file write finish, until the window
  /// was told [hideOnClose].
  Future<void> toggle(WidgetTester tester, {required bool hideOnClose}) async {
    await tester.tap(find.text('Keep running in tray'));
    await tester.pumpAndSettle();
    await settle(tester, until: () => window.hideOnClose == hideOnClose);
  }

  bool switchedOn(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  testWidgets('turns keeping running in the tray off and on', (tester) async {
    await pumpSettings(tester);
    expect(switchedOn(tester), isTrue);

    await toggle(tester, hideOnClose: false);
    expect(window.hideOnClose, isFalse);
    expect(tray.shown, isFalse);

    expect(switchedOn(tester), isFalse);
    await toggle(tester, hideOnClose: true);
    expect(window.hideOnClose, isTrue);
  });

  testWidgets('says when no tray can take the icon', (tester) async {
    tray.hasTray = false;
    await pumpSettings(tester);

    expect(find.text('No tray on this desktop: closing quits'), findsOneWidget);
  });

  testWidgets('has no tray setting where the platform has no tray', (
    tester,
  ) async {
    await pumpSettings(tester, withTray: false);

    expect(find.text('Keep running in tray'), findsNothing);
  });
}
