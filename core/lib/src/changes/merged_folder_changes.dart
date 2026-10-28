import 'dart:async';

import '../storage/rel_path.dart';
import 'folder_changes.dart';

/// The changes of all of [_parts] in one, e.g. one watcher per selected
/// subfolder. Ends as soon as one part ends: the folder's changes can no
/// longer all be followed.
final class MergedFolderChanges implements FolderChanges {
  const MergedFolderChanges(this._parts);

  final List<FolderChanges> _parts;

  @override
  Stream<RelPath> get changes {
    final subscriptions = <StreamSubscription<RelPath>>[];
    late final StreamController<RelPath> controller;
    Future<void> end() async {
      await Future.wait(subscriptions.map((part) => part.cancel()));
      await controller.close();
    }

    controller = StreamController<RelPath>(
      onListen: () {
        if (_parts.isEmpty) unawaited(controller.close());
        subscriptions.addAll([
          for (final part in _parts)
            part.changes.listen(controller.add, onDone: () => unawaited(end())),
        ]);
      },
      onCancel: () => Future.wait(subscriptions.map((part) => part.cancel())),
    );
    return controller.stream;
  }
}
