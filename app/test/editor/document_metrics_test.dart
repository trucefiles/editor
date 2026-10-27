import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/document_metrics.dart';

void main() {
  Future<DocumentMetrics> metricsIn(
    WidgetTester tester, {
    double textScale = 1,
    MaterialTapTargetSize tapTargets = MaterialTapTargetSize.shrinkWrap,
  }) async {
    late DocumentMetrics metrics;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(materialTapTargetSize: tapTargets),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Builder(
            builder: (context) {
              metrics = DocumentMetrics.of(context);
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
    expect(touch.lineGap, mouse.lineGap);
  });

  testWidgets('on touch, items never stand closer as the text grows', (
    tester,
  ) async {
    Future<double> gapAt(double textScale) async => (await metricsIn(
      tester,
      textScale: textScale,
      tapTargets: MaterialTapTargetSize.padded,
    )).itemGap;

    expect(await gapAt(1.5), greaterThan(await gapAt(1)));
  });

  testWidgets('paragraphs never take back space, even when small', (
    tester,
  ) async {
    final touch = await metricsIn(
      tester,
      textScale: 0.8,
      tapTargets: MaterialTapTargetSize.padded,
    );

    expect(touch.paragraphGap, greaterThanOrEqualTo(0));
  });
}
