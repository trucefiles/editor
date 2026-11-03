import 'package:truce_files/truce_files.dart';

import '../../common/store_error_text.dart';
import '../../folders/ui/folder_badge.dart';

/// What to tell the user about [failure].
String moveFailureText(MoveFailure failure) => switch (failure) {
  MoveNotSaved() =>
    "Couldn't move the file yet: it isn't saved in its folder. "
        'Please try again.',
  MoveBlockedByConflict() =>
    "Resolve this file's sync conflict first, then move it.",
  MoveNotWritten(:final error) => "Couldn't move the file: ${error.text}",
  MoveLeftOriginal(:final copy, :final error) =>
    'Saved as ${placeName(copy.folder, copy.path.parent)}/${copy.path.name}, '
        "but the old file couldn't be removed: ${error.text}",
};
