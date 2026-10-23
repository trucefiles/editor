import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/note_metrics.dart';

void main() {
  Future<NoteMetrics> metricsIn(
    WidgetTester tester, {
    double textScale = 1,
    MaterialTapTargetSize tapTargets = MaterialTapTargetSize.shrinkWrap,
  }) async {
    late NoteMetrics metrics;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(materialTapTargetSize: tapTargets),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Builder(
            builder: (context) {
              metrics = NoteMetrics.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    // The theme changes by an animation.
    await tester.pumpAndSettle();
    return metrics;
  }

  testWidgets('grow with the text', (tester) async {
    final base = await metricsIn(tester);
    final double = await metricsIn(tester, textScale: 2);

    expect(double.scale, 2);
    expect(double.levelIndent, base.levelIndent * 2);
    expect(double.markerWidth, base.markerWidth * 2);
    expect(double.lineGap, base.lineGap * 2);
    expect(double.itemGap, base.itemGap * 2);
    expect(double.lineHeight, closeTo(base.lineHeight * 2, 1));
  });

  testWidgets('on touch, handles are a touch target wide and items apart', (
    tester,
  ) async {
    final mouse = await metricsIn(tester);
    final touch = await metricsIn(
      tester,
      tapTargets: MaterialTapTargetSize.padded,
    );

    expect(touch.touch, isTrue);
    expect(touch.handleWidth, kMinInteractiveDimension);
    expect(touch.handleIconSize, mouse.handleIconSize);
    expect(touch.itemRowInset, greaterThan(mouse.itemRowInset));
    expect(touch.lineHeight + touch.itemGap, kMinInteractiveDimension);
    expect(touch.lineGap, mouse.lineGap);
  });

  testWidgets('on touch, large text spaces items as with a mouse', (
    tester,
  ) async {
    final mouse = await metricsIn(tester, textScale: 3);
    final touch = await metricsIn(
      tester,
      textScale: 3,
      tapTargets: MaterialTapTargetSize.padded,
    );

    expect(touch.itemGap, mouse.itemGap);
  });
}
