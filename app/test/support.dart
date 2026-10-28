import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_drafts.dart';
import 'package:truce_editor/file_types/document_types.dart';
import 'package:truce_editor/folders/base_folder.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/platform/platform_facts.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/sync_tool/base_folder_services.dart';
import 'package:truce_editor/sync_tool/syncthing/syncthing_wiring.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_controller.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';
import 'package:truce_test_support/truce_test_support.dart' show path;

export 'package:truce_test_support/truce_test_support.dart'
    show ResultUnwrap, WriteCreatingFolders, bytesOf, path;

/// The zooms `main` loads from [storage], once [zooms] are saved there.
/// In a widget test, call it inside `runAsync`: it reads real files.
Future<SavedTextZooms> savedTextZoomsIn(
  AppStorage storage, [
  Map<TextZoomTarget, TextZoom> zooms = const {},
]) async {
  for (final MapEntry(key: target, value: zoom) in zooms.entries) {
    await textZoomStoreIn(storage, target).save(zoom);
  }
  return SavedTextZooms.load(storage);
}

/// Waits until [holds], for work whose end the test cannot see (files
/// written after a timer); fails once [timeout] has passed. Fixed waits
/// fail on a busy machine.
Future<void> eventually(
  FutureOr<bool> Function() holds, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!await holds()) {
    if (DateTime.now().isAfter(end)) fail('Not reached within $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// A fresh temp folder, deleted after the test.
Directory tempFolder() {
  final dir = Directory.systemTemp.createTempSync('truce_test');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// A folder showing [selection] of the base folder at [dir], synced by
/// Syncthing; the base folder's id is [baseId], by default [id].
DocumentFolder folderAt(
  Directory dir, {
  String id = 'f1',
  String? baseId,
  Selection selection = const WholeFolder(),
}) => DocumentFolder(
  id: id,
  base: BaseFolder(id: baseId ?? id, path: dir.path, toolId: syncthingTool.id),
  selection: selection,
  name: 'Documents',
  color: const Color(0xFF009688),
);

/// The document types the app handles.
DocumentTypes appDocumentTypes() {
  final container = ProviderContainer();
  try {
    return container.read(documentTypesProvider);
  } finally {
    container.dispose();
  }
}

/// A document held in memory, never read from a file.
Document documentOf(
  DocumentFolder folder,
  String text, {
  String name = 'a.md',
  int version = 0,
  DateTime? modified,
}) => Document(
  folder: folder,
  path: path(name),
  type: appDocumentTypes().of(path(name))!,
  file: const TextFile.empty().withText(text),
  version: FileVersion(version),
  modified: modified ?? DateTime(2000),
);

/// Services for [folder]'s base folder, bounded to [folder], with backups
/// at [backupsPath], by default in their own temp folder.
BaseFolderServices servicesFor(DocumentFolder folder, {String? backupsPath}) {
  final platform = hostFacts();
  final files = LocalFileStore(
    folder.base.path,
    syncthingTool.rules.tempFileName,
    replacesInPlace: platform.replacesInPlace,
  );
  return baseFolderServices(
    folder.base,
    tool: syncthingTool,
    files: files,
    reach: folderReach(files),
    selection: folder.selection,
    types: appDocumentTypes(),
    platform: platform,
    backupsPath: backupsPath ?? tempFolder().path,
    deviceId: '0123456789abcdef',
  );
}

/// The facts of the platform the tests run on.
PlatformFacts hostFacts() =>
    ProviderContainer.test().read(platformFactsProvider);

/// Drafts in their own temp folder.
DocumentDrafts tempDrafts() => DocumentDrafts(tempFolder());

/// A scan of [folders] (by default those of [documents] and [failed])
/// that starts now and finds [documents]; it could not read the files of
/// [unread], the subfolders [unreadable] or the folders [failed].
FolderScans scanFinding(
  List<Document> documents, {
  List<DocumentFolder>? folders,
  Set<DocumentKey> unread = const {},
  Map<String, List<RelPath>> unreadable = const {},
  Map<DocumentFolder, StoreError> failed = const {},
}) => FolderScans(
  folders:
      folders ??
      {
        for (final document in documents) document.folder,
        ...failed.keys,
      }.toList(),
  documents: documents,
  marks: const {},
  subfolders: const {},
  conflicts: FolderConflicts(const []),
  failedFolders: failed,
  unreadable: unreadable,
  startedAt: Moment.now(),
  unreadNotes: unread,
);
