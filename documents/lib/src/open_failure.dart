import 'package:truce_core/truce_core.dart';

import 'error_text.dart';

/// Why a document's file can't be opened.
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

/// User-facing text for why a document can't be opened.
extension OpenFailureText on OpenFailure {
  String get text => switch (this) {
    NotText() => "It isn't text.",
    NotRead(:final error) => error.text,
  };
}
