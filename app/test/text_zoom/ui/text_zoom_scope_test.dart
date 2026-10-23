import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_controller.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';
import 'package:truce_editor/text_zoom/ui/note_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scope.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_title.dart';

import '../../support.dart';

void main() {
  final page = find.text('page');
  final note = find.text('note');
  final toast = find.text(textZoomTitle(TextZoomTarget.notes));

  TextZoom zoom(
    WidgetTester tester, [
    TextZoomTarget of = TextZoomTarget.notes,
  ]) =>
      ProviderScope.containerOf(tester.element(page))
          .read(textZoomProvider(of));

  double scaled(WidgetTester tester, Finder text) =>
      MediaQuery.textScalerOf(tester.element(text)).scale(10);

  var taps = 0;

  /// An app with a page in [TextZoomScope], with note text on it.
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
                  const NoteTextZoom(child: Text('note')),
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

  testWidgets('shows the app at its zoom, note text at its own', (
    tester,
  ) async {
    await show(tester);

    expect(scaled(tester, page), 15);
    expect(scaled(tester, note), 10);
  });

  testWidgets('keys zoom note text only', (tester) async {
    await show(tester);
    await pressCtrlPlus(tester);

    expect(zoom(tester).percent, 110);
    expect(scaled(tester, note), 11);
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
