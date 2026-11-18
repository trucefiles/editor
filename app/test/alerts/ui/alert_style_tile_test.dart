import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/alerts/alert_permissions.dart';
import 'package:truce_editor/alerts/alert_style.dart';
import 'package:truce_editor/alerts/ui/alert_style_tile.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../../support.dart';

/// Permissions the user grants once asked.
final class _Permissions implements AlertPermissions {
  _Permissions({required this.notify});

  bool notify;
  var fullScreenAsks = 0;

  @override
  Future<bool> mayNotify() async => notify;

  @override
  Future<bool> askToNotify() async => notify = true;

  @override
  Future<void> askForFullScreen() async => fullScreenAsks++;
}

void main() {
  final tile = find.byType(AlertStyleTile);

  AlertStyle style(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(tile))
          .read(deviceSettingsProvider)
          .requireValue
          .alertStyle;

  /// Lets file writes and permission answers finish, which complete
  /// outside the test's fake time, until [until] holds; then renders.
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

  Future<void> show(
    WidgetTester tester,
    AlertPermissions permissions, {
    bool chooses = true,
  }) => tester.runAsync(
    () => tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
          loadedDeviceSettingsProvider.overrideWithValue(
            DeviceSettings.standard,
          ),
          choosesAlertStyleProvider.overrideWithValue(chooses),
          alertPermissionsProvider.overrideWithValue(permissions),
        ],
        child: const MaterialApp(home: Scaffold(body: AlertStyleTile())),
      ),
    ),
  );

  testWidgets('alerts ring as a notification until the user picks Alarm, '
      'which asks to show full screen', (tester) async {
    final permissions = _Permissions(notify: true);
    await show(tester, permissions);
    expect(find.text('Notification'), findsOneWidget);

    await tester.tap(find.text('Calendar alerts ring as'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alarm'));
    await settle(tester, until: () => permissions.fullScreenAsks > 0);

    expect(style(tester), AlertStyle.alarm);
    expect(permissions.fullScreenAsks, 1);
  });

  testWidgets('while notifications are off, a row says alerts are silent; '
      'a tap asks to allow them', (tester) async {
    final permissions = _Permissions(notify: false);
    await show(tester, permissions);
    await settle(
      tester,
      until: () => find.text('Alerts are silent').evaluate().isNotEmpty,
    );

    await tester.tap(find.text('Alerts are silent'));
    await settle(
      tester,
      until: () => find.text('Alerts are silent').evaluate().isEmpty,
    );
    expect(find.text('Alerts are silent'), findsNothing);
  });

  testWidgets('nothing where alerts ring only one way', (tester) async {
    await show(tester, _Permissions(notify: true), chooses: false);
    expect(find.text('Calendar alerts ring as'), findsNothing);
  });
}
