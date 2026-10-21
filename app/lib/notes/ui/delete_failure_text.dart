import '../../common/error_text.dart';
import '../delete_failure.dart';

/// What to tell the user about [failure].
String deleteFailureText(DeleteFailure failure) => switch (failure) {
  DeleteBlockedByConflict() => 'This note has a sync conflict. Please resolve it first, then delete the note.',
  DeleteNotDone(:final error) => error.text,
};
