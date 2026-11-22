import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/file_page/ui/unreachable_texts.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import '../../support.dart';

void main() {
  group('an open text', () {
    test('is said to be kept on this device while it is', () {
      expect(textUnreachableText(const Running()), contains('kept'));
      expect(textUnreachableText(const Stopped('a', kept: true)), isNotNull);
    });

    test('is never said to be kept while the device could not keep it, '
        'or it is not known yet', () {
      expect(textUnreachableText(const Stopped('a', kept: false)), isNull);
      expect(textUnreachableText(const Stopped('a')), isNull);
    });
  });

  group('a new shown file', () {
    final file = NewShownFile(
      (folder: folderAt(Directory('/documents')), subfolder: null),
      name: 'Cat.jpg',
      bytes: Uint8List(1),
    );

    test('is said to be kept on this device once it is', () {
      expect(
        shownUnreachableText(
          WaitingNew(
            file,
            kept: NewKept.onDevice,
            content: ContentTag.unique(),
          ),
        ),
        'The file is kept on this device.',
      );
    });

    test('is never said to be kept while it is kept nowhere, or not yet '
        'known', () {
      expect(
        shownUnreachableText(
          WaitingNew(file, kept: NewKept.nowhere, content: ContentTag.unique()),
        ),
        isNull,
      );
      expect(
        shownUnreachableText(
          WaitingNew(file, kept: NewKept.keeping, content: ContentTag.unique()),
        ),
        isNull,
      );
    });
  });
}
