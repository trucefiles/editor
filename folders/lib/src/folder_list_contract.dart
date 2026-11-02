/// The folder list owner's contract: the folders added on this device,
/// and the user's changes to them, each answered once it is saved. It
/// runs them one at a time, in the order sent, so each change starts from
/// the list the one before saved.
library;

import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';

import 'folder.dart';
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

  final List<Folder> folders;

  @override
  bool operator ==(Object other) =>
      other is FoldersLoaded &&
      const ListEquality<Folder>().equals(other.folders, folders);

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

/// Add the folders [candidates] name, which [plugin]'s add page returned,
/// each with the name and color the user gave it: all together or none.
final class AddFolders extends FolderListAsking {
  AddFolders(
    super.ticket, {
    required this.plugin,
    required List<NamedCandidate> candidates,
  }) : candidates = List.unmodifiable(candidates);

  /// The plugin's id.
  final String plugin;
  final List<NamedCandidate> candidates;
}

/// A folder to add, with the name and color the user gave it.
typedef NamedCandidate = ({
  PluginFolderCandidate candidate,
  String name,
  String color,
});

/// Change a folder's name or color to [changed]'s.
final class ChangeFolder extends FolderListAsking {
  const ChangeFolder(super.ticket, this.changed);

  final Folder changed;
}

/// Forget [removed]; its files stay untouched.
final class RemoveFolder extends FolderListAsking {
  const RemoveFolder(super.ticket, this.removed);

  final Folder removed;
}

/// How many files have edits kept only on this device that removing
/// [folder] would delete; asked after securing its open files, so the
/// count is the one the user is warned with.
final class CountDrafts extends FolderListAsking {
  const CountDrafts(super.ticket, this.folder);

  final Folder folder;
}

// Events: one answer per asking input.

sealed class FolderListAnswer implements Answering {
  const FolderListAnswer(this.ticket);

  @override
  final Ticket ticket;
}

final class FoldersAdded extends FolderListAnswer {
  const FoldersAdded(super.ticket, this.result);

  /// The folders added, in the order asked.
  final Result<List<Folder>, FolderError> result;
}

final class FolderChanged extends FolderListAnswer {
  const FolderChanged(super.ticket, this.result);

  final Result<void, FolderError> result;
}

final class FolderRemoved extends FolderListAnswer {
  const FolderRemoved(super.ticket, this.result);

  final Result<void, FolderError> result;
}

final class DraftsCounted extends FolderListAnswer {
  const DraftsCounted(super.ticket, this.count);

  final int count;
}
