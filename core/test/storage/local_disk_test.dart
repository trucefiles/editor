import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('truce_local_disk');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  LocalDisk disk({bool live = true}) => LocalDisk(
    replacesInPlace: false,
    followsLive: (_) => live,
    seesParents: (_) => true,
  );

  test('opens the folder at a file address', () async {
    Directory('${dir.path}/work').createSync();
    File('${dir.path}/.stfolder').createSync();
    final place = disk().at(
      Uri.file(dir.path),
      tempName: (token) => '$token.tmp',
    );

    await place.files.create(path('a.md'), bytesOf('text'));

    expect(File('${dir.path}/a.md').readAsStringSync(), 'text');
    expect((await place.subfolders.namesIn(null)).value, ['work']);
    expect(await place.markers.holds('.stfolder'), isTrue);
    expect(place.changes, isA<WatchedLiveChanges>());
  });

  test('gives no live changes where the platform tells none', () {
    final place = disk(live: false)
        .at(Uri.file(dir.path), tempName: (token) => '$token.tmp');

    expect(place.changes, isNull);
  });

  test('other kinds of address are a bug', () {
    expect(
      () => disk().markersAt(Uri.parse('cloud://me/docs')),
      throwsArgumentError,
    );
  });
}
