import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart' show TextFile;
import 'package:truce_editor/files/ui/file_card.dart';
import 'package:truce_editor/files/ui/file_grid.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/document_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';
import 'package:truce_files/truce_files.dart';

import '../../support.dart';

void main() {
  final file = listedFile(
    folderAt(Directory.systemTemp),
    name: 'document.md',
    version: 1,
    modified: DateTime(2026, 10, 14),
  );

  /// [text] as the card's preview, read.
  CardPreview read(String text) => Previewed(
    appFileTypes()
        .ofFile(file.type)
        .cardSummary(FileText(file, const TextFile.empty().withText(text))),
  );

  /// Shows the card of a file with [title] and [lines] lines, as wide
  /// as in a grid, at [zoom].
  Future<void> show(
    WidgetTester tester, {
    String title = 'Title',
    int lines = 20,
    TextZoom zoom = TextZoom.normal,
  }) async {
    final text = ['# $title', for (var i = 1; i <= lines; i++) 'line $i'];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DocumentTextZoomScope(
            zoom: zoom,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 240,
                  child: FileCard(
                    file,
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

  testWidgets('is as tall as its text, up to the lines a preview has', (
    tester,
  ) async {
    double height() => tester.getSize(find.byType(FileCard)).height;

    await show(tester, lines: 2);
    final short = height();
    await show(tester);

    expect(height(), greaterThan(short));
    expect(previewLines(tester), FileCardSummary.previewLines);
  });

  testWidgets('grows with the document text zoom, keeping its lines', (
    tester,
  ) async {
    await show(tester);
    final normal = tester.getSize(find.byType(FileCard)).height;

    await show(tester, zoom: TextZoom.closestTo(150));

    expect(tester.getSize(find.byType(FileCard)).height, greaterThan(normal));
    expect(previewLines(tester), FileCardSummary.previewLines);
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
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FileCard(
              file,
              preview: read('# Title'),
              hasConflict: hasConflict,
              onTap: () {},
              onMark: () {},
            ),
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
        ProviderScope(
          child: MaterialApp(
            home: DocumentTextZoomScope(
              zoom: TextZoom.closestTo(150),
              child: TextZoomScale(
                zoom: TextZoom.closestTo(120),
                child: Scaffold(
                  body: FileCard(
                    file,
                    preview: read('# Title\nline'),
                    onTap: () {},
                    onMark: () {},
                  ),
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
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: FileCard(file, preview: preview, onTap: () {}, onMark: () {}),
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
      ProviderScope(
        child: MaterialApp(
          home: DocumentTextZoomScope(
            zoom: zoom,
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  fileGrid(
                    1,
                    (_) => FileCard(
                      file,
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
      ),
    );
    double height() => tester.getSize(find.byType(FileCard)).height;

    await show(TextZoom.normal);
    final normal = height();
    expect(previewLines(tester), FileCardSummary.previewLines);

    await show(TextZoom.closestTo(150));
    expect(height(), greaterThan(normal));
    expect(previewLines(tester), FileCardSummary.previewLines);
  });
}
