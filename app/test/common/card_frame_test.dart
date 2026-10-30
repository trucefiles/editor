import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/card_frame.dart';
import 'package:truce_editor/conflicts/ui/conflict_label.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';

void main() {
  testWidgets('the footer fits its tallest label at large app text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
          child: TextZoomScale(
            zoom: TextZoom.closestTo(150),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => SizedBox(
                    width: 240,
                    height: cardHeight(context),
                    child: CardFrame(
                      title: 'Title',
                      body: const CardLines('Some text'),
                      footer: const Row(children: [ConflictLabel()]),
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final footer = find
        .ancestor(of: find.byType(Row).first, matching: find.byType(SizedBox))
        .first;

    final label = tester.renderObject<RenderBox>(find.byType(ConflictLabel));

    expect(
      label.getMaxIntrinsicHeight(double.infinity),
      lessThanOrEqualTo(tester.getSize(footer).height),
    );
  });

  testWidgets('shows only whole lines of its body', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              height: 50,
              child: CardLines(List.filled(40, 'word').join(' ')),
            ),
          ),
        ),
      ),
    );
    final text = find.byType(Text);

    expect(tester.widget<Text>(text).maxLines, isPositive);
    expect(tester.getSize(text).height, lessThanOrEqualTo(50));
  });
}
