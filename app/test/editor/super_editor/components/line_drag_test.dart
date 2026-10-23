import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/super_editor/components/line_drag.dart';
import 'package:truce_editor/editor/super_editor/components/line_drop_zone.dart';

void main() {
  testWidgets('the dragged copy shows its text as the row does', (
    tester,
  ) async {
    final row = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => LineDropZone(child: child!),
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
        builder: (_, child) => LineDropZone(child: child!),
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

  /// Four rows of 48 px, one below the other; drops go to [onDrop].
  Future<void> showRows(
    WidgetTester tester, {
    void Function(LineId item, LineId target, {required bool below})? onDrop,
  }) async {
    final rows = [for (final _ in Iterable<int>.generate(4)) GlobalKey()];
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => LineDropZone(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              for (final (index, row) in rows.indexed)
                LineDropTarget(
                  item: LineId(index),
                  step: 24,
                  onDrop: (item, {required below, required levels}) =>
                      onDrop?.call(item, LineId(index), below: below),
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
  }

  /// Takes row [from] by its handle and moves it by [by] in [steps].
  Future<TestGesture> drag(
    WidgetTester tester,
    int from,
    Offset by, {
    int steps = 72,
    void Function()? eachFrame,
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(LineDragHandle).at(from)),
    );
    await tester.pump();
    for (final _ in Iterable<int>.generate(steps)) {
      await gesture.moveBy(by / steps.toDouble());
      await tester.pump(const Duration(milliseconds: 16));
      eachFrame?.call();
    }
    return gesture;
  }

  for (final (direction, from, by) in [
    ('down', 0, const Offset(0, 144)),
    ('up', 3, const Offset(0, -144)),
  ]) {
    testWidgets('dragging $direction past items keeps the gap open', (
      tester,
    ) async {
      await showRows(tester);
      final seen = <double>[];
      // From the middle of the first or last row to that of the other.
      final gesture = await drag(
        tester,
        from,
        by,
        eachFrame: () => seen.add(
          tester
                  .widgetList<AnimatedPadding>(find.byType(AnimatedPadding))
                  .map(
                    (padding) => tester.getSize(find.byWidget(padding)).height,
                  )
                  .sum -
              4 * 48,
        ),
      );
      await gesture.up();

      final open = seen.skipWhile((gap) => gap < 48).toList();
      expect(open, isNotEmpty);
      expect(open, everyElement(closeTo(48, 0.01)), reason: 'gap: $seen');
    });
  }

  testWidgets('a copy past the middle of the next row drops below it', (
    tester,
  ) async {
    final drops = <(LineId, LineId, bool)>[];
    await showRows(
      tester,
      onDrop: (item, target, {required below}) =>
          drops.add((item, target, below)),
    );
    final gesture = await drag(tester, 0, const Offset(0, 48 * 1.4));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, [(const LineId(0), const LineId(1), true)]);
  });
}
