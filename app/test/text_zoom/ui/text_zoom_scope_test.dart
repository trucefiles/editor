import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_controller.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scope.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_title.dart';

import '../../support.dart';

void main() {
  final page = find.text('page');
  final toast = find.text(textZoomTitle);

  TextZoom? zoom(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(page))
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
  }

  var taps = 0;

  /// An app with a page in [TextZoomScope], the setting loaded.
  Future<void> show(WidgetTester tester) async {
    taps = 0;
    final storage = AppStorage(tempFolder().path);
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [appStorageProvider.overrideWithValue(storage)],
          child: MaterialApp(
            builder: (context, child) => TextZoomScope(child: child!),
            home: Scaffold(
              body: Column(
                children: [
                  const Text('page'),
                  TextButton(onPressed: () => taps++, child: const Text('tap')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester, until: () => zoom(tester) != null);
  }

  Future<void> pressCtrlPlus(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester, until: () => zoom(tester) != TextZoom.normal);
  }

  testWidgets('zooms the text of everything in it', (tester) async {
    await show(tester);
    await pressCtrlPlus(tester);

    expect(MediaQuery.textScalerOf(tester.element(page)).scale(10), 11);
  });

  testWidgets('a zoom by keys shows the toast, which hides after a moment', (
    tester,
  ) async {
    await show(tester);
    expect(toast, findsNothing);

    await pressCtrlPlus(tester);
    expect(toast, findsOne);
    expect(find.text('110 %'), findsOne);

    await tester.pump(TextZoomScope.toastTime);
    expect(toast, findsNothing);
  });

  testWidgets('beside the toast, the page takes taps as before', (
    tester,
  ) async {
    await show(tester);
    await pressCtrlPlus(tester);
    expect(toast, findsOne);

    await tester.tap(find.text('tap'));
    expect(taps, 1);
  });
}
