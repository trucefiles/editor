import 'package:truce_files/truce_files.dart';

import '../../common/store_error_text.dart';

/// User-facing text for why a file can't be opened.
extension OpenFailureText on OpenFailure {
  String get text => switch (this) {
    NotText() => "It isn't text.",
    NotRead(:final error) => error.text,
  };
}
