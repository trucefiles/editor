import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

/// Id of the folder the files grid is filtered to; `null` shows all.
final selectedFolderIdProvider = NotifierProvider<FolderIdChoice, FolderId?>(
  FolderIdChoice.new,
);

/// A remembered folder id, for this app run only.
class FolderIdChoice extends Notifier<FolderId?> {
  @override
  FolderId? build() => null;

  void choose(FolderId? folderId) => state = folderId;
}
