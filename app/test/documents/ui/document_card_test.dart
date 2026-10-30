import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_editor/common/card_frame.dart';
import 'package:truce_editor/documents/ui/document_card.dart';
import 'package:truce_editor/documents/ui/document_grid.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/document_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';

import '../../support.dart';

void main() {
  final document = listedDocument(
    folderAt(Directory.systemTemp),
    name: 'document.md',
    version: 1,
    modified: DateTime(2026, 10, 14),
  );

  /// [text] as the card's preview, read.
  CardPreview read(String text) => Previewed(
    appDocumentTypes().ofFile(document.type).cardSummary(text, document.path),
  );

  /// Shows the card of a document with [title] and [lines] lines, as tall
  /// as in a grid at [zoom].
  Future<void> show(
    WidgetTester tester, {
    String title = 'Title',
    int lines = 20,
    TextZoom zoom = TextZoom.normal,
  }) async {
    final text = ['# $title', for (var i = 1; i <= lines; i++) 'line $i'];
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentTextZoomScope(
          zoom: zoom,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: Builder(
                builder: (context) => SizedBox(
                  width: 240,
                  height: cardHeight(context),
                  child: DocumentCard(
                    document,
                    preview: read(text.join('\n')),
                    onTap: () {},
                    onMark: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Lines the preview shows at most.
  int previewLines(WidgetTester tester) =>
      tester.widget<Text>(find.textContaining('line 1')).maxLines!;

  testWidgets('shows as many whole preview lines as fit under the title', (
    tester,
  ) async {
    await show(tester);
    expect(previewLines(tester), cardBodyLines);

    await show(tester, title: 'A title long enough for two lines');
    expect(previewLines(tester), lessThan(cardBodyLines));
  });

  testWidgets('grows with the document text zoom, keeping its lines', (
    tester,
  ) async {
    await show(tester);
    final normal = tester.getSize(find.byType(DocumentCard)).height;

    await show(tester, zoom: TextZoom.closestTo(150));

    expect(
      tester.getSize(find.byType(DocumentCard)).height,
      greaterThan(normal),
    );
    expect(previewLines(tester), cardBodyLines);
  });

  testWidgets('shows only the title for a document without text', (
    tester,
  ) async {
    await show(tester, lines: 0);

    expect(find.text('Title'), findsOne);
    expect(find.textContaining('line'), findsNothing);
  });

  testWidgets('labels a document with a sync conflict', (tester) async {
    Future<void> show({required bool hasConflict}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentCard(
            document,
            preview: read('# Title'),
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
                  document,
                  preview: read('# Title\nline'),
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

  testWidgets('shows the file name while the text is read, and says when it '
      "can't be shown", (tester) async {
    Future<void> show(CardPreview preview) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentCard(
            document,
            preview: preview,
            onTap: () {},
            onMark: () {},
          ),
        ),
      ),
    );

    await show(const PreviewReading());
    expect(find.text('document'), findsOne);
    expect(find.text("Can't be shown as text."), findsNothing);

    await show(const PreviewNotText());
    expect(find.text('document'), findsOne);
    expect(find.text("Can't be shown as text."), findsOne);

    await show(const PreviewUnreadable());
    expect(find.text('document'), findsOne);
    expect(find.text("Can't be shown as text."), findsNothing);
  });

  testWidgets('in a grid, shows its lines and follows a zoom change', (
    tester,
  ) async {
    Future<void> show(TextZoom zoom) => tester.pumpWidget(
      MaterialApp(
        home: DocumentTextZoomScope(
          zoom: zoom,
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                documentGrid(
                  1,
                  (_) => DocumentCard(
                    document,
                    preview: read(
                      [
                        '# Title',
                        for (var i = 1; i <= 20; i++) 'line $i',
                      ].join('\n'),
                    ),
                    onTap: () {},
                    onMark: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    double height() => tester.getSize(find.byType(DocumentCard)).height;

    await show(TextZoom.normal);
    final normal = height();
    expect(previewLines(tester), cardBodyLines);

    await show(TextZoom.closestTo(150));
    expect(height(), greaterThan(normal));
    expect(previewLines(tester), cardBodyLines);
  });
}
