import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/save_state.dart';
import 'package:truce_editor/documents/ui/save_indicator.dart';

void main() {
  Future<int Function()> pump(WidgetTester tester, SaveState state) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [SaveIndicator(state, onSave: () => saves++)],
          ),
        ),
      ),
    );
    return () => saves;
  }

  testWidgets('tapping it saves edits kept on this device', (tester) async {
    final saves = await pump(tester, SaveState.onDevice);

    await tester.tap(find.byIcon(Icons.save_outlined));

    expect(saves(), 1);
  });

  testWidgets('is no button in other states', (tester) async {
    for (final state in [SaveState.inFolder, SaveState.editing]) {
      await pump(tester, state);
      expect(find.byType(IconButton), findsNothing, reason: '$state');
    }
  });

  testWidgets('shows nothing with nothing to tell', (tester) async {
    await pump(tester, SaveState.none);

    expect(find.byType(Icon), findsNothing);
  });
}
