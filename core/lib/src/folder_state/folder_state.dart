import '../common/moment.dart';
import '../conflicts/conflict.dart';
import '../marks/document_marks.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// What the base folders hold, by base folder id: the folder state
/// owner's state. Holds every base folder it follows.
final class FolderState {
  FolderState(Map<String, BaseState> bases) : bases = Map.unmodifiable(bases);

  static final none = FolderState(const {});

  final Map<String, BaseState> bases;
}

/// What one base folder holds, as far as is known.
sealed class BaseState {
  const BaseState();
}

/// Not listed yet.
final class NotListed extends BaseState {
  const NotListed();
}

/// The last listing failed with [error] (e.g. the folder is out of
/// reach): what it holds is unknown.
final class ListingFailed extends BaseState {
  const ListingFailed(this.error);

  final StoreError error;
}

/// Listed: its files and what is known of them, kept in step with changes.
final class Listed extends BaseState {
  Listed({
    required Map<RelPath, FileEntry> files,
    required Map<RelPath, Conflict> conflicts,
    required Set<RelPath> subfolders,
    required List<RelPath> unreadable,
    required this.marks,
    required this.listedAt,
    Map<RelPath?, Moment> checkedAt = const {},
  }) : files = Map.unmodifiable(files),
       conflicts = Map.unmodifiable(conflicts),
       subfolders = Set.unmodifiable(subfolders),
       unreadable = List.unmodifiable(unreadable),
       checkedAt = Map.unmodifiable(checkedAt);

  /// The files its sync tool shows, by path. A file's time is never one
  /// older than the app's own write of it.
  final Map<RelPath, FileEntry> files;

  /// The pending conflicts, by main file.
  final Map<RelPath, Conflict> conflicts;

  /// Every subfolder, empty ones too.
  final Set<RelPath> subfolders;

  /// Subfolders that could not be read: what is below them is unknown.
  final List<RelPath> unreadable;

  /// The marks files of all devices.
  final MarksFiles marks;

  /// When the last whole listing began.
  final Moment listedAt;

  /// When the last check of a folder since [listedAt] began, by folder
  /// (`null`: the top level).
  final Map<RelPath?, Moment> checkedAt;

  /// When what is known of [path] was seen: the start of the last listing
  /// or check of its folder, so a write that ended later is not in it. A
  /// check looks only directly in a folder, so one of a folder above
  /// tells nothing of [path].
  Moment seenAt(RelPath path) => checkedAt[path.parent] ?? listedAt;

  /// Whether what is at [path] is known: no subfolder above it could not
  /// be read.
  bool sees(RelPath path) =>
      !unreadable.any((folder) => path.isAtOrInside(folder));

  Listed copyWith({
    Map<RelPath, FileEntry>? files,
    Map<RelPath, Conflict>? conflicts,
    Set<RelPath>? subfolders,
    MarksFiles? marks,
    Map<RelPath?, Moment>? checkedAt,
  }) => Listed(
    files: files ?? this.files,
    conflicts: conflicts ?? this.conflicts,
    subfolders: subfolders ?? this.subfolders,
    unreadable: unreadable,
    marks: marks ?? this.marks,
    listedAt: listedAt,
    checkedAt: checkedAt ?? this.checkedAt,
  );
}
