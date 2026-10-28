import 'package:flutter/foundation.dart';

/// A folder the user granted the app on this device, e.g. a Syncthing
/// folder: what [DocumentFolder]s show parts of. One sync tool works on it.
///
/// Per device and never synced. Value-equal, so everything built for it
/// (its files, its reach) stays while it is the same.
@immutable
final class BaseFolder {
  const BaseFolder({
    required this.id,
    required this.path,
    required this.toolId,
  });

  /// Random, stable on this device; names app storage that belongs to the
  /// base folder (its drafts and backups) and keys its documents.
  final String id;

  /// Absolute path on this device.
  final String path;

  /// The id of the sync tool that works on it.
  final String toolId;

  Map<String, Object> toJson() => {'id': id, 'path': path, 'tool': toolId};

  /// `null` if [json] is not a base folder written by [toJson].
  static BaseFolder? fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'path': final String path,
      'tool': final String toolId,
    } =>
      BaseFolder(id: id, path: path, toolId: toolId),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is BaseFolder &&
      other.id == id &&
      other.path == path &&
      other.toolId == toolId;

  @override
  int get hashCode => Object.hash(id, path, toolId);
}
