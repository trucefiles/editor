import 'package:truce_files/truce_files.dart';

/// What to tell the user about [failure].
String deleteFailureText(DeleteFailure failure) => switch (failure) {
  DeleteBlockedByConflict() => 'This file has a sync conflict. Please resolve it first, then delete the file.',
  DeleteNotDone(:final error) => error.text,
};
