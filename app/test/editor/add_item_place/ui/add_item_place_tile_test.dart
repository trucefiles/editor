import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/add_item_place/add_item_place_controller.dart';
import 'package:truce_editor/editor/add_item_place/ui/add_item_place_tile.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../../../support.dart';

void main() {
  final tile = find.byType(AddItemPlaceTile);

  AddItemPlace? place(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(tile))
          .read(addItemPlaceProvider)
          .value;

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
          overrides: [appStorageProvider.overrideWithValue(storage)],
          child: const MaterialApp(home: Scaffold(body: AddItemPlaceTile())),
        ),
      ),
    );
    await settle(tester, until: () => place(tester) != null);
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
