import '../../common/error_text.dart';
import '../delete_failure.dart';

/// What to tell the user about [failure].
String deleteFailureText(DeleteFailure failure) => switch (failure) {
  DeleteBlockedByConflict() =>
    'Resolve the sync conflict of this note first, then delete it.',
  DeleteNotDone(:final error) => error.text,
};
