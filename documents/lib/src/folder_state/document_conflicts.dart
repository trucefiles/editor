import 'package:truce_core/truce_core.dart';

import '../document.dart';

/// Whether a sync conflict of the document at [key] waits for the user in
/// [state], as last listed.
bool conflictWaitsIn(FolderState state, DocumentKey key) =>
    switch (state.bases[key.baseId]) {
      Listed(:final conflicts) => conflicts.containsKey(key.path),
      _ => false,
    };
