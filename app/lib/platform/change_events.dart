import 'dart:io';

import 'linux/document_portal.dart';

/// Whether this platform tells the app about changes other apps make to
/// files as they happen, through `package:watcher`'s native watchers.
///
/// Only where the library has one (Linux, macOS, Windows); elsewhere, as
/// on Android, it only polls.
bool get platformReportsChanges =>
    FileSystemEntity.isWatchSupported &&
    (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

/// Whether the app hears about changes to the folder at [folderPath] as
/// they happen.
///
/// Not for a folder from the Flatpak document portal: the portal passes on
/// no change events for changes made outside the sandbox.
bool reportsChanges(String folderPath) =>
    platformReportsChanges && !isInDocumentPortal(folderPath);
