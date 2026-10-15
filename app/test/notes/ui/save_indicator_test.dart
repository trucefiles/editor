import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/ui/save_indicator.dart';

void main() {
  Future<int Function()> pump(WidgetTester tester, EditState state) async {
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
    final saves = await pump(tester, EditState.savedOnDevice);

    await tester.tap(find.byIcon(Icons.save_outlined));

    expect(saves(), 1);
  });

  testWidgets('is no button in other states', (tester) async {
    for (final state in [EditState.saved, EditState.unsaved]) {
      await pump(tester, state);
      expect(find.byType(IconButton), findsNothing, reason: '$state');
    }
  });
}
