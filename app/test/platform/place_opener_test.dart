import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/link_opener.dart';
import 'package:truce_editor/platform/place_opener.dart';

/// Opens only links of the [handled] schemes, noting every one asked.
class _Links implements LinkOpener {
  _Links(this.handled);

  final Set<String> handled;
  final asked = <Uri>[];

  @override
  Future<bool> open(Uri link) async {
    asked.add(link);
    return handled.contains(link.scheme);
  }
}

void main() {
  test('a place opens in a maps app where the system has one', () async {
    final links = _Links({'geo', 'https'});

    expect(await PlaceOpener(links).open('Main St 1, Town'), isTrue);
    expect(links.asked, [Uri.parse('geo:0,0?q=Main%20St%201%2C%20Town')]);
  });

  test("else in OpenStreetMap's search in the browser", () async {
    final links = _Links({'https'});

    expect(await PlaceOpener(links).open('Main St 1'), isTrue);
    expect(
      links.asked.last.toString(),
      'https://www.openstreetmap.org/search?query=Main+St+1',
    );
  });

  test('false when neither opens', () async {
    expect(await PlaceOpener(_Links({})).open('Main St 1'), isFalse);
  });

  test('a point opens in a maps app, else on OpenStreetMap with a marker '
      'there', () async {
    final maps = _Links({'geo'});
    expect(await PlaceOpener(maps).openPoint(48.1, -11.5), isTrue);
    expect(maps.asked, [Uri.parse('geo:48.1,-11.5')]);

    final web = _Links({'https'});
    expect(await PlaceOpener(web).openPoint(48.1, -11.5), isTrue);
    expect(
      web.asked.last.toString(),
      'https://www.openstreetmap.org/?mlat=48.1&mlon=-11.5#map=16/48.1/-11.5',
    );
  });
}
