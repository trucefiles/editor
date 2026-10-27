import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_controller.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';
import 'package:truce_editor/text_zoom/ui/document_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scope.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_title.dart';

import '../../support.dart';

void main() {
  final page = find.text('page');
  final document = find.text('document');
  final toast = find.text(textZoomTitle(TextZoomTarget.documents));

  TextZoom zoom(
    WidgetTester tester, [
    TextZoomTarget of = TextZoomTarget.documents,
  ]) =>
      ProviderScope.containerOf(tester.element(page))
          .read(textZoomProvider(of));

  double scaled(WidgetTester tester, Finder text) =>
      MediaQuery.textScalerOf(tester.element(text)).scale(10);

  var taps = 0;

  /// An app with a page in [TextZoomScope], with document text on it.
  Future<void> show(WidgetTester tester) async {
    taps = 0;
    final storage = AppStorage(tempFolder().path);
    final zooms = (await tester.runAsync(
      () => savedTextZoomsIn(storage, {
        TextZoomTarget.app: TextZoom.closestTo(150),
      }),
    ))!;
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(storage),
            savedTextZoomsProvider.overrideWithValue(zooms),
          ],
          child: MaterialApp(
            builder: (context, child) => TextZoomScope(child: child!),
            home: Scaffold(
              body: Column(
                children: [
                  const Text('page'),
                  const DocumentTextZoom(child: Text('document')),
                  TextButton(onPressed: () => taps++, child: const Text('tap')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pressCtrlPlus(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets('shows the app at its zoom, document text at its own', (
    tester,
  ) async {
    await show(tester);

    expect(scaled(tester, page), 15);
    expect(scaled(tester, document), 10);
  });

  testWidgets('keys zoom document text only', (tester) async {
    await show(tester);
    await pressCtrlPlus(tester);

    expect(zoom(tester).percent, 110);
    expect(scaled(tester, document), 11);
    expect(scaled(tester, page), 15);
    expect(zoom(tester, TextZoomTarget.app).percent, 150);
  });

  testWidgets('a zoom by keys shows the toast, which hides after a moment', (
    tester,
  ) async {
    await show(tester);
    expect(toast, findsNothing);

    await pressCtrlPlus(tester);
    expect(toast, findsOne);
    expect(find.text('110 %'), findsOne);

    await tester.pump(const Duration(seconds: 2));
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
