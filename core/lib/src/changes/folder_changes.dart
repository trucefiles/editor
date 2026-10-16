import '../storage/rel_path.dart';

/// Changes to the files in one folder, made by anyone: the sync tool,
/// other apps or this app.
///
/// How they are found (events from the platform, comparing listings now
/// and then, a sync tool's API) is up to each implementation, and so is
/// how it keeps to the files it is told to follow: skipping folders where
/// it can, else dropping the changes of other files.
abstract interface class FolderChanges {
  /// The paths of followed files that were created, changed or deleted,
  /// relative to the folder. A path may come more than once for one
  /// change.
  ///
  /// Starts finding changes when listened to and stops when cancelled;
  /// each listen starts anew. Ends when changes can no longer be followed,
  /// e.g. the folder is gone; never emits errors.
  Stream<RelPath> get changes;
}
