import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  final areas = DiskAreas()
    ..claim('syncthing', [Uri.file('/home/me/Sync')])
    ..claim('local', [Uri.file('/home/me/Notes')]);

  test('an area of another plugin at, inside or around clashes', () {
    for (final path in ['/home/me/Sync', '/home/me/Sync/work', '/home/me']) {
      expect(areas.clashes('local', Uri.file(path)), isTrue, reason: path);
    }
  });

  test("a plugin's own areas and unrelated paths don't clash", () {
    expect(areas.clashes('syncthing', Uri.file('/home/me/Sync/work')), isFalse);
    expect(areas.clashes('local', Uri.file('/home/me/Sync2')), isFalse);
    expect(areas.clashes('local', Uri.file('/home/me/Notes/a')), isFalse);
  });

  test('a new claim replaces the old one', () {
    final claimed = DiskAreas()
      ..claim('local', [Uri.file('/a')])
      ..claim('local', [Uri.file('/b')]);

    expect(claimed.clashes('other', Uri.file('/a')), isFalse);
    expect(claimed.clashes('other', Uri.file('/b')), isTrue);
  });

  test('paths inside another one, by segments', () {
    expect(
      segmentsInside(Uri.file('/home/me/Sync/a/b'), Uri.file('/home/me/Sync')),
      ['a', 'b'],
    );
    expect(
      segmentsInside(Uri.file('/home/me/Sync'), Uri.file('/home/me/Sync')),
      isNull,
    );
    expect(
      segmentsInside(Uri.file('/home/me/Sync2'), Uri.file('/home/me/Sync')),
      isNull,
    );
  });
}
