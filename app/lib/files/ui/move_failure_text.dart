import 'package:truce_files/truce_files.dart';

import '../../folders/ui/folder_badge.dart';

/// What to tell the user about [failure].
String moveFailureText(MoveFailure failure) => switch (failure) {
  MoveNotSaved() =>
    "Couldn't move the file now: it isn't saved in its folder yet. "
        'Please try again.',
  MoveBlockedByConflict() => 'This file has a sync conflict. Please resolve it first, then move the file.',
  MoveNotWritten(:final error) => "Couldn't move the file: ${error.text}",
  MoveLeftOriginal(:final copy, :final error) =>
    'Saved as ${placeName(copy.folder, copy.path.parent)}/${copy.path.name}, '
        "but the old file couldn't be removed: ${error.text}",
};
