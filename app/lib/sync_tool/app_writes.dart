import 'dart:async';

import 'package:truce_core/truce_core.dart';

/// The app's own writes into the base folders, as they happen: told by
/// each base folder's services, heard by whoever keeps what the folders
/// hold.
final class AppWrites {
  final _writes = StreamController<AppWrote>.broadcast(sync: true);

  Stream<AppWrote> get all => _writes.stream;

  /// The app wrote [paths] in the base folder [baseId], now.
  void wrote(String baseId, Set<RelPath> paths) {
    if (!_writes.isClosed) {
      _writes.add(AppWrote(baseId, paths, at: DateTime.now()));
    }
  }

  void close() => unawaited(_writes.close());
}
