import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Where a folder's files live: all its services depend on. Name and color
/// are left out, so changing them keeps the services.
typedef FolderLocation = ({String id, String path});

/// A folder the user added on this device, with its display settings.
///
/// Per device and never synced: another device may name and color the same
/// folder differently.
@immutable
final class DocumentFolder {
  const DocumentFolder({
    required this.id,
    required this.path,
    required this.name,
    required this.color,
  });

  /// Random, stable on this device; names app storage that belongs to the
  /// folder (e.g. its conflict backups).
  final String id;

  /// Absolute path on this device.
  final String path;

  final String name;
  final Color color;

  FolderLocation get location => (id: id, path: path);

  DocumentFolder copyWith({String? name, Color? color}) => DocumentFolder(
    id: id,
    path: path,
    name: name ?? this.name,
    color: color ?? this.color,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'color': color.toARGB32(),
  };

  /// `null` if [json] is not a folder written by [toJson].
  static DocumentFolder? fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'path': final String path,
      'name': final String name,
      'color': final int color,
    } =>
      DocumentFolder(id: id, path: path, name: name, color: Color(color)),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is DocumentFolder &&
      other.id == id &&
      other.path == path &&
      other.name == name &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, path, name, color);
}
