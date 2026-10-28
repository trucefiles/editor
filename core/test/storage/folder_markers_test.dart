import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('truce_markers');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  test('tells whether the base folder or a parent holds a name', () async {
    Directory('${dir.path}/.stfolder').createSync();
    Directory('${dir.path}/notes').createSync();
    final markers = LocalFolderMarkers('${dir.path}/notes', seesParents: true);

    expect(await markers.holds('.stfolder'), isFalse);
    expect(await markers.holds('.stfolder', levelsUp: 1), isTrue);
  });

  test('null for a folder it cannot see or that is gone', () async {
    final hidden = LocalFolderMarkers(dir.path, seesParents: false);
    final gone = LocalFolderMarkers('${dir.path}/gone', seesParents: true);

    expect(await hidden.holds('.stfolder', levelsUp: 1), isNull);
    expect(await gone.holds('.stfolder'), isNull);
    expect(await hidden.holds('.stfolder'), isFalse);
  });

  test('null above the file system root', () async {
    final markers = LocalFolderMarkers('/', seesParents: true);

    expect(await markers.holds('x', levelsUp: 1), isNull);
  });
}
