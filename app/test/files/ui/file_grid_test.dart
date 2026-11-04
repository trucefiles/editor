import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/files/ui/file_grid.dart';

void main() {
  /// The left edges of four cards in a grid 320 wide at [textScale].
  Future<Set<double>> columns(WidgetTester tester, double textScale) async {
    tester.view
      ..physicalSize = const Size(320, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: CustomScrollView(
            slivers: [
              fileGrid(
                4,
                (index) => gridCard(
                  SizedBox(height: 40, child: Text('$index')),
                  ready: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return {
      for (final index in [0, 1, 2, 3])
        tester.getTopLeft(find.text('$index')).dx,
    };
  }

  testWidgets('columns widen with the text size', (tester) async {
    expect(await columns(tester, 1), hasLength(2));
    expect(await columns(tester, 2), hasLength(1));
  });
}
