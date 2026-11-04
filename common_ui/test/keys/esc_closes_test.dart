import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

void main() {
  testWidgets('while open, Esc closes it and goes no further; closed, Esc '
      'goes on', (tester) async {
    final open = ValueNotifier<Object?>(null);
    addTearDown(open.dispose);
    var leaves = 0;
    await tester.pumpWidget(
      MaterialApp(
        // Above the pages, as an app's own Esc that leaves a page.
        builder: (_, child) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => leaves++,
          },
          child: child!,
        ),
        home: EscCloses(
          open: open,
          close: () => open.value = null,
          child: const SizedBox(),
        ),
      ),
    );

    open.value = 'popup';
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect((open.value, leaves), (null, 0));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(leaves, 1);
  });
}
