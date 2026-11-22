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
import '../open_file/observation.dart';
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

/// The file's folder was removed from the app: a new file not written
/// yet is kept nowhere now (its draft went with the folder), until the
/// user picks another folder. Touches no disk.
final class NewFolderRemoved extends ShownInput {
  const NewFolderRemoved();
}

// State.

sealed class ShownState {
  const ShownState();
}

/// Which bytes a shown file holds, as its owner knows: equal tags, equal
/// bytes. It stays the same while the bytes do, wherever the file goes
/// (e.g. after the owner's own rename or move, or once it writes a new
/// file), so what was drawn of it is drawn again. Opaque.
@immutable
final class ContentTag {
  /// The bytes of [file] as listed: of its version stamp, so a file
  /// opened again gets the same tag.
  ContentTag.listed(ListedFile file) : _token = versionStampOf(file);

  /// Bytes no other tag names (e.g. of a new file).
  ContentTag.unique() : _token = Object();

  final Object _token;

  @override
  bool operator ==(Object other) =>
      other is ContentTag && other._token == _token;

  @override
  int get hashCode => _token.hashCode;
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
/// waits, [content] tags its bytes.
@immutable
final class WaitingNew extends ShownState {
  const WaitingNew(this.file, {required this.kept, required this.content});

  final NewShownFile file;
  final NewKept kept;
  final ContentTag content;

  @override
  bool operator ==(Object other) =>
      other is WaitingNew &&
      identical(other.file, file) &&
      other.kept == kept &&
      other.content == content;

  @override
  int get hashCode => Object.hash(identityHashCode(file), kept, content);
}

/// The file, as listed now, holding [content].
@immutable
final class ShownListed extends ShownState {
  const ShownListed(this.file, {required this.content});

  final ListedFile file;
  final ContentTag content;

  @override
  bool operator ==(Object other) =>
      other is ShownListed && other.file == file && other.content == content;

  @override
  int get hashCode => Object.hash(file, content);
}

/// The file is gone: deleted, moved or renamed elsewhere; [last] is how
/// it was last listed, holding [content]. It is never written again by
/// itself.
@immutable
final class ShownGone extends ShownState {
  const ShownGone(this.last, {required this.content});

  final ListedFile last;
  final ContentTag content;

  @override
  bool operator ==(Object other) =>
      other is ShownGone && other.last == last && other.content == content;

  @override
  int get hashCode => Object.hash(last, content);
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
  const Secured(this.ticket, {required this.kept, required this.onDevice});

  @override
  final Ticket ticket;
  final bool kept;

  /// Whether a new file waits on this device as a draft.
  final bool onDevice;
}

/// A new file was written into its folder, as [file].
final class NewWritten extends ShownEvent {
  const NewWritten(this.file);

  final ListedFile file;
}
