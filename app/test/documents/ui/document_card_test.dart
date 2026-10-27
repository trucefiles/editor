import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_card_summary.dart';
import 'package:truce_editor/documents/ui/document_card.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/document_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';

import '../../support.dart';

void main() {
  Document document(String text) => documentOf(
    folderAt(Directory.systemTemp),
    text,
    name: 'document.md',
    version: 1,
    modified: DateTime(2026, 10, 14),
  );

  Future<double> heightWith(WidgetTester tester, int lines) async {
    final text = ['# Title', for (var i = 1; i <= lines; i++) 'line $i'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 240,
              child: DocumentCard(
                document(text.join('\n')),
                onTap: () {},
                onMark: () {},
              ),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(DocumentCard)).height;
  }

  testWidgets('grows with the document up to the preview limit', (
    tester,
  ) async {
    final short = await heightWith(tester, 1);
    final full = await heightWith(tester, DocumentCardSummary.previewLines);
    final long = await heightWith(tester, DocumentCardSummary.previewLines * 4);

    expect(short, lessThan(full));
    expect(long, full);
  });

  testWidgets('shows only the title for a document without text', (
    tester,
  ) async {
    expect(await heightWith(tester, 0), lessThan(await heightWith(tester, 1)));
  });

  testWidgets('labels a document with a sync conflict', (tester) async {
    Future<void> show({required bool hasConflict}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentCard(
            document('# Title'),
            hasConflict: hasConflict,
            onTap: () {},
            onMark: () {},
          ),
        ),
      ),
    );

    await show(hasConflict: false);
    expect(find.text('Conflict'), findsNothing);

    await show(hasConflict: true);
    expect(find.text('Conflict'), findsOne);
  });

  testWidgets(
    "shows the document at the document text zoom, the rest at the app's",
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentTextZoomScope(
            zoom: TextZoom.closestTo(150),
            child: TextZoomScale(
              zoom: TextZoom.closestTo(120),
              child: Scaffold(
                body: DocumentCard(
                  document('# Title\nline'),
                  onTap: () {},
                  onMark: () {},
                ),
              ),
            ),
          ),
        ),
      );
      double scaled(Finder text) =>
          MediaQuery.textScalerOf(tester.element(text)).scale(10);

      expect(scaled(find.text('Title')), 15);
      expect(scaled(find.text('line')), 15);
      expect(scaled(find.textContaining('Oct 14')), 12);
    },
  );
}
