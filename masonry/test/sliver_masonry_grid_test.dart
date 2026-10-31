import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_masonry/truce_masonry.dart';

/// Two columns 100 wide, 10 apart, in a view 600 high.
const _width = 210.0;
const _height = 600.0;

void main() {
  /// Item heights and the items not ready; a change rebuilds only the
  /// items, as a card that finishes reading does.
  late ValueNotifier<List<double>> heights;
  late ValueNotifier<Set<int>> waiting;

  /// Shows a grid of items as tall as [initial] says, each ready unless in
  /// [notReady], with [after] below it.
  Future<void> show(
    WidgetTester tester,
    List<double> initial, {
    Set<int> notReady = const {},
    ScrollController? controller,
    Widget? after,
  }) {
    heights = ValueNotifier(initial);
    waiting = ValueNotifier(notReady);
    addTearDown(heights.dispose);
    addTearDown(waiting.dispose);
    return tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _width,
            height: _height,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                SliverMasonryGrid(
                  itemCount: initial.length,
                  itemBuilder: (_, index) => _Item(index, heights, waiting),
                  maxColumnWidth: 100,
                  spacing: 10,
                ),
                if (after != null) SliverToBoxAdapter(child: after),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Offset at(WidgetTester tester, int index) =>
      tester.getTopLeft(find.text('item $index'));

  Iterable<int> built(WidgetTester tester) => tester
      .widgetList<Text>(find.textContaining('item ', skipOffstage: false))
      .map((text) => int.parse(text.data!.substring(5)));

  /// The built items, as rectangles on screen.
  List<Rect> rects(WidgetTester tester) => [
    for (final index in built(tester))
      tester.getRect(find.text('item $index', skipOffstage: false)),
  ];

  /// No two built items cover each other.
  void expectNoOverlap(WidgetTester tester) {
    final all = rects(tester);
    for (final (index, rect) in all.indexed) {
      for (final other in all.skip(index + 1)) {
        expect(rect.overlaps(other), isFalse, reason: '$rect, $other');
      }
    }
  }

  testWidgets('puts each item in the shortest column', (tester) async {
    await show(tester, [100, 50, 30, 40]);

    expect(at(tester, 0), Offset.zero);
    expect(at(tester, 1), const Offset(110, 0));
    expect(at(tester, 2), const Offset(110, 60));
    expect(at(tester, 3), const Offset(110, 100));
  });

  testWidgets('builds only the items near the screen', (tester) async {
    await show(tester, List.filled(1000, 100));

    expect(built(tester).length, lessThan(30));
  });

  testWidgets('a jump far down and back keeps every item and what follows '
      'in place', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await show(
      tester,
      [for (var i = 0; i < 500; i++) 40.0 + (i * 37) % 150],
      controller: controller,
      after: const SizedBox(height: 50, child: Text('after')),
    );

    controller.jumpTo(20000);
    await tester.pump();
    expectNoOverlap(tester);
    expect(built(tester).length, lessThan(40));

    // The end moves as the items there are measured; the view follows it.
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expectNoOverlap(tester);
    final bottom = rects(tester)
        .map((rect) => rect.bottom)
        .reduce((a, b) => a > b ? a : b);
    expect(
      tester.getTopLeft(find.text('after')).dy,
      greaterThanOrEqualTo(bottom),
    );
    expect(tester.getBottomLeft(find.text('after')).dy, _height);

    controller.jumpTo(0);
    await tester.pump();
    expectNoOverlap(tester);
    expect(at(tester, 0), Offset.zero);
    expect(at(tester, 1), const Offset(110, 0));
  });

  testWidgets('an item that grows moves only the items below it in its '
      'column', (tester) async {
    await show(tester, [100, 50, 30, 40]);

    heights.value = [100, 200, 30, 40];
    await tester.pump();

    expect(at(tester, 0), Offset.zero);
    expect(at(tester, 2), const Offset(110, 210));
    expect(at(tester, 3), const Offset(110, 250));
  });

  testWidgets('holds back an item that is not ready, and the items after '
      'it', (tester) async {
    await show(tester, [100, 50, 30], notReady: {1});

    expect(find.text('item 0').hitTestable(), findsOne);
    expect(find.text('item 1').hitTestable(), findsNothing);
    expect(find.text('item 2').hitTestable(), findsNothing);

    waiting.value = {};
    await tester.pump();

    expect(find.text('item 1').hitTestable(), findsOne);
    expect(find.text('item 2').hitTestable(), findsOne);
  });

  testWidgets('an item shown stays shown when it waits again', (tester) async {
    await show(tester, [100, 50, 30]);

    waiting.value = {0};
    await tester.pump();

    expect(find.text('item 0').hitTestable(), findsOne);
    expect(find.text('item 2').hitTestable(), findsOne);
  });

  testWidgets('keeps what is on screen in place when an item above it '
      'grows', (tester) async {
    final controller = ScrollController(initialScrollOffset: 500);
    addTearDown(controller.dispose);
    await show(tester, List.filled(100, 100), controller: controller);
    final before = at(tester, 8);

    heights.value = [...heights.value]..[6] = 200;
    await tester.pump();

    expect(at(tester, 8), before);
  });
}

/// Item [index], as tall as [heights] says, ready unless in [waiting].
class _Item extends StatelessWidget {
  const _Item(this.index, this.heights, this.waiting);

  final int index;
  final ValueNotifier<List<double>> heights;
  final ValueNotifier<Set<int>> waiting;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([heights, waiting]),
    builder: (_, _) => MasonryItem(
      ready: !waiting.value.contains(index),
      child: SizedBox(height: heights.value[index], child: Text('item $index')),
    ),
  );
}
