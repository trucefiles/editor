import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show NodeId;

/// Dragging an item over rows of different heights, down and back up, a
/// few pixels a frame, checking every frame: the gap opens and flips at
/// the middle line the dragged row shares with the row it passes, the
/// same line both ways; no row ever moves away from where it should end
/// (rows that should stay never move, moving rows go one way only).
void main() {
  final long = 'bbb ${List.filled(24, 'word').join(' ')}';
  final longer = 'ddd ${List.filled(90, 'word').join(' ')}';
  final texts = ['aaa', long, 'ccc', longer, 'eee'];
  final document = texts.map((text) => '- [ ] $text').join('\n');

  /// The rows' drop targets, top to bottom, as [texts] are.
  List<LineDropTarget> targets(WidgetTester tester) => [
    for (final text in texts)
      tester.widget<LineDropTarget>(
        find
            .ancestor(
              of: find.textContaining(text.substring(0, 3), findRichText: true),
              matching: find.byType(LineDropTarget),
            )
            .first,
      ),
  ];

  /// The dragged copy, while it shows.
  final copy = find.byWidgetPredicate(
    (widget) => widget is Material && widget.elevation == 4,
  );

  /// The top of each row's item row, top to bottom: where it shows now.
  List<double> tops(WidgetTester tester, List<LineDropTarget> rows) => [
    for (final row in rows) tester.getTopLeft(find.byKey(row.row)).dy,
  ];

  for (final (name, dragged, down) in [
    ('down to the end and back', 1, true),
    ('up to the top and back', 3, false),
  ]) {
    testWidgets('dragged $name: the gap flips at the middle lines, rows '
        'move one way only', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDocument(tester, TestDocument(document));
      final rows = targets(tester);
      final rest = [for (final row in rows) tester.getRect(find.byWidget(row))];
      expect(
        rest.map((rect) => rect.height).toSet(),
        hasLength(3),
        reason: 'rows of three heights',
      );
      final own = rest[dragged];
      final room = own.height;
      final zone = tester.state<LineDropZoneState>(find.byType(LineDropZone));
      final handle = find.descendant(
        of: find.byWidget(rows[dragged]),
        matching: find.byIcon(Icons.drag_indicator),
      );
      final inset =
          tester.getTopLeft(find.byKey(rows[dragged].row)).dy - own.top;
      final restTops = tops(tester, rows);
      // Past the last row's middle line and back, or the first row's.
      final travel = down
          ? rest.last.bottom - own.bottom + 6
          : -(own.top - rest.first.top + 6);

      /// The gap the middle-line rule asks for, the copy's top at [top]:
      /// moving down, the last row whose middle the copy's bottom passed;
      /// moving up, the first row whose middle its top passed.
      (NodeId, bool)? expectedGap(double top) {
        final place = top - inset;
        final below = rest.indexed
            .skip(dragged + 1)
            .lastWhereOrNull((row) => place + room > row.$2.center.dy);
        if (below != null) return (rows[below.$1].item, true);
        final above = rest.indexed
            .take(dragged)
            .firstWhereOrNull((row) => place < row.$2.center.dy);
        return above == null ? null : (rows[above.$1].item, false);
      }

      /// Where each row should end with [gap] open: past the gap, one
      /// dragged row lower.
      List<double> ends((NodeId, bool)? gap) {
        final at = switch (gap) {
          (final item, final below) =>
            rows.indexWhere((row) => row.item == item) + (below ? 1 : 0),
          null => rows.length,
        };
        return [
          for (final (index, top) in restTops.indexed)
            top + (index >= at ? room : 0),
        ];
      }

      final gesture = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      final flips = [<double>[], <double>[]];
      var last = restTops;
      (NodeId, bool)? lastGap;
      for (final (way, move) in [travel, -travel].indexed) {
        for (final _ in Iterable<int>.generate((move.abs() / 3).round())) {
          await gesture.moveBy(Offset(0, move.sign * 3));
          await tester.pump(const Duration(milliseconds: 16));
          final copyTop = tester.getTopLeft(copy).dy;
          final gap = switch (zone.drag.value.gap) {
            (:final item, :final below, height: _) => (item, below),
            null => null,
          };
          expect(gap, expectedGap(copyTop), reason: 'copy at $copyTop');
          if (gap != lastGap) flips[way].add(copyTop);
          lastGap = gap;
          final now = tops(tester, rows);
          final end = ends(gap);
          for (final (index, top) in now.indexed) {
            expect(
              (top - end[index]).abs(),
              lessThanOrEqualTo((last[index] - end[index]).abs() + 0.01),
              reason:
                  'row $index moved away from its end: '
                  '${last[index]} -> $top, end ${end[index]}',
            );
          }
          last = now;
        }
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Every row on the way passed and back, each flip at the same line
      // both ways, within a frame's step.
      final [there, back] = flips;
      expect(there, hasLength(down ? 3 : 3), reason: '$flips');
      expect(
        back.reversed,
        pairwiseCompare<double, double>(
          there,
          (a, b) => (a - b).abs() <= 3,
          'within 3 px of',
        ),
      );
    });
  }
}
