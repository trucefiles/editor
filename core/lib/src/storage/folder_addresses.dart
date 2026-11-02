/// Small rules on folder addresses (URIs) that every disk plugin uses.
library;

/// The folder's own name: the last non-empty segment of [address].
String lastSegment(Uri address) => address.pathSegments.lastWhere(
  (segment) => segment.isNotEmpty,
  orElse: () => '$address',
);

/// Whether the folder at [address] lies in a hidden folder (or is one),
/// e.g. a sync tool's own version folder: never one to add.
bool liesInHidden(Uri address) =>
    address.pathSegments.any((segment) => segment.startsWith('.'));

/// [address] as the user reads it: a path for a folder on this device,
/// else the address as it is.
String shownAddress(Uri address) =>
    address.isScheme('file') ? address.toFilePath() : '$address';

/// The folder address [raw] holds as saved; `null` unless it is one on
/// this device.
Uri? savedFileAddress(String raw) => switch (Uri.tryParse(raw)) {
  final uri? when uri.isScheme('file') => uri,
  _ => null,
};
