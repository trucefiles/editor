import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/platform/platform_facts.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';
import 'package:truce_editor/sync_tool/syncthing/syncthing_wiring.dart';
import 'package:truce_test_support/truce_test_support.dart' show path;

export 'package:truce_test_support/truce_test_support.dart'
    show ResultUnwrap, WriteCreatingFolders, bytesOf, path;

/// A fresh temp folder, deleted after the test.
Directory tempFolder() {
  final dir = Directory.systemTemp.createTempSync('truce_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

NoteFolder folderAt(Directory dir, {String id = 'f1'}) => NoteFolder(
  id: id,
  path: dir.path,
  name: 'Notes',
  color: const Color(0xFF009688),
);

/// A note held in memory, never read from a file.
Note noteOf(
  NoteFolder folder,
  String text, {
  String name = 'a.md',
  int version = 0,
  DateTime? modified,
}) => Note(
  folder: folder,
  path: path(name),
  file: const TextFile.empty().withText(text),
  version: FileVersion(version),
  modified: modified ?? DateTime(2000),
);

/// Services for [folder], with backups in their own temp folder.
FolderServices servicesFor(NoteFolder folder) => syncthingFolderServices(
  folder.path,
  backupsPath: tempFolder().path,
  deviceId: '0123456789abcdef',
  platform: hostFacts(),
);

/// The facts of the platform the tests run on.
PlatformFacts hostFacts() =>
    ProviderContainer.test().read(platformFactsProvider);

/// Drafts in their own temp folder.
NoteDrafts tempDrafts() => NoteDrafts(tempFolder());

extension RescanNow on NoteEditSession {
  /// Hands the session a rescan that starts now; see [onRescan].
  bool rescanNow(Note? latest) => onRescan(latest, scannedAt: Moment.now());
}
