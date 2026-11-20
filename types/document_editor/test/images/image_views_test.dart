import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:truce_common_ui/truce_common_ui.dart' show ImageViewer;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

import 'image_fakes.dart';

/// Adding, showing and pasting images in the document views.
void main() {
  testWidgets('Image in Visual edit keeps the picture and puts it on a line '
      'after the caret', (tester) async {
    final document = TestDocument('milk\n\neggs');
    final kept = FakeImageKeeping();
    await pumpDocument(
      tester,
      document,
      imageAdding: (
        picking: FakePicking(onePixelPng),
        kept: kept,
        hint: (_) {},
      ),
    );

    await tester.caretIn(paragraphNodeOf(), 2);
    await tester.tap(find.byTooltip('Image'));
    // Made ready on another thread.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    expect(kept.kept.keys, ['kept/1.png']);
    expect(document.text, 'milk\n\n![](kept/1.png)\n\neggs');
  });

  testWidgets('with camera and photos, Image asks which first', (tester) async {
    final document = TestDocument('milk');
    final picking = FakePicking(
      null,
      sources: const [ImageSource.gallery, ImageSource.camera],
    );
    await pumpDocument(
      tester,
      document,
      imageAdding: (picking: picking, kept: FakeImageKeeping(), hint: (_) {}),
    );

    await tester.caretIn(paragraphNodeOf(), 2);
    await tester.tap(find.byTooltip('Image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();

    expect(picking.asked, [ImageSource.camera]);
    expect(document.text, 'milk');
  });

  testWidgets('no Image button where images can not be added', (tester) async {
    await pumpDocument(tester, TestDocument('milk'));
    await tester.caretIn(paragraphNodeOf(), 2);

    expect(find.byTooltip('Image'), findsNothing);
  });

  testWidgets('Markdown edit pastes image links as they are', (tester) async {
    const link = '![](document-images/img-0123456789abcdef.png)';
    final document = TestDocument('', mode: EditMode.markdown);
    await pumpDocument(tester, document);
    tester.clipboardHolds(link);

    await tester.caretIn(lineNodeOf(0), 0);
    await tester.pressCtlV();
    await tester.pumpAndSettle();

    expect(document.text, link);
  });

  testWidgets('a tap on an image in Visual edit shows it full screen', (
    tester,
  ) async {
    final document = TestDocument('# Doc\n\n![p](p.png)\n\nend');
    await pumpDocument(tester, document, images: const _OneImage());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    // The editor's own gestures above it take the tap.
    await tester.tap(find.byType(Image), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(ImageViewer), findsOne);
    expect(document.edits, isEmpty);
  });

  testWidgets('a tap on an image that opens shows it full screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentImage(
            'p.png',
            alt: 'pic',
            images: const _OneImage(),
            opens: true,
          ),
        ),
      ),
    );

    // Decoded off the test's clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewer), findsOne);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(ImageViewer), findsNothing);
  });
}

final class _OneImage implements DocumentImageLookup {
  const _OneImage();

  @override
  ImageProvider? of(String url) => MemoryImage(onePixelPng);
}
