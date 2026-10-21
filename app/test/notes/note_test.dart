import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  final note = noteOf(
    folderAt(Directory.systemTemp),
    '# Shopping\n- [x] milk\n- [ ] eggs',
  );

  test('shows its title and previews', () {
    expect(note.title, 'Shopping');
    expect(note.preview(hideDone: false), '☑ milk\n☐ eggs');
    expect(note.preview(hideDone: true), '☐ eggs\n+ 1 done');
  });

  test('works out its title and previews once', () {
    expect(identical(note.title, note.title), isTrue);
    expect(
      identical(note.preview(hideDone: true), note.preview(hideDone: true)),
      isTrue,
    );
  });
}
