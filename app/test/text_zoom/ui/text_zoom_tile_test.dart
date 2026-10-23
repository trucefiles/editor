import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_controller.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_tile.dart';

import '../../support.dart';

void main() {
  final tile = find.byType(TextZoomTile);

  TextZoom? size(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(tile))
          .read(textZoomProvider)
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

  testWidgets('the slider sets the global text zoom', (tester) async {
    final storage = AppStorage(tempFolder().path);
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [appStorageProvider.overrideWithValue(storage)],
          child: const MaterialApp(home: Scaffold(body: TextZoomTile())),
        ),
      ),
    );
    await settle(tester, until: () => size(tester) != null);
    expect(find.text('Global text zoom'), findsOne);
    expect(find.text('100 %'), findsOne);

    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(slider.centerRight - const Offset(30, 0));
    await settle(tester, until: () => size(tester) != TextZoom.normal);

    expect(size(tester)!.percent, greaterThan(180));
    expect(find.text(size(tester).toString()), findsWidgets);
  });
}
