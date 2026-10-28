import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_drafts.dart';
import 'package:truce_editor/documents/document_text.dart';
import 'package:truce_editor/file_types/document_types.dart';
import 'package:truce_editor/folder_state/folder_contents.dart';
import 'package:truce_editor/folders/base_folder.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/platform/platform_facts.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
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

/// A document as listed, of no file on disk.
Document listedDocument(
  DocumentFolder folder, {
  String name = 'a.md',
  int version = 0,
  DateTime? modified,
}) => Document(
  folder: folder,
  path: path(name),
  type: appDocumentTypes().of(path(name))!,
  version: FileVersion(version),
  modified: modified ?? DateTime(2000),
);

/// A document's file as if read, holding [text]; never read from a file.
DocumentText documentTextOf(
  DocumentFolder folder,
  String text, {
  String name = 'a.md',
  int version = 0,
  DateTime? modified,
}) => DocumentText(
  listedDocument(folder, name: name, version: version, modified: modified),
  const TextFile.empty().withText(text),
);

/// Services for [folder]'s base folder, bounded to [folder], with backups
/// at [backupsPath], by default in their own temp folder.
/// [wrote] hears the paths of each write that landed.
BaseFolderServices servicesFor(
  DocumentFolder folder, {
  String? backupsPath,
  void Function(Set<RelPath> paths)? wrote,
}) {
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
    wrote: wrote ?? (_) {},
  );
}

/// The facts of the platform the tests run on.
PlatformFacts hostFacts() =>
    ProviderContainer.test().read(platformFactsProvider);

/// Drafts in their own temp folder.
DocumentDrafts tempDrafts() => DocumentDrafts(tempFolder());

/// What the folders hold, listed now (or [listedAt]) with [documents]:
/// [folders] (by default those of [documents] and [failed]); the base
/// folders of [failed] could not be listed, and the subfolders
/// [unreadable] (by base folder id) could not be read.
FolderContents contentsFinding(
  List<Document> documents, {
  List<DocumentFolder>? folders,
  Map<String, List<RelPath>> unreadable = const {},
  Map<DocumentFolder, StoreError> failed = const {},
  Moment? listedAt,
}) {
  final shown =
      folders ??
      {
        for (final document in documents) document.folder,
        ...failed.keys,
      }.toList();
  final at = listedAt ?? Moment.now();
  return FolderContents(
    FolderState({
      for (final base in {for (final folder in shown) folder.base})
        base.id: switch ([
          for (final MapEntry(key: folder, value: error) in failed.entries)
            if (folder.base == base) error,
        ]) {
          [final error, ...] => ListingFailed(error),
          [] => Listed(
            files: {
              for (final document in documents)
                if (document.folder.base == base)
                  document.path: FileEntry(
                    document.path,
                    version: document.version,
                    modified: document.modified,
                  ),
            },
            conflicts: const {},
            subfolders: const {},
            unreadable: unreadable[base.id] ?? const [],
            marks: MarksFiles.none,
            listedAt: at,
          ),
        },
    }),
    folders: shown,
    types: appDocumentTypes(),
  );
}
