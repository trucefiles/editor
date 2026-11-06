import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart' show TextFile;
import 'package:truce_editor/files/ui/file_card.dart';
import 'package:truce_editor/files/ui/file_grid.dart';
import 'package:truce_editor/folders/ui/folder_badge.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/document_text_zoom.dart';
import 'package:truce_editor/text_zoom/ui/text_zoom_scale.dart';
import 'package:truce_editor/theme/app_theme.dart';
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
                    onActions: () {},
                    onActionsAt: (_) {},
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

  testWidgets('shows its type icon before the title, as large as its '
      'letters, growing with the document text zoom', (tester) async {
    Rect icon() => tester.getRect(
      find
          .descendant(of: find.byType(FileCard), matching: find.byType(Icon))
          .first,
    );

    await show(tester);
    final card = tester.getRect(find.byType(FileCard));
    final title = tester.getRect(find.text('Title'));
    final normal = icon();

    // At the card's left edge, inside its padding, beside the title.
    expect(normal.left - card.left, lessThan(20));
    expect(normal.right, lessThanOrEqualTo(title.left));
    expect(normal.center.dy, closeTo(title.center.dy, 1));

    await show(tester, zoom: TextZoom.closestTo(150));
    expect(icon().height, greaterThan(normal.height));
    expect(
      icon().center.dy,
      closeTo(tester.getCenter(find.text('Title')).dy, 1),
    );
  });

  group('footer', () {
    final deep = listedFile(
      folderAt(Directory.systemTemp).copyWith(name: 'Shared Notes'),
      name: 'projects/clients/work/plan.md',
      modified: DateTime(2026, 10, 14),
    );

    // The app's own font, so widths are as on a device.
    setUpAll(() async {
      final inter = FontLoader('Inter');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        inter.addFont(rootBundle.load('assets/fonts/inter/Inter-$weight.ttf'));
      }
      await inter.load();
    });

    /// Shows [deep]'s card [width] wide, pinned and with a conflict, at
    /// the text size [scale].
    Future<void> showDeep(
      WidgetTester tester, {
      required double width,
      double scale = 1,
    }) => tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: FileCard(
                    deep,
                    preview: read('# Plan'),
                    settings: FileSettings.defaults.withPinned(pinned: true),
                    hasConflict: true,
                    onTap: () {},
                    onActions: () {},
                    onActionsAt: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Finder footerIcon(IconData icon) => find.byIcon(icon);
    Text place(WidgetTester tester) =>
        tester.widget<Text>(find.textContaining('Shared'));

    // From a narrow phone's two columns to the widest a grid makes them,
    // and wider, as in a dialog.
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final width in [140.0, 160.0, 180.0, 200.0, 240.0, 320.0, 480.0]) {
        testWidgets('fits at $width px and text size $scale: the place '
            'giving way before the date', (tester) async {
          await showDeep(tester, width: width, scale: scale);

          expect(tester.takeException(), isNull);
          final card = tester.getRect(find.byType(FileCard));
          final date = find.textContaining('Oct 14');
          final dateText = tester.widget<Text>(date);
          final painter = TextPainter(
            text: TextSpan(text: dateText.data, style: dateText.style),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(scale),
            maxLines: 1,
          )..layout();
          final whole = tester.getSize(date).width >= painter.width - 0.01;
          painter.dispose();
          // The place gives way first: the date is cut only once it's gone.
          if (!whole) expect(find.byType(FolderDot), findsNothing);
          if (width >= 160 && scale == 1) expect(whole, isTrue);
          expect(tester.getRect(date).right, lessThanOrEqualTo(card.right));
          expect(footerIcon(Icons.push_pin), findsOne);
        });
      }
    }

    testWidgets('shortens the place in the middle, the folder name last', (
      tester,
    ) async {
      await showDeep(tester, width: 700);
      expect(place(tester).data, 'Shared Notes/projects/clients/work');

      await showDeep(tester, width: 320);
      expect(place(tester).data, 'Shared Notes/…/work');

      await showDeep(tester, width: 240);
      expect(place(tester).data, 'Shared Notes/…');
    });
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
              onActions: () {},
              onActionsAt: (_) {},
            ),
          ),
        ),
      ),
    );

    await show(hasConflict: false);
    expect(find.text('Conflict'), findsNothing);

    await show(hasConflict: true);
    expect(find.byTooltip('Sync conflict'), findsOne);
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
                    onActions: () {},
                    onActionsAt: (_) {},
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
            body: FileCard(
              file,
              preview: preview,
              onTap: () {},
              onActions: () {},
              onActionsAt: (_) {},
            ),
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
                      onActions: () {},
                      onActionsAt: (_) {},
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
