import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_controller.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_tile.dart';

import '../../support.dart';

void main() {
  final tile = find.byType(TextZoomTile);

  TextZoom size(WidgetTester tester, TextZoomTarget target) =>
      ProviderScope.containerOf(tester.element(tile.first))
          .read(textZoomProvider(target));

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

  for (final (target, title) in [
    (TextZoomTarget.notes, 'Note text size'),
    (TextZoomTarget.app, 'App text size'),
  ]) {
    testWidgets('the slider sets the ${title.toLowerCase()} only', (
      tester,
    ) async {
      final storage = AppStorage(tempFolder().path);
      final zooms = (await tester.runAsync(() => savedTextZoomsIn(storage)))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(storage),
            savedTextZoomsProvider.overrideWithValue(zooms),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  for (final target in TextZoomTarget.values)
                    TextZoomTile(target),
                ],
              ),
            ),
          ),
        ),
      );
      final row = find.widgetWithText(TextZoomTile, title);
      expect(row, findsOne);
      expect(find.text('100 %'), findsNWidgets(2));

      final slider = tester.getRect(
        find.descendant(of: row, matching: find.byType(Slider)),
      );
      await tester.tapAt(slider.centerRight - const Offset(30, 0));
      await settle(
        tester,
        until: () => size(tester, target) != TextZoom.normal,
      );

      expect(size(tester, target).percent, greaterThan(180));
      expect(
        find.descendant(
          of: row,
          matching: find.text('${size(tester, target)}'),
        ),
        findsOne,
      );
      final other = TextZoomTarget.values.firstWhere((t) => t != target);
      expect(size(tester, other), TextZoom.normal);
    });
  }
}
