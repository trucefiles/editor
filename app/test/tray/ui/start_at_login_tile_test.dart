import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/tray/login_start.dart';
import 'package:truce_editor/tray/ui/start_at_login_tile.dart';

import '../../support.dart';
import '../../tray/fakes.dart';

/// A desktop that agrees to the login start while [agrees].
final class _LoginStart implements LoginStart {
  bool agrees = true;
  final asked = <bool>[];

  @override
  Future<bool> set({required bool start}) async {
    asked.add(start);
    return agrees;
  }
}

void main() {
  final tile = find.byType(StartAtLoginTile);

  DeviceSettings settings(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(tile))
          .read(deviceSettingsProvider)
          .requireValue;

  /// Lets file writes finish, which complete outside the test's fake
  /// time, until [until] holds; then renders the result.
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

  Future<void> show(WidgetTester tester, LoginStart loginStart) =>
      tester.runAsync(
        () => tester.pumpWidget(
          ProviderScope(
            overrides: [
              appStorageProvider.overrideWithValue(
                AppStorage(tempFolder().path),
              ),
              loadedDeviceSettingsProvider.overrideWithValue(
                DeviceSettings.standard,
              ),
              systemTrayProvider.overrideWithValue(FakeTray()),
              appWindowProvider.overrideWithValue(FakeWindow()),
              loginStartProvider.overrideWithValue(loginStart),
            ],
            child: const MaterialApp(home: Scaffold(body: StartAtLoginTile())),
          ),
        ),
      );

  testWidgets('turned on, it starts the app at login and keeps it in the '
      'tray on close', (tester) async {
    final loginStart = _LoginStart();
    await show(tester, loginStart);

    await tester.tap(find.text('Start in tray at login'));
    await settle(
      tester,
      until: () =>
          settings(tester).startAtLogin && settings(tester).closeToTray,
    );

    expect(loginStart.asked, [true]);
    expect(
      (settings(tester).startAtLogin, settings(tester).closeToTray),
      (true, true),
    );
  });

  testWidgets("a desktop that doesn't allow it changes nothing and says so", (
    tester,
  ) async {
    final loginStart = _LoginStart()..agrees = false;
    await show(tester, loginStart);

    await tester.tap(find.text('Start in tray at login'));
    await tester.pumpAndSettle();

    expect(find.text("The desktop didn't allow it."), findsOneWidget);
    expect(settings(tester).startAtLogin, isFalse);
  });

  testWidgets('nothing where the app has no tray', (tester) async {
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
            loadedDeviceSettingsProvider.overrideWithValue(
              DeviceSettings.standard,
            ),
            systemTrayProvider.overrideWithValue(null),
            loginStartProvider.overrideWithValue(_LoginStart()),
          ],
          child: const MaterialApp(home: Scaffold(body: StartAtLoginTile())),
        ),
      ),
    );
    expect(find.text('Start in tray at login'), findsNothing);
  });
}
