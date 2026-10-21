import '../../common/error_text.dart';
import '../../folders/ui/folder_badge.dart';
import '../move_failure.dart';

/// What to tell the user about [failure].
String moveFailureText(MoveFailure failure) => switch (failure) {
  MoveBlockedByConflict() => 'This note has a sync conflict. Please resolve it first, then move the note.',
  MoveNotWritten(:final error) => "Couldn't move the note: ${error.text}",
  MoveLeftOriginal(:final copy, :final error) =>
    'Saved as ${placeName(copy.folder, copy.path.parent)}/${copy.path.name}, '
        "but the old file couldn't be removed: ${error.text}",
};
