import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../listed_file.dart';
import '../shown_file_types.dart';
import 'folder_files.dart';

/// What the added folders hold now ([shown]) and when each part of it
/// was seen, for the open files and compare views, which must not take
/// an old listing for news.
final class FolderContents {
  /// [state] as [folders] and [types] show it; [shown] is [before]'s
  /// while the folders found the same, so screens rebuild only on a
  /// change.
  FolderContents(
    this.state, {
    required List<Folder> folders,
    required ShownFileTypes types,
    FolderContents? before,
  }) : shown = switch (before?.shown) {
         final shown?
             when shown.madeOf(state, folders: folders, types: types) =>
           shown,
         _ => FolderFiles(state, folders: folders, types: types),
       };

  /// What the folders hold.
  final FolderState state;

  /// What the screens show of it.
  final FolderFiles shown;

  /// When what is known of the file at [key] was seen: writes that
  /// ended later are not in it. `null` if its folder was not listed.
  Moment? seenAt(FileKey key) => switch (state.folders[key.folder]) {
    final Listed listed when shown.folders.any((f) => f.id == key.folder) =>
      listed.seenAt(key.path),
    _ => null,
  };
}
