import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/visual/ui/line_drag.dart';
import 'package:truce_editor/editor/visual/ui/line_drop_zone.dart';
import 'package:truce_markdown/truce_markdown.dart' show NodeId;

/// A drop: the dropped item, the row it went next to, whether below it,
/// and by how many levels it was shifted.
typedef Drop = (NodeId item, NodeId target, bool below, int levels);

/// [child] in a drop zone a level 24 wide; drops go to [onDrop].
Widget _zone(Widget child, {void Function(Drop drop)? onDrop}) => LineDropZone(
  step: 24,
  onLift: (_) {},
  onDrop: (drag, {required target, required below, required levels}) =>
      onDrop?.call((drag.item, target, below, levels)),
  onSettled: () {},
  child: child,
);

/// The handle of item [index], whose row is [row]; its copy shows [copy].
Widget _handle(int index, GlobalKey row, {String? copy}) => SizedBox(
  width: 48,
  height: 48,
  child: LineDragHandle(
    LineDrag(
      NodeId(index),
      leaf: NodeId(100 + index),
      row: row,
      look: Text(copy ?? 'copy $index'),
    ),
    icon: const Icon(Icons.drag_indicator),
  ),
);

void main() {
  testWidgets('the dragged copy shows its text as the row does', (
    tester,
  ) async {
    final row = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => _zone(child!),
        home: Scaffold(
          body: MediaQuery(
            // Zoomed, like note text inside the app.
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Row(
              key: row,
              children: [
                _handle(1, row, copy: 'copy'),
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
        builder: (_, child) => _zone(child!),
        home: Scaffold(
          backgroundColor: Colors.orange,
          body: Row(
            key: row,
            children: [_handle(1, row, copy: 'copy')],
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
        home: Scaffold(
          // Inside the app's overlay, as in the editor, so a dropped
          // copy glides there.
          body: _zone(
            onDrop: onDrop,
            ValueListenableBuilder(
              valueListenable: count ?? ValueNotifier(rows.length),
              builder: (context, count, _) => Column(
                children: [
                  for (final (index, row) in rows.take(count).indexed)
                    Padding(
                      padding: EdgeInsets.only(bottom: spacing),
                      child: LineDropTarget(
                        item: NodeId(index),
                        child: Row(
                          key: row,
                          children: [_handle(index, row), Text('item $index')],
                        ),
                      ),
                    ),
                ],
              ),
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

    expect(drops, [(const NodeId(0), const NodeId(1), true, 0)]);
  });

  testWidgets('a dropped copy glides into the gap before the drop lands', (
    tester,
  ) async {
    final drops = <Drop>[];
    await showRows(tester, onDrop: drops.add);
    final gesture = await drag(tester, 0, const Offset(0, 48 * 1.4));
    await gesture.up();
    await tester.pump();

    expect(find.text('copy 0'), findsOne, reason: 'gliding');
    expect(drops, isEmpty);

    await tester.pumpAndSettle();
    expect(find.text('copy 0'), findsNothing);
    expect(drops, hasLength(1));
  });

  testWidgets('a copy dropped right where it was lifted settles at once', (
    tester,
  ) async {
    final drops = <Drop>[];
    await showRows(tester, onDrop: drops.add);
    final gesture = await drag(tester, 1, const Offset(0, 20), steps: 4);
    await gesture.moveBy(const Offset(0, -20));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('copy 1'), findsNothing);
    expect(drops, [(const NodeId(1), const NodeId(1), false, 0)]);
  });

  testWidgets('scrolling during a drag keeps the drop places', (tester) async {
    final drops = <(NodeId, bool)>[];
    final scroll = ScrollController();
    final rows = [for (final _ in Iterable<int>.generate(20)) GlobalKey()];
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            _zone(child!, onDrop: (drop) => drops.add((drop.$2, drop.$3))),
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              for (final (index, row) in rows.indexed)
                LineDropTarget(
                  item: NodeId(index),
                  child: Row(
                    key: row,
                    children: [_handle(index, row), Text('item $index')],
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

    expect(drops, [(const NodeId(2), true)]);
  });

  testWidgets('a drop between spaced rows still drops', (tester) async {
    final drops = <Drop>[];
    await showRows(tester, onDrop: drops.add, spacing: 8);
    // The copy's middle ends in the space below the second row.
    final gesture = await drag(tester, 0, const Offset(0, 48 + 8 + 26));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, [(const NodeId(0), const NodeId(1), true, 0)]);
  });

  testWidgets('a row dropped on itself, shifted sideways, changes level', (
    tester,
  ) async {
    final drops = <Drop>[];
    await showRows(tester, onDrop: drops.add);
    final gesture = await drag(tester, 1, const Offset(50, 0), steps: 10);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drops, [(const NodeId(1), const NodeId(1), false, 2)]);
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

    expect(drops, [(const NodeId(0), const NodeId(1), true, 0)]);
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
