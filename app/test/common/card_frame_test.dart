import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_documents/truce_documents.dart' show DocumentCardSummary;
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
                child: SizedBox(
                  width: 240,
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

  testWidgets('is as tall as its text, up to the lines a preview has', (
    tester,
  ) async {
    Future<double> height(int lines) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: CardFrame(
                title: 'Title',
                body: CardLines(List.filled(lines, 'line').join('\n')),
                footer: const SizedBox(),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(CardFrame)).height;
    }

    final short = await height(2);
    final long = await height(DocumentCardSummary.previewLines);

    expect(long, greaterThan(short));
    expect(await height(DocumentCardSummary.previewLines + 5), long);
  });
}
