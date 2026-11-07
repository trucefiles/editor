import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/file_page/ui/place_above_text_tile.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../../support.dart';

void main() {
  final tile = find.byType(PlaceAboveTextTile);

  bool? above(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(tile))
          .read(deviceSettingsProvider)
          .requireValue
          .placeAboveText;

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

  testWidgets('moves the location and name picker to the menu and back', (
    tester,
  ) async {
    final storage = AppStorage(tempFolder().path);
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(storage),
            loadedDeviceSettingsProvider.overrideWithValue(
              DeviceSettings.standard,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PlaceAboveTextTile())),
        ),
      ),
    );
    expect(above(tester), isTrue);
    expect(find.text('At the top of the page'), findsOneWidget);

    await tester.tap(find.text('File location and name picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("In the file's menu"));
    await settle(tester, until: () => above(tester) == false);
    expect(find.text("In the file's menu"), findsOneWidget);

    await tester.tap(find.text('File location and name picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('At the top of the page'));
    await settle(tester, until: () => above(tester) ?? false);
    expect(above(tester), isTrue);
  });
}
