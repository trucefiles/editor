import 'package:truce_documents/truce_documents.dart';

import '../../folders/ui/folder_badge.dart';

/// What to tell the user about [failure].
String moveFailureText(MoveFailure failure) => switch (failure) {
  MoveBlockedByConflict() => 'This document has a sync conflict. Please resolve it first, then move the document.',
  MoveNotWritten(:final error) => "Couldn't move the document: ${error.text}",
  MoveLeftOriginal(:final copy, :final error) =>
    'Saved as ${placeName(copy.folder, copy.path.parent)}/${copy.path.name}, '
        "but the old file couldn't be removed: ${error.text}",
};
