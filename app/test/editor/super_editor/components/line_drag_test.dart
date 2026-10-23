import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/super_editor/components/line_drag.dart';
import 'package:truce_editor/editor/super_editor/components/line_drop_zone.dart';

/// A drop: the dropped item, the row it went next to, whether below it,
/// and by how many levels it was shifted.
typedef Drop = (LineId item, LineId target, bool below, int levels);

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

  /// [count] rows of 48 px, [spacing] apart (as note lines are), one
  /// below the other; drops go to [onDrop].
  Future<void> showRows(
    WidgetTester tester, {
    void Function(Drop drop)? onDrop,
    double spacing = 0,
    ValueListenable<int>? count,
  }) async {
    final rows = [for (final _ in Iterable<int>.generate(4)) GlobalKey()];
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => LineDropZone(child: child!),
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: count ?? ValueNotifier(rows.length),
            builder: (context, count, _) => Column(
              children: [
                for (final (index, row) in rows.take(count).indexed)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing),
                    child: LineDropTarget(
                      item: LineId(index),
                      step: 24,
                      onDrop: (item, {required below, required levels}) =>
                          onDrop?.call((item, LineId(index), below, levels)),
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
                  ),
              ],
            ),
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

  for (final (direction, from, by, spacing) in [
    ('down', 0, const Offset(0, 144), 0.0),
    ('up', 3, const Offset(0, -144), 0.0),
    ('down over spaced rows', 0, const Offset(0, 144 + 3 * 8.0), 8.0),
  ]) {
    testWidgets('dragging $direction keeps the gap open past items', (
      tester,
    ) async {
      await showRows(tester, spacing: spacing);
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
    final drops = <Drop>[];
    await showRows(tester, onDrop: drops.add);
    final gesture = await drag(tester, 0, const Offset(0, 48 * 1.4));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, [(const LineId(0), const LineId(1), true, 0)]);
  });

  testWidgets('scrolling during a drag keeps the drop places', (tester) async {
    final drops = <(LineId, bool)>[];
    final scroll = ScrollController();
    final rows = [for (final _ in Iterable<int>.generate(20)) GlobalKey()];
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => LineDropZone(child: child!),
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              for (final (index, row) in rows.indexed)
                LineDropTarget(
                  item: LineId(index),
                  step: 24,
                  onDrop: (_, {required below, required levels}) =>
                      drops.add((LineId(index), below)),
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

    final gesture = await drag(tester, 0, const Offset(0, 48 * 1.4));
    // The rows move up one row under the copy, e.g. by the mouse wheel.
    scroll.jumpTo(48);
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, [(const LineId(2), true)]);
  });

  testWidgets('a drop between spaced rows still drops', (tester) async {
    final drops = <Drop>[];
    await showRows(tester, onDrop: drops.add, spacing: 8);
    // The copy's middle ends in the space below the second row.
    final gesture = await drag(tester, 0, const Offset(0, 48 + 8 + 26));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, [(const LineId(0), const LineId(1), true, 0)]);
  });

  testWidgets('a row dropped on itself, shifted sideways, changes level', (
    tester,
  ) async {
    final drops = <Drop>[];
    await showRows(tester, onDrop: drops.add);
    final gesture = await drag(tester, 1, const Offset(50, 0), steps: 10);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, [(const LineId(1), const LineId(1), false, 2)]);
  });

  testWidgets('a row gone during a drag takes no drop', (tester) async {
    final drops = <Drop>[];
    final count = ValueNotifier(4);
    await showRows(tester, onDrop: drops.add, count: count);
    final gesture = await drag(tester, 0, const Offset(0, 48 * 2.6));
    // The last rows go, e.g. by a change from elsewhere.
    count.value = 2;
    await tester.pump();
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, [(const LineId(0), const LineId(1), true, 0)]);
  });

  testWidgets('a drag whose row is gone drops nothing', (tester) async {
    final drops = <Drop>[];
    final count = ValueNotifier(4);
    await showRows(tester, onDrop: drops.add, count: count);
    final gesture = await drag(tester, 3, const Offset(0, -48 * 2));
    count.value = 2;
    await tester.pump();
    await gesture.moveBy(const Offset(0, -1));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
