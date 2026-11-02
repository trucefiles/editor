/// Small rules on folder addresses (URIs) that every disk plugin uses.
library;

/// The folder's own name: the last non-empty segment of [address].
String lastSegment(Uri address) => address.pathSegments.lastWhere(
  (segment) => segment.isNotEmpty,
  orElse: () => '$address',
);

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
