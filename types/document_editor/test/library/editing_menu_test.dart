import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

/// The right-click menu: Cut, Copy, Paste and Select all, as their keys.
void main() {
  /// The clipboard, held for the test: starts with [text].
  List<String> clipboard(WidgetTester tester, String text) {
    final held = [text];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => switch (call.method) {
        'Clipboard.getData' => <String, Object?>{'text': held.last},
        'Clipboard.setData' => () {
          held.add((call.arguments as Map)['text'] as String);
        }(),
        _ => null,
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return held;
  }

  Future<void> rightClick(WidgetTester tester, String node, int offset) async {
    await tester.tapAt(
      tester.tapPointIn(node, offset),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String item) async {
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  final desktop = TargetPlatformVariant.only(TargetPlatform.linux);

  group('Visual edit', () {
    testWidgets('on text with nothing selected: the caret goes there; '
        'Paste pastes, one undo step', (tester) async {
      final document = TestDocument('buy milk');
      await pumpDocument(tester, document);
      clipboard(tester, 'eggs ');

      await rightClick(tester, paragraphNodeOf(), 4);
      expect(find.text('Cut'), findsNothing);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Select all'), findsOneWidget);
      await choose(tester, 'Paste');

      expect(document.text, 'buy eggs milk');
      document.undo();
      await tester.pumpAndSettle();
      expect(document.text, 'buy milk');
    }, variant: desktop);

    testWidgets('on the selection: Copy and Cut copy it as plain text', (
      tester,
    ) async {
      final document = TestDocument('buy **milk** now');
      await pumpDocument(tester, document);
      final held = clipboard(tester, '');
      await tester.selectWordIn(paragraphNodeOf(), 5);

      await rightClick(tester, paragraphNodeOf(), 5);
      await choose(tester, 'Copy');
      expect(held.last, 'milk');
      expect(document.text, 'buy **milk** now');

      await rightClick(tester, paragraphNodeOf(), 5);
      await choose(tester, 'Cut');
      expect(held.last, 'milk');
      expect(document.text, 'buy  now');
    }, variant: desktop);

    testWidgets('Select all selects the whole document', (tester) async {
      await pumpDocument(tester, TestDocument('a\n\nb'));

      await rightClick(tester, paragraphNodeOf(), 0);
      await choose(tester, 'Select all');

      final selection = SuperEditorInspector.findDocumentSelection()!;
      expect(selection.isCollapsed, isFalse);
      expect(
        (selection.base.nodeId, selection.extent.nodeId),
        (paragraphNodeOf(), paragraphNodeOf(index: 1)),
      );
    }, variant: desktop);
  });

  testWidgets('closes on Escape, a click elsewhere, or a key', (tester) async {
    final document = TestDocument('buy milk');
    await pumpDocument(tester, document);

    await rightClick(tester, paragraphNodeOf(), 4);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Select all'), findsNothing);
    expect(document.text, 'buy milk');

    await rightClick(tester, paragraphNodeOf(), 4);
    await tester.tapAt(tester.tapPointIn(paragraphNodeOf(), 1));
    await tester.pumpAndSettle();
    expect(find.text('Select all'), findsNothing);

    await rightClick(tester, paragraphNodeOf(), 4);
    await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
    await tester.pumpAndSettle();
    expect(find.text('Select all'), findsNothing);

    await rightClick(tester, paragraphNodeOf(), 4);
    await tester.typeImeText('x');
    await tester.pumpAndSettle();
    expect(find.text('Select all'), findsNothing);
  }, variant: desktop);

  testWidgets('Markdown edit: Cut copies and removes the selection', (
    tester,
  ) async {
    final document = TestDocument('buy milk', mode: EditMode.markdown);
    await pumpDocument(tester, document);
    final held = clipboard(tester, '');
    await tester.selectWordIn(lineNodeOf(0), 5);

    await rightClick(tester, lineNodeOf(0), 5);
    await choose(tester, 'Cut');

    expect(held.last, 'milk');
    expect(document.text, 'buy ');
  }, variant: desktop);
}
