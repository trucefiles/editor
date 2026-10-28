import '../storage/rel_path.dart';
import 'folder_changes.dart';

/// Changes to the files of one base folder as they happen, where the place
/// can tell them live: the bottom of a base folder's changes, which the
/// bounded layer narrows to what the app may see.
///
/// One implementation per kind of place, e.g. the platform's file watcher
/// for a folder on this device.
abstract interface class LiveChanges {
  /// Hints that files below [folder] (the whole base folder if `null`)
  /// changed, with paths relative to the base folder. Gives every file it
  /// hears of; narrowing is the caller's.
  ///
  /// Starts when listened to and stops when cancelled. Ends when the
  /// changes can no longer be followed, e.g. the folder is gone; never
  /// emits errors.
  Stream<ChangeHint> below(RelPath? folder);
}
