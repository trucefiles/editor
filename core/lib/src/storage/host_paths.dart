import 'package:collection/collection.dart';

/// Where folders lie on the host system, to tell whether two overlap. In a
/// sandbox (e.g. Flatpak) the app may see each picked folder at its own
/// unrelated path. A platform fact, injected by the platform wiring.
abstract interface class HostPaths {
  /// The host's address of the folder the app sees at [address];
  /// [address] itself where the host's is unknown, or it is no folder on
  /// this device.
  Future<Uri> of(Uri address);
}

/// Platforms where the app sees folders at their host paths.
final class SameHostPaths implements HostPaths {
  const SameHostPaths();

  @override
  Future<Uri> of(Uri address) async => address;
}

/// Whether the folders at [a] and [b] are the same, or one lies inside the
/// other.
bool nests(Uri a, Uri b) =>
    a.scheme == b.scheme &&
    a.authority == b.authority &&
    (_isAtOrInside(_segments(a), _segments(b)) ||
        _isAtOrInside(_segments(b), _segments(a)));

/// Whether [a] and [b] are the same folder, whatever their trailing
/// slashes.
bool isSameFolder(Uri a, Uri b) =>
    a.scheme == b.scheme &&
    a.authority == b.authority &&
    _same.equals(_segments(a), _segments(b));

/// The path of the folder at [inner] inside the one at [outer], as
/// segments; `null` if it doesn't lie there (or is it).
List<String>? segmentsInside(Uri inner, Uri outer) {
  final (inside, around) = (_segments(inner), _segments(outer));
  return inner.scheme == outer.scheme &&
          inner.authority == outer.authority &&
          inside.length > around.length &&
          _same.equals(inside.sublist(0, around.length), around)
      ? inside.sublist(around.length)
      : null;
}

const _same = ListEquality<String>();

bool _isAtOrInside(List<String> inner, List<String> outer) =>
    inner.length >= outer.length &&
    _same.equals(inner.sublist(0, outer.length), outer);

List<String> _segments(Uri address) => [
  for (final segment in address.pathSegments)
    if (segment.isNotEmpty) segment,
];
