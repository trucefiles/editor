import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/settings/ui/add_item_place_tile.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../../support.dart';

void main() {
  final tile = find.byType(AddItemPlaceTile);

  AddItemPlace? place(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(tile))
          .read(deviceSettingsProvider)
          .requireValue
          .addItemPlace;

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

  testWidgets('moves the add buttons below lists and back', (tester) async {
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
          child: const MaterialApp(home: Scaffold(body: AddItemPlaceTile())),
        ),
      ),
    );
    expect(place(tester), AddItemPlace.top);

    await tester.tap(find.text('Show "Add item" below lists'));
    await settle(tester, until: () => place(tester) == AddItemPlace.bottom);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await tester.tap(find.text('Show "Add item" below lists'));
    await settle(tester, until: () => place(tester) == AddItemPlace.top);
    expect(place(tester), AddItemPlace.top);
  });
}
