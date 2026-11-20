/// The contract of a shown file's owner: one file the app only shows
/// (e.g. an image), not edits. It follows the file as the folder lists
/// it, moves it, and writes a new one the user added once they leave.
library;

import 'package:meta/meta.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../file_place.dart';
import '../folder_state/folder_contents.dart';
import '../listed_file.dart';
import '../move_failure.dart';
import 'new_shown_file.dart';

// Inputs.

sealed class ShownInput {
  const ShownInput();
}

/// The folders, as listed now.
final class SeeFolders extends ShownInput {
  const SeeFolders(this.contents);

  final FolderContents contents;
}

/// Move the file to [place], named after [title]; for a new file, only
/// where it will go. [newSubfolder]: [place]'s subfolder is a new one,
/// made with the file. Answered by [Placed].
final class PlaceShown extends ShownInput implements Asking {
  const PlaceShown(
    this.ticket,
    this.place, {
    required this.title,
    this.newSubfolder = false,
  });

  @override
  final Ticket ticket;
  final FilePlace place;
  final String title;
  final bool newSubfolder;
}

/// Keep a new file somewhere lasting, by the rule of [reason]: in its
/// folder, else on the device while hidden or as the app ends. Answered
/// by [Secured].
final class SecureShown extends ShownInput implements Asking {
  const SecureShown(this.ticket, this.reason);

  @override
  final Ticket ticket;
  final SecureReason reason;
}

/// Keep a new file on the device, else write it into its folder at
/// once: sent first, and again when the user retries one that could be
/// kept nowhere.
final class KeepNew extends ShownInput {
  const KeepNew();
}

/// Drop a new file that is not written yet.
final class DropNew extends ShownInput {
  const DropNew();
}

// State.

sealed class ShownState {
  const ShownState();
}

/// Where a new file is kept until it is written.
enum NewKept {
  /// Not yet known: it is being kept.
  keeping,

  /// On the device, for the next start if the app ends first.
  onDevice,

  /// Nowhere but in the app: it is lost if the app ends.
  nowhere,
}

/// A new file the user added, not written yet; [kept] tells where it
/// waits.
@immutable
final class WaitingNew extends ShownState {
  const WaitingNew(this.file, {required this.kept});

  final NewShownFile file;
  final NewKept kept;

  @override
  bool operator ==(Object other) =>
      other is WaitingNew && identical(other.file, file) && other.kept == kept;

  @override
  int get hashCode => Object.hash(identityHashCode(file), kept);
}

/// The file, as listed now.
@immutable
final class ShownListed extends ShownState {
  const ShownListed(this.file);

  final ListedFile file;

  @override
  bool operator ==(Object other) => other is ShownListed && other.file == file;

  @override
  int get hashCode => file.hashCode;
}

/// The file is gone: deleted, moved or renamed elsewhere; [last] is how
/// it was last listed. It is never written again by itself.
@immutable
final class ShownGone extends ShownState {
  const ShownGone(this.last);

  final ListedFile last;

  @override
  bool operator ==(Object other) => other is ShownGone && other.last == last;

  @override
  int get hashCode => last.hashCode;
}

/// A new file the user dropped before it was written.
final class ShownDropped extends ShownState {
  const ShownDropped();
}

// Events.

sealed class ShownEvent {
  const ShownEvent();
}

/// The answer to [PlaceShown]: `null` [failure] once it is there.
final class Placed extends ShownEvent implements Answering {
  const Placed(this.ticket, this.failure);

  @override
  final Ticket ticket;
  final MoveFailure? failure;
}

/// The answer to [SecureShown]: whether the file is kept somewhere
/// lasting.
final class Secured extends ShownEvent implements Answering {
  const Secured(this.ticket, {required this.kept});

  @override
  final Ticket ticket;
  final bool kept;
}

/// A new file was written into its folder, as [file].
final class NewWritten extends ShownEvent {
  const NewWritten(this.file);

  final ListedFile file;
}
