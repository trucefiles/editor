/// What the folder state tells of one document's conflict: the one rule
/// the lists, the reads and the document steps share.
library;

import 'package:truce_core/truce_core.dart';

import '../document.dart';
import '../document_types.dart';

/// The conflict copies [state] holds of the document at [key] that are
/// merged into it, in the order they merge: none unless its type merges
/// ([types]) and its file is there.
List<ConflictCopy> mergedCopiesOf(
  FolderState state,
  DocumentTypes types,
  DocumentKey key,
) => switch (_conflictAt(state, key)) {
  final conflict? when mergesIn(conflict, types) => conflict.copies,
  _ => const [],
};

/// Whether a conflict of the document at [key] waits for the user in
/// [state]: one whose copies are not merged in (see [mergesIn]).
bool conflictWaitsIn(FolderState state, DocumentTypes types, DocumentKey key) =>
    switch (_conflictAt(state, key)) {
      final conflict? => !mergesIn(conflict, types),
      null => false,
    };

/// Whether [conflict]'s copies are merged into its document, not resolved
/// by the user: its type merges ([types]) and its file is there.
bool mergesIn(Conflict conflict, DocumentTypes types) =>
    !conflict.isOrphaned && types.mergeOf(conflict.mainPath) != null;

/// The pending conflict of the document at [key], as last listed.
Conflict? _conflictAt(FolderState state, DocumentKey key) =>
    switch (state.bases[key.baseId]) {
      Listed(:final conflicts) => conflicts[key.path],
      _ => null,
    };
