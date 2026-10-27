import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  final document = documentOf(
    folderAt(Directory.systemTemp),
    '# Shopping\n- [x] milk\n- [ ] eggs',
  );

  test('shows its title and previews', () {
    expect(document.title, 'Shopping');
    expect(document.preview(hideDone: false), '☑ milk\n☐ eggs');
    expect(document.preview(hideDone: true), '☐ eggs\n+ 1 done');
  });

  test('works out its title and previews once', () {
    expect(identical(document.title, document.title), isTrue);
    expect(
      identical(
        document.preview(hideDone: true),
        document.preview(hideDone: true),
      ),
      isTrue,
    );
  });
}
