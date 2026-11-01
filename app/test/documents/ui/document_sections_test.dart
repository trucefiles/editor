import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/ui/document_sections.dart';

void main() {
  Future<void> show(
    WidgetTester tester, {
    List<String> pinned = const [],
    List<String> others = const [],
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DocumentSections(
          leading: const [Text('orphan')],
          pinned: [for (final name in pinned) Text(name)],
          others: [for (final name in others) Text(name)],
          footer: const Text('footer'),
        ),
      ),
    ),
  );

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text, skipOffstage: false)).dy;

  testWidgets('shows pinned cards under their own heading first', (
    tester,
  ) async {
    await show(tester, pinned: ['a'], others: ['b']);

    expect(top(tester, 'orphan'), lessThan(top(tester, 'Pinned')));
    expect(top(tester, 'Pinned'), lessThan(top(tester, 'a')));
    expect(top(tester, 'a'), lessThan(top(tester, 'Recent')));
    expect(top(tester, 'Recent'), lessThan(top(tester, 'b')));
    expect(top(tester, 'b'), lessThan(top(tester, 'footer')));
  });

  testWidgets('shows no headings if nothing is pinned', (tester) async {
    await show(tester, others: ['b']);

    expect(find.text('b'), findsOne);
    expect(find.text('Pinned'), findsNothing);
    expect(find.text('Recent'), findsNothing);
  });

  testWidgets('shows no "Recent" heading if all are pinned', (tester) async {
    await show(tester, pinned: ['a']);

    expect(find.text('Pinned'), findsOne);
    expect(find.text('Recent'), findsNothing);
  });

  testWidgets('cards are as tall as their content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DocumentSections(
            pinned: [],
            others: [
              SizedBox(height: 50, child: Text('short')),
              SizedBox(height: 300, child: Text('tall')),
            ],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.text('short')).height, 50);
    expect(tester.getSize(find.text('tall')).height, 300);
  });

  testWidgets('scrolls past the pinned cards to the end', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget card(String name, double height) =>
        SizedBox(height: height, child: Text(name));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentSections(
            pinned: [
              for (var i = 0; i < 8; i++) card('pinned $i', 150.0 + i % 3 * 40),
            ],
            others: [
              for (var i = 0; i < 60; i++) card('other $i', 120.0 + i % 4 * 30),
            ],
          ),
        ),
      ),
    );

    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();
    }

    expect(find.text('other 59'), findsOne);
  });

  testWidgets('builds only the cards near the screen', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget card(String name) => SizedBox(height: 150, child: Text(name));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentSections(
            pinned: [for (var i = 0; i < 40; i++) card('pinned $i')],
            others: [for (var i = 0; i < 200; i++) card('other $i')],
          ),
        ),
      ),
    );

    expect(find.text('pinned 0'), findsOne);
    expect(find.text('pinned 39', skipOffstage: false), findsNothing);
    expect(find.text('other 199', skipOffstage: false), findsNothing);
  });

  testWidgets('a jump past the pinned cards keeps every section in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(520, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentSections(
            pinned: [for (var i = 0; i < 10; i++) Text('pinned $i')],
            others: [for (var i = 0; i < 80; i++) Text('other $i')],
          ),
        ),
      ),
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    final recent = top(tester, 'Recent');

    position.jumpTo(3000);
    await tester.pump();
    position.jumpTo(0);
    await tester.pump();

    expect(top(tester, 'Recent'), recent);
    expect(find.text('pinned 0'), findsOne);
  });
}
