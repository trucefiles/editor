import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';

import 'base_folder.dart';

/// A folder the user added on this device, as the app shows it: a name
/// and a color name ([color], from the app's palette) for one part of a
/// [base] folder, the whole of it or some of its subfolders
/// ([selection]). A view: changing it moves no file and
/// none of the app's own data.
///
/// Per device and never synced: another device may name, color and
/// select the same folder differently.
@immutable
final class DocumentFolder {
  const DocumentFolder({
    required this.id,
    required this.base,
    required this.selection,
    required this.name,
    required this.color,
  });

  /// Random, stable on this device.
  final String id;

  final BaseFolder base;

  /// What it shows of [base]: never empty.
  final Selection selection;

  final String name;

  /// The name of its color in the app's palette.
  final String color;

  /// Whether the file or folder at [path] in [base] belongs to it.
  bool covers(RelPath path) => selection.covers(path);

  DocumentFolder copyWith({
    String? name,
    String? color,
    Selection? selection,
  }) => DocumentFolder(
    id: id,
    base: base,
    selection: selection ?? this.selection,
    name: name ?? this.name,
    color: color ?? this.color,
  );

  @override
  bool operator ==(Object other) =>
      other is DocumentFolder &&
      other.id == id &&
      other.base == base &&
      other.selection == selection &&
      other.name == name &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, base, selection, name, color);
}
