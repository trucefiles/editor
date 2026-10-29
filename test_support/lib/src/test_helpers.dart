import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart' show addTearDown;
import 'package:truce_core/truce_core.dart';

RelPath path(String raw) => RelPath.parse(raw)!;

Uint8List bytesOf(String text) => Uint8List.fromList(text.codeUnits);

/// Unwraps results in tests; a wrong variant fails the test with a cast
/// error.
extension ResultUnwrap<T, E> on Result<T, E> {
  T get value => (this as Ok<T, E>).value;
  E get error => (this as Err<T, E>).error;
}

extension WriteCreatingFolders on File {
  /// Writes [text], creating the folders on the file's path first.
  void writeCreatingFolders(String text) => this
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
}

/// A fresh temp folder, deleted after the test.
Directory tempFolder() {
  final dir = Directory.systemTemp.createTempSync('truce_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}
