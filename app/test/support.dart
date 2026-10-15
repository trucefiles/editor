import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_services.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note_drafts.dart';

RelPath path(String raw) => RelPath.parse(raw)!;

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

/// Services for [folder], with backups in their own temp folder.
FolderServices servicesFor(NoteFolder folder) => FolderServices.syncthing(
  folder.path,
  backupsPath: tempFolder().path,
  deviceId: '0123456789abcdef',
);

/// Drafts in their own temp folder.
NoteDrafts tempDrafts() => NoteDrafts(tempFolder());

/// Unwraps results in tests; a wrong variant fails with a cast error.
extension ResultUnwrap<T, E> on Result<T, E> {
  T get value => (this as Ok<T, E>).value;
  E get error => (this as Err<T, E>).error;
}
