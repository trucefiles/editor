import 'package:collection/collection.dart';
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

  testWidgets('the dragged copy lies on the color of the row\'s surface', (
    tester,
  ) async {
    final row = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          backgroundColor: Colors.orange,
          body: Row(
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
            ],
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

    final copy = tester.widget<Material>(
      find
          .ancestor(of: find.text('copy'), matching: find.byType(Material))
          .first,
    );
    expect(copy.color, Colors.orange);
    await gesture.up();
  });

  for (final (direction, from, step) in [('down', 0, 2.0), ('up', 3, -2.0)]) {
    testWidgets('dragging $direction past items keeps the gap open', (
      tester,
    ) async {
      final rows = [for (final _ in Iterable<int>.generate(4)) GlobalKey()];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final (index, row) in rows.indexed)
                  LineDropTarget(
                    item: LineId(index),
                    step: 24,
                    onDrop: (_, {required below, required levels}) {},
                    child: Row(
                      key: row,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: LineDragHandle(
                            item: LineId(index),
                            row: row,
                            preview: Text('copy $index'),
                            icon: const Icon(Icons.drag_indicator),
                          ),
                        ),
                        Text('item $index'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      double gaps() =>
          tester
              .widgetList<AnimatedPadding>(find.byType(AnimatedPadding))
              .map((padding) => tester.getSize(find.byWidget(padding)).height)
              .sum -
          rows.length * 48;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(LineDragHandle).at(from)),
      );
      await tester.pump();
      final seen = <double>[];
      // From the middle of the first or last row to that of the other.
      for (final _ in Iterable<int>.generate(72)) {
        await gesture.moveBy(Offset(0, step));
        await tester.pump(const Duration(milliseconds: 16));
        seen.add(gaps());
      }
      await gesture.up();

      final open = seen.skipWhile((gap) => gap < 48).toList();
      expect(open, isNotEmpty);
      expect(open, everyElement(closeTo(48, 0.01)), reason: 'gap: $seen');
    });
  }
}
