import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart' show SizedImage;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';

/// Where Visual edit draws the caret beside a picture in the text.
void main() {
  /// Shows "a ![p](p.png) b" with a picture 100 high in a line of text,
  /// once the picture is drawn; gives the picture's box.
  Future<Rect> pumpPicture(WidgetTester tester) async {
    final picture = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 40, 100),
        Paint()..color = Colors.teal,
      );
      final image = await recorder.endRecording().toImage(40, 100);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return MemoryImage(png!.buffer.asUint8List());
    });
    await pumpDocument(
      tester,
      TestDocument('a ![p](p.png) b'),
      images: _OneImage(picture!),
    );
    await tester.runAsync(
      () => precacheImage(picture, tester.element(find.byType(Image))),
    );
    await tester.pumpAndSettle();
    return tester.getRect(find.byType(Image));
  }

  /// The caret's box at [offset] of the paragraph, [affinity] given.
  Rect caretAt(int offset, TextAffinity affinity) =>
      SuperEditorInspector.findDocumentLayout().getRectForPosition(
        DocumentPosition(
          nodeId: paragraphNodeOf(),
          nodePosition: TextNodePosition(offset: offset, affinity: affinity),
        ),
      )!;

  testWidgets('the caret right after a picture stands as high as the line, '
      'as it does before it', (tester) async {
    final picture = await pumpPicture(tester);
    final layout = SuperEditorInspector.findDocumentLayout()
        .getGlobalOffsetFromDocumentOffset(Offset.zero);
    final before = caretAt(2, TextAffinity.downstream).shift(layout);
    final after = caretAt(3, TextAffinity.downstream).shift(layout);

    expect(picture.height, 100);
    expect(after.top, moreOrLessEquals(before.top));
    expect(after.bottom, moreOrLessEquals(before.bottom));
    expect(after.left, moreOrLessEquals(picture.right, epsilon: 1));
    expect(after.top, lessThanOrEqualTo(picture.top + 0.5));
    // The desktop caret is drawn on the edge.
    final edge = SuperEditorInspector.findDocumentLayout().getEdgeForPosition(
      DocumentPosition(
        nodeId: paragraphNodeOf(),
        nodePosition: const TextNodePosition(offset: 3),
      ),
    )!;
    expect(edge.shift(layout).top, moreOrLessEquals(before.top));
  });
}

/// Every image a document refers to is [image].
final class _OneImage implements DocumentImageLookup {
  const _OneImage(this.image);

  final ImageProvider image;

  @override
  SizedImage? of(String url) =>
      (_) => image;
}
