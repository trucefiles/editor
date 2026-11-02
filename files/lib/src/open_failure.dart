import 'package:truce_core/truce_core.dart';

/// Why a file can't be opened.
sealed class OpenFailure {
  const OpenFailure();
}

/// The file holds no text (its bytes are not UTF-8). Told by the file
/// itself, so it stays so until the file changes.
final class NotText extends OpenFailure {
  const NotText();
}

/// The file could not be read, or the folder doesn't show it.
final class NotRead extends OpenFailure {
  const NotRead(this.error);

  final StoreError error;

  @override
  bool operator ==(Object other) => other is NotRead && other.error == error;

  @override
  int get hashCode => error.hashCode;
}
