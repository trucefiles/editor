import 'package:truce_documents/truce_documents.dart';

/// What to tell the user about [failure].
String deleteFailureText(DeleteFailure failure) => switch (failure) {
  DeleteBlockedByConflict() => 'This document has a sync conflict. Please resolve it first, then delete the document.',
  DeleteNotDone(:final error) => error.text,
};
