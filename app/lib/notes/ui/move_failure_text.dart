import '../../common/error_text.dart';
import '../../folders/ui/folder_badge.dart';
import '../move_failure.dart';

/// What to tell the user about [failure].
String moveFailureText(MoveFailure failure) => switch (failure) {
  MoveBlockedByConflict() =>
    'Resolve the sync conflict of this note first, then move it.',
  MoveNotWritten(:final error) => "Couldn't move the note: ${error.text}",
  MoveLeftOriginal(:final copy, :final error) =>
    'The note is now also in ${placeName(copy.folder, copy.path.parent)}, '
        "but couldn't be removed here: ${error.text}",
};
