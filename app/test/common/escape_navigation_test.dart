import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/escape_navigation.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) =>
            EscapeNavigation(navigator: navigator, child: child!),
        home: const Text('home'),
      ),
    );
  }

  Future<void> push(WidgetTester tester, Widget page) async {
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Esc closes the top screen, with nothing focused', (
    tester,
  ) async {
    await start(tester);
    await push(tester, const Scaffold(body: Text('form')));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOne);
    expect(find.text('form'), findsNothing);
  });

  testWidgets('Esc closes a form while its text field has the focus', (
    tester,
  ) async {
    await start(tester);
    await push(tester, const Scaffold(body: TextField(autofocus: true)));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOne);
  });

  testWidgets("Esc runs a screen's own leave check", (tester) async {
    var asked = false;
    await start(tester);
    await push(
      tester,
      PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, _) => asked = true,
        child: const Scaffold(body: Text('form')),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(asked, isTrue);
    expect(find.text('form'), findsOne);
  });

  testWidgets('Esc closes a dialog first, then the screen under it', (
    tester,
  ) async {
    await start(tester);
    await push(tester, const Scaffold(body: Text('form')));
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);
    expect(find.text('form'), findsOne);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('form'), findsNothing);
  });

  testWidgets('Esc closes a menu, not the screen under it', (tester) async {
    await start(tester);
    await push(
      tester,
      Scaffold(
        body: MenuAnchor(
          menuChildren: [
            MenuItemButton(onPressed: () {}, child: const Text('item')),
          ],
          // The focus stays on its button, as from the keyboard.
          builder: (context, menu, _) => TextButton(
            autofocus: true,
            onPressed: menu.open,
            child: const Text('form'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('form'));
    await tester.pumpAndSettle();
    expect(find.text('item'), findsOne);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('item'), findsNothing);
    expect(find.text('form'), findsOne);
  });

  testWidgets("Esc doesn't close a dialog that the user must answer", (
    tester,
  ) async {
    await start(tester);
    await push(tester, const Scaffold(body: Text('form')));
    unawaited(
      showDialog<void>(
        context: navigator.currentContext!,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOne);
  });
}
