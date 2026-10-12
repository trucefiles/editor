import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Id of the folder the notes grid is filtered to; `null` shows all.
final selectedFolderIdProvider = NotifierProvider<FolderIdChoice, String?>(
  FolderIdChoice.new,
);

/// Id of the folder a note was last created in, the next default.
final lastUsedFolderIdProvider = NotifierProvider<FolderIdChoice, String?>(
  FolderIdChoice.new,
);

/// A remembered folder id, for this app run only.
class FolderIdChoice extends Notifier<String?> {
  @override
  String? build() => null;

  void choose(String? folderId) => state = folderId;
}
