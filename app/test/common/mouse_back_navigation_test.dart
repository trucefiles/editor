import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/mouse_back_navigation.dart';

void main() {
  testWidgets('the mouse back button closes the top screen', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) =>
            MouseBackNavigation(navigator: navigator, child: child!),
        home: const Text('home'),
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('note')),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.startGesture(
      tester.getCenter(find.text('note')),
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await mouse.up();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOne);
    expect(find.text('note'), findsNothing);
  });
}
