import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

/// A folder the user added on this device: one directory, set up by a
/// plugin, as the app shows it: a name and a color name ([color], from
/// the app's palette). Paths of its files count from it.
///
/// Per device and never synced: another device may name and color the
/// same directory differently.
@immutable
final class Folder {
  const Folder({
    required this.id,
    required this.name,
    required this.color,
    required this.location,
  });

  final FolderId id;

  final String name;

  /// The name of its color in the app's palette.
  final String color;

  /// Where it is, for the user, as its plugin tells it.
  final String location;

  Folder copyWith({String? name, String? color}) => Folder(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    location: location,
  );

  @override
  bool operator ==(Object other) =>
      other is Folder &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.location == location;

  @override
  int get hashCode => Object.hash(id, name, color, location);
}

/// Questions on the folders added on this device.
extension FolderLookup on Iterable<Folder> {
  /// The folder [id]; `null` if none is (any more).
  Folder? byId(FolderId id) => where((folder) => folder.id == id).firstOrNull;
}
