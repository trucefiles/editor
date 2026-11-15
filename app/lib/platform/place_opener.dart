import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'link_opener.dart';

final placeOpenerProvider = Provider<PlaceOpener>(
  (ref) => PlaceOpener(ref.watch(linkOpenerProvider)),
);

/// Shows a place, given as its address or name, in a maps app; where the
/// system has none, in OpenStreetMap's search in the browser (which sends
/// the place to openstreetmap.org, on a tap only). The same rule on every
/// platform: the system says whether something handles `geo:` links.
class PlaceOpener {
  const PlaceOpener(this._links);

  final LinkOpener _links;

  /// `false` if nothing could show [place].
  Future<bool> open(String place) async =>
      await _links.open(geoLink(place)) ||
      await _links.open(openStreetMapSearch(place));
}

/// A `geo:` link that asks a maps app to search for [place] (RFC 5870,
/// with the query Android's maps apps read).
Uri geoLink(String place) =>
    Uri.parse('geo:0,0?q=${Uri.encodeComponent(place)}');

/// OpenStreetMap's search for [place].
Uri openStreetMapSearch(String place) =>
    Uri.https('www.openstreetmap.org', '/search', {'query': place});
