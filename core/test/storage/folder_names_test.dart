import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('reads local folder names; null if unreadable', () async {
    final dir = Directory.systemTemp.createTempSync('truce_names');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/.stfolder').createSync();
    File('${dir.path}/a.md').writeAsStringSync('');

    expect(await readLocalFolderNames(dir.path), {'.stfolder', 'a.md'});
    expect(await readLocalFolderNames('${dir.path}/missing'), isNull);
  });
}
