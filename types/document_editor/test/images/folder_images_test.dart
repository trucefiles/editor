import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  testWidgets('an image that could not be read is read again as it shows '
      'again', (tester) async {
    Uint8List? bytes;
    final images = FolderImages(
      (_) async => bytes,
      folder: folderId('f1'),
      document: path('doc.md'),
      openedAt: DateTime(2026),
    );
    Future<void> show() async {
      await tester.pumpWidget(
        MaterialApp(
          home: DocumentImage('a.png', alt: 'a picture', images: images),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }

    await show();
    expect(find.text('a picture'), findsOne);

    bytes = onePixelPng;
    await tester.pumpWidget(const SizedBox());
    await show();

    expect(find.text('a picture'), findsNothing);
  });

  testWidgets('a document image is decoded no higher than it shows, so a '
      'large photo never fills memory', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final asked = <Within>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DocumentImage('a.png', alt: 'a picture', images: _Sizes(asked)),
      ),
    );

    expect(asked, [const Within(DecodeSize.largestSide, 640)]);
  });
}

/// One picture, telling each size it is asked at.
final class _Sizes implements DocumentImageLookup {
  const _Sizes(this.asked);

  final List<Within> asked;

  @override
  SizedImage? of(String url) => (size) {
    asked.add(size);
    return MemoryImage(onePixelPng);
  };
}
