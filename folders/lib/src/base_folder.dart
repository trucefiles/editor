import 'package:meta/meta.dart';

/// A folder the user granted the app on this device, e.g. a Syncthing
/// folder: what [DocumentFolder]s show parts of. One sync tool works on it.
///
/// Per device and never synced. Value-equal, so everything built for it
/// (its files, its reach) stays while it is the same.
@immutable
final class BaseFolder {
  const BaseFolder({
    required this.id,
    required this.address,
    required this.toolId,
  });

  /// Random, stable on this device; names app storage that belongs to the
  /// base folder (its drafts and backups) and keys its documents.
  final String id;

  /// Where its sync tool finds it, e.g. `file:` for a folder on this
  /// device. Only the tool opens it; the app keeps, compares and shows it.
  final Uri address;

  /// The id of the sync tool that works on it.
  final String toolId;

  /// Where it is, for the user: a folder on this device by its path.
  String get shownAddress => addressText(address);

  Map<String, Object> toJson() => {
    'id': id,
    'address': '$address',
    'tool': toolId,
  };

  /// `null` if [json] is not a base folder written by [toJson].
  static BaseFolder? fromJson(Object? json) => switch (json) {
    {
      'id': final String id,
      'address': final String address,
      'tool': final String toolId,
    } =>
      switch (Uri.tryParse(address)) {
        final address? when address.hasScheme => BaseFolder(
          id: id,
          address: address,
          toolId: toolId,
        ),
        _ => null,
      },
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is BaseFolder &&
      other.id == id &&
      other.address == address &&
      other.toolId == toolId;

  @override
  int get hashCode => Object.hash(id, address, toolId);
}

/// [address] for the user: a folder on this device by its path, any other
/// as it is.
String addressText(Uri address) =>
    address.isScheme('file') ? address.toFilePath() : '$address';
