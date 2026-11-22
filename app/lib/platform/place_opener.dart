import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'link_opener.dart';

final placeOpenerProvider = Provider<PlaceOpener>(
  (ref) => PlaceOpener(ref.watch(linkOpenerProvider)),
);

/// Shows a place, given as its address or name or as a point, in a maps
/// app; where the system has none, on OpenStreetMap in the browser (which
/// sends the place to openstreetmap.org, on a tap only). The same rule on
/// every platform: the system says whether something handles `geo:`
/// links.
class PlaceOpener {
  const PlaceOpener(this._links);

  final LinkOpener _links;

  /// `false` if nothing could show [place].
  Future<bool> open(String place) =>
      _openFirst(geoLink(place), openStreetMapSearch(place));

  /// `false` if nothing could show the point [latitude], [longitude] (in
  /// degrees).
  Future<bool> openPoint(double latitude, double longitude) => _openFirst(
    geoPointLink(latitude, longitude),
    openStreetMapPoint(latitude, longitude),
  );

  Future<bool> _openFirst(Uri maps, Uri web) async =>
      await _links.open(maps) || await _links.open(web);
}

/// A `geo:` link that asks a maps app to search for [place] (RFC 5870,
/// with the query Android's maps apps read).
Uri geoLink(String place) =>
    Uri.parse('geo:0,0?q=${Uri.encodeComponent(place)}');

/// OpenStreetMap's search for [place].
Uri openStreetMapSearch(String place) =>
    Uri.https('www.openstreetmap.org', '/search', {'query': place});

/// A `geo:` link to the point [latitude], [longitude] (RFC 5870).
Uri geoPointLink(double latitude, double longitude) =>
    Uri.parse('geo:$latitude,$longitude');

/// OpenStreetMap's map with a marker at [latitude], [longitude], close
/// enough to see its streets.
Uri openStreetMapPoint(double latitude, double longitude) => Uri(
  scheme: 'https',
  host: 'www.openstreetmap.org',
  path: '/',
  queryParameters: {'mlat': '$latitude', 'mlon': '$longitude'},
  fragment: 'map=16/$latitude/$longitude',
);
