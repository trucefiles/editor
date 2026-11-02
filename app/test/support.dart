import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/file_types/editable_type.dart';
import 'package:truce_editor/file_types/file_types.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/sync_tool/syncthing/syncthing_wiring.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart'
    show path, tempFolder;

export 'package:truce_test_support/truce_test_support.dart'
    show ResultUnwrap, WriteCreatingFolders, bytesOf, path, tempFolder;

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

/// A folder showing [selection] of the base folder at [dir], synced by
/// Syncthing; the base folder's id is [baseId], by default [id].
Folder folderAt(
  Directory dir, {
  String id = 'f1',
  String? baseId,
  Selection selection = const WholeFolder(),
}) => Folder(
  id: id,
  base: BaseFolder(
    id: baseId ?? id,
    address: Uri.file(dir.path),
    toolId: hostSyncthing().id,
  ),
  selection: selection,
  name: 'Documents',
  color: 'teal',
);

/// The file types the app handles.
ShownFileTypes<EditableType> appFileTypes() {
  final container = ProviderContainer();
  try {
    return container.read(fileTypesProvider);
  } finally {
    container.dispose();
  }
}

/// A file as listed, of no file on disk.
ListedFile listedFile(
  Folder folder, {
  String name = 'a.md',
  int version = 0,
  DateTime? modified,
}) => ListedFile(
  folder: folder,
  path: path(name),
  type: appFileTypes().of(path(name))!.support,
  version: FileVersion(version),
  modified: modified ?? DateTime(2000),
);

/// A file as if read, holding [text]; never read from a file.
FileText fileTextOf(
  Folder folder,
  String text, {
  String name = 'a.md',
  int version = 0,
  DateTime? modified,
}) => FileText(
  listedFile(folder, name: name, version: version, modified: modified),
  const TextFile.empty().withText(text),
);

/// Services for [folder]'s base folder, bounded to [folder], with backups
/// at [backupsPath], by default in their own temp folder.
/// [wrote] hears the paths of each write that landed.
BaseFolderServices servicesFor(
  Folder folder, {
  String? backupsPath,
  void Function(Set<RelPath> paths)? wrote,
}) {
  final tool = hostSyncthing();
  final place = tool.place(folder.base.address);
  return baseFolderServices(
    place,
    syncToolName: tool.name,
    reach: folderReach(place.files),
    selection: folder.selection,
    handles: appFileTypes().handles,
    checkEvery: () => const Duration(seconds: 1),
    backupsPath: backupsPath ?? tempFolder().path,
    deviceId: '0123456789abcdef',
    wrote: wrote ?? (_) {},
  );
}

/// The shared parts of folders on this device, as the platform the tests
/// run on has them.
LocalDisk hostDisk() {
  final container = ProviderContainer();
  try {
    return container.read(localDiskProvider);
  } finally {
    container.dispose();
  }
}

/// Syncthing as the app registers it, for folders on this device.
SyncTool hostSyncthing() => syncthingTool(hostDisk());

/// Drafts in their own temp folder.
FileDrafts tempDrafts() => FileDrafts(tempFolder());

/// What the folders hold, listed now (or [listedAt]) with [files]:
/// [folders] (by default those of [files] and [failed]); the base
/// folders of [failed] could not be listed, and the subfolders
/// [unreadable] (by base folder id) could not be read.
FolderContents contentsFinding(
  List<ListedFile> files, {
  List<Folder>? folders,
  Map<String, List<RelPath>> unreadable = const {},
  Map<Folder, StoreError> failed = const {},
  Moment? listedAt,
}) {
  final shown =
      folders ??
      {for (final file in files) file.folder, ...failed.keys}.toList();
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
              for (final file in files)
                if (file.folder.base == base)
                  file.path: FileEntry(
                    file.path,
                    version: file.version,
                    modified: file.modified,
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
    types: appFileTypes(),
  );
}
