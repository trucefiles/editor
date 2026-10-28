/// The folder list owner's contract: the folders added on this device,
/// and the user's changes to them, each answered once it is saved. It
/// runs them one at a time, in the order sent, so each change starts from
/// the list the one before saved.
library;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:truce_core/truce_core.dart';

import 'document_folder.dart';
import 'folder_error.dart';
import 'folder_list_store.dart';

// State.

sealed class FolderListState {
  const FolderListState();
}

/// Not loaded yet.
final class FoldersLoading extends FolderListState {
  const FoldersLoading();
}

/// The saved folders, in the order added.
final class FoldersLoaded extends FolderListState {
  const FoldersLoaded(this.folders);

  final List<DocumentFolder> folders;

  @override
  bool operator ==(Object other) =>
      other is FoldersLoaded && listEquals(other.folders, folders);

  @override
  int get hashCode => Object.hashAll(folders);
}

/// The saved list could not be loaded; nothing changes it until the next
/// start.
final class FoldersUnreadable extends FolderListState {
  const FoldersUnreadable(this.error);

  final SettingsError error;
}

// Inputs.

sealed class FolderListInput {
  const FolderListInput();
}

/// Load the saved list; the owner's first input.
final class LoadFolders extends FolderListInput {
  const LoadFolders();
}

sealed class FolderListAsking extends FolderListInput implements Asking {
  const FolderListAsking(this.ticket);

  @override
  final Ticket ticket;
}

/// Add a folder showing [selection] of the base folder at [basePath],
/// which the sync tool [toolId] works on; an added base folder at the
/// same place is used again, with its own tool.
final class AddFolder extends FolderListAsking {
  const AddFolder(
    super.ticket, {
    required this.basePath,
    required this.toolId,
    required this.selection,
    required this.name,
    required this.color,
  });

  final String basePath;
  final String toolId;
  final Selection selection;
  final String name;
  final Color color;
}

/// Change a folder's name, color or selection to [changed]'s.
final class ChangeFolder extends FolderListAsking {
  const ChangeFolder(super.ticket, this.changed);

  final DocumentFolder changed;
}

/// Forget [removed]; its files stay untouched. Its base folder goes with
/// its last folder.
final class RemoveFolder extends FolderListAsking {
  const RemoveFolder(super.ticket, this.removed);

  final DocumentFolder removed;
}

// Events: one answer per asking input.

sealed class FolderListAnswer implements Answering {
  const FolderListAnswer(this.ticket);

  @override
  final Ticket ticket;
}

final class FolderAdded extends FolderListAnswer {
  const FolderAdded(super.ticket, this.result);

  /// The folder added.
  final Result<DocumentFolder, FolderError> result;
}

final class FolderChanged extends FolderListAnswer {
  const FolderChanged(super.ticket, this.result);

  final Result<void, FolderError> result;
}

final class FolderRemoved extends FolderListAnswer {
  const FolderRemoved(super.ticket, this.result);

  final Result<void, FolderError> result;
}
