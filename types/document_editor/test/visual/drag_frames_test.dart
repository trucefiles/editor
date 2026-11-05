import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show NodeId;

/// Dragging an item over rows of different heights, down to the end and
/// back, up to the top and back, a few pixels a frame, checking every
/// frame against what shows: the gap opens and flips once the middle of
/// the copy, as drawn, crosses the middle of the room the pair it swaps
/// takes (the copy's row and the row it passes, the open gap counted
/// where it shows), the same line both ways; no row ever moves away from
/// where it should end (rows that should stay never move, moving rows go
/// one way only). In the touch and the desktop look, and at a larger
/// text size.
void main() {
  final long = 'bbb ${List.filled(24, 'word').join(' ')}';
  final longer = 'ddd ${List.filled(90, 'word').join(' ')}';
  final texts = ['aaa', long, 'ccc', longer, 'eee', 'fff'];
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

  for (final (look, platform, textScale) in [
    ('touch', TargetPlatform.android, 1.0),
    ('desktop', TargetPlatform.linux, 1.0),
    ('desktop at 1.5x text', TargetPlatform.linux, 1.5),
  ]) {
    for (final (name, dragged, down) in [
      ('the first row down to the end and back', 0, true),
      ('a middle row down to the end and back', 2, true),
      ('the last row up to the top and back', 5, false),
      ('a middle row up to the top and back', 3, false),
    ]) {
      testWidgets('$look: $name, the gap flips where the copy\'s middle '
          'crosses the middle of the pair\'s room, rows move one way only', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpDocument(
          tester,
          TestDocument(document),
          around: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        );
        final rows = targets(tester);
        final rest = [
          for (final row in rows) tester.getRect(find.byWidget(row)),
        ];
        expect(
          rest.map((rect) => rect.height).toSet(),
          hasLength(3),
          reason: 'rows of three heights',
        );
        final own = rest[dragged];
        // The room the dragged row takes, and so the gap it opens.
        final room = own.height;
        final zone = tester.state<LineDropZoneState>(find.byType(LineDropZone));
        final handle = find.descendant(
          of: find.byWidget(rows[dragged]),
          matching: find.byIcon(Icons.drag_indicator),
        );
        final restTops = tops(tester, rows);
        // Past the last row's line and back, or the first row's; the
        // pointer stays over the document.
        final travel = down
            ? rest.last.bottom - own.top + 6
            : -(own.top - rest.first.top + 6);

        /// Where the copy's middle flips past each row, as the pair it
        /// swaps shows: the row next to the old place with it; a row
        /// farther on with the gap, a dragged row high, open before it.
        final lines = <int, double>{
          for (final index in Iterable<int>.generate(rows.length))
            if (index == dragged + 1)
              index: (own.top + rest[index].bottom) / 2
            else if (index > dragged + 1)
              index: (rest[index - 1].bottom + rest[index].bottom + room) / 2
            else if (index == dragged - 1)
              index: (rest[index].top + own.bottom) / 2
            else if (index < dragged - 1)
              index: (rest[index].top + rest[index + 1].top + room) / 2,
        };

        /// The gap the rule asks for with the copy's middle at [middle]:
        /// moving down, below the last row whose line it passed; moving
        /// up, above the first one. `null` within half a pixel of a
        /// line, where a frame's rounding decides.
        (NodeId, bool)? expectedGap(double middle) {
          final below = lines.entries
              .where((line) => line.key > dragged && middle > line.value)
              .map((line) => line.key)
              .maxOrNull;
          if (below != null) return (rows[below].item, true);
          final above = lines.entries
              .where((line) => line.key < dragged && middle < line.value)
              .map((line) => line.key)
              .minOrNull;
          return above == null ? null : (rows[above].item, false);
        }

        bool nearLine(double middle) =>
            lines.values.any((line) => (line - middle).abs() < 0.5);

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
            final middle = tester.getRect(copy).center.dy;
            final gap = switch (zone.drag.value.gap) {
              (:final item, :final below, height: _) => (item, below),
              null => null,
            };
            if (!nearLine(middle)) {
              expect(gap, expectedGap(middle), reason: 'copy middle $middle');
            }
            if (gap != lastGap) flips[way].add(middle);
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
        debugDefaultTargetPlatformOverride = null;

        // Every row on the way passed and back, each flip at the same line
        // both ways, within a frame's step.
        final [there, back] = flips;
        expect(
          there,
          hasLength(down ? rows.length - 1 - dragged : dragged),
          reason: '$flips',
        );
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
}
