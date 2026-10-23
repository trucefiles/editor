import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/super_editor/components/line_drag.dart';

void main() {
  testWidgets('the dragged copy shows its text as the row does', (
    tester,
  ) async {
    final row = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            // Zoomed, like note text inside the app.
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Row(
              key: row,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: LineDragHandle(
                    item: const LineId(1),
                    row: row,
                    preview: const Text('copy'),
                    icon: const Icon(Icons.drag_indicator),
                  ),
                ),
                const Text('item'),
              ],
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LineDragHandle)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();

    expect(
      MediaQuery.textScalerOf(tester.element(find.text('copy'))).scale(10),
      20,
    );
    await gesture.up();
  });
}
