import '../../common/error_text.dart';
import '../delete_failure.dart';

/// What to tell the user about [failure].
String deleteFailureText(DeleteFailure failure) => switch (failure) {
  DeleteBlockedByConflict() => 'This document has a sync conflict. Please resolve it first, then delete the document.',
  DeleteNotDone(:final error) => error.text,
};
