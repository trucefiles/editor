import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/screen_shortcuts.dart';

void main() {
  late int presses;
  final navigator = GlobalKey<NavigatorState>();

  setUp(() => presses = 0);

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: ScreenShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
              presses++,
        },
        child: const Scaffold(body: Text('screen')),
      ),
    ),
  );

  Future<void> pressCtrl1(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }

  testWidgets('runs a binding with nothing focused', (tester) async {
    await show(tester);

    await pressCtrl1(tester);

    expect(presses, 1);
  });

  testWidgets('ignores other keys', (tester) async {
    await show(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);

    expect(presses, 0);
  });

  testWidgets('does nothing while a dialog is above the screen', (
    tester,
  ) async {
    await show(tester);
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const Text('dialog'),
      ),
    );
    await tester.pumpAndSettle();

    await pressCtrl1(tester);

    expect(presses, 0);
  });
}
