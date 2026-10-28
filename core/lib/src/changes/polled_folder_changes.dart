import 'dart:async';

import 'folder_changes.dart';

/// [FolderChanges] where they can't be followed live: asks for the folder
/// to be listed again every [interval]. Never ends on its own.
final class PolledFolderChanges implements FolderChanges {
  const PolledFolderChanges({required this.interval});

  final Duration interval;

  @override
  Stream<ChangeHint> get changes =>
      Stream.periodic(interval, (_) => const ListAgain());
}
