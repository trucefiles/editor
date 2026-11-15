import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/mouse_back_navigation.dart';

void main() {
  /// Shows a screen over home, the mouse back button handled if [enabled],
  /// and presses that button.
  Future<void> pressBackOverScreen(
    WidgetTester tester, {
    required bool enabled,
  }) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => MouseBackNavigation(
          navigator: navigator,
          enabled: enabled,
          child: child!,
        ),
        home: const Text('home'),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('document')),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.startGesture(
      tester.getCenter(find.text('document')),
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await mouse.up();
    await tester.pumpAndSettle();
  }

  testWidgets('the mouse back button closes the top screen', (tester) async {
    await pressBackOverScreen(tester, enabled: true);

    expect(find.text('home'), findsOne);
    expect(find.text('document'), findsNothing);
  });

  testWidgets('where the system turns the button into Back itself, the app '
      'leaves it alone, so one press closes one screen', (tester) async {
    await pressBackOverScreen(tester, enabled: false);

    expect(find.text('document'), findsOne);
  });
}
