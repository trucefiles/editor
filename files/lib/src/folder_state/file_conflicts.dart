import 'package:truce_core/truce_core.dart';

import '../listed_file.dart';

/// Whether a sync conflict of the file at [key] waits for the user in
/// [state], as last listed.
bool conflictWaitsIn(FolderState state, FileKey key) =>
    switch (state.folders[key.folder]) {
      Listed(:final conflicts) => conflicts.containsKey(key.path),
      _ => false,
    };
