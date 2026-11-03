import 'package:truce_files/truce_files.dart';

import '../../common/store_error_text.dart';

/// What to tell the user about [failure].
String deleteFailureText(DeleteFailure failure) => switch (failure) {
  DeleteBlockedByConflict() =>
    "Resolve this file's sync conflict first, then delete it.",
  DeleteNotDone(:final error) => error.text,
};
