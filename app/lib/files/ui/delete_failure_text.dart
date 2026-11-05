import 'package:truce_files/truce_files.dart';

import '../../common/store_error_text.dart';

/// What to tell the user about [failure].
String deleteFailureText(DeleteFailure failure) => switch (failure) {
  DeleteBlockedByConflict() =>
    "Resolve this file's sync conflict first, then delete it.",
  DeleteNotBackedUp() =>
    "No backup of the file could be made, so it wasn't deleted.",
  DeleteNotDone(:final error) => error.text,
};
