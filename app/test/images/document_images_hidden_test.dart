import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/open_folders_wiring.dart';
import 'package:truce_test_support/truce_test_support.dart' show onePixelPng;

import '../support.dart';

/// Pictures added to documents live in the folder's own store; now that
/// pictures show as files, they still never list as files of their own.
void main() {
  test("a document's pictures never list as image files", () async {
    final dir = tempFolder();
    File('${dir.path}/note.md').writeAsStringSync('![](document-images/x)\n');
    File('${dir.path}/photo.png').writeAsBytesSync(onePixelPng);
    Directory('${dir.path}/document-images').createSync();
    File('${dir.path}/document-images/img-0123456789abcdef.png')
        .writeAsBytesSync(onePixelPng);
    final services = servicesFor(folderAt(dir));

    final scan = (await services.scanner.scan()).value;

    expect(
      {for (final file in scan.files) file.path.value},
      {'note.md', 'photo.png'},
    );
    expect(scan.subfolders, isNot(contains(path('document-images'))));
  });

  test("a document's pictures are not shown files, so stay out of Backups "
      'and their space', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bounds = container.read(fileBoundsProvider);

    expect(bounds.shows(path('photo.png')), isTrue);
    expect(
      bounds.shows(path('document-images/img-0123456789abcdef.png')),
      isFalse,
    );
  });
}
