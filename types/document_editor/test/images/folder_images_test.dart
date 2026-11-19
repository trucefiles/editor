import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'image_fakes.dart';

void main() {
  testWidgets('an image that could not be read is read again as it shows '
      'again', (tester) async {
    Uint8List? bytes;
    final images = FolderImages(
      (_) async => bytes,
      folder: folderId('f1'),
      document: path('doc.md'),
      readSince: DateTime(2026),
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
}
