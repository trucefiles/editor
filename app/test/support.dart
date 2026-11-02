import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/file_types/editable_type.dart';
import 'package:truce_editor/file_types/file_types.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/plugins/plugins_wiring.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart'
    show ResultUnwrap, path, tempFolder;

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

/// A Syncthing folder at [dir], with the plugin id [id]. In tests its
/// location is [dir]'s path, so [servicesFor] finds the directory.
Folder folderAt(Directory dir, {String id = 'f1'}) => Folder(
  id: FolderId('syncthing', id),
  name: 'Files',
  color: 'teal',
  location: dir.path,
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

/// Services for [folder], made by [folderAt], with backups at
/// [backupsPath], by default in their own temp folder. [wrote] hears the
/// paths of each write that landed.
FolderServices servicesFor(
  Folder folder, {
  String? backupsPath,
  void Function(Set<RelPath> paths)? wrote,
}) {
  final raw = syncthingFolderAt(Directory(folder.location));
  return folderServices(
    raw,
    pluginName: 'Syncthing',
    reach: folderReach(raw.files),
    handles: appFileTypes().handles,
    checkEvery: () => const Duration(seconds: 1),
    backupsPath: backupsPath ?? tempFolder().path,
    deviceId: '0123456789abcdef',
    wrote: wrote ?? (_) {},
  );
}

/// The directory [dir] as Syncthing's raw folder on this device, its own
/// Syncthing folder.
RawFolder syncthingFolderAt(Directory dir) {
  final disk = hostDisk();
  final address = Uri.directory(dir.path);
  return SyncthingFolder(
    disk.open(address, tempName: SyncthingFolder.rules.tempFileName),
    disk.markersAt(address),
  );
}

/// The local-disk service, as the platform the tests run on has it.
LocalDisk hostDisk() {
  final container = ProviderContainer();
  try {
    return container.read(localDiskProvider);
  } finally {
    container.dispose();
  }
}

/// Drafts in their own temp folder.
FileDrafts tempDrafts() => FileDrafts(tempFolder());

/// What the folders hold, listed now (or [listedAt]) with [files]:
/// [folders] (by default those of [files] and [failed]); those of
/// [failed] could not be listed, and the folders [unreadable] inside
/// them (by folder) could not be read.
FolderContents contentsFinding(
  List<ListedFile> files, {
  List<Folder>? folders,
  Map<FolderId, List<RelPath>> unreadable = const {},
  Map<Folder, StoreError> failed = const {},
  Moment? listedAt,
}) {
  final shown =
      folders ??
      {for (final file in files) file.folder, ...failed.keys}.toList();
  final at = listedAt ?? Moment.now();
  return FolderContents(
    FolderState({
      for (final folder in shown)
        folder.id: switch (failed[folder]) {
          final error? => ListingFailed(error),
          null => Listed(
            files: {
              for (final file in files)
                if (file.folder.id == folder.id)
                  file.path: FileEntry(
                    file.path,
                    version: file.version,
                    modified: file.modified,
                  ),
            },
            conflicts: const {},
            subfolders: const {},
            unreadable: unreadable[folder.id] ?? const [],
            marks: MarksFiles.none,
            listedAt: at,
          ),
        },
    }),
    folders: shown,
    types: appFileTypes(),
  );
}

/// Adds the folder [inside] the directory [root] (all of it if `null`), as
/// a Syncthing folder with [root] as its Syncthing folder, through the
/// folder list of [container]; the folder added.
Future<Folder> addSyncthingFolder(
  ProviderContainer container,
  Directory root, {
  RelPath? inside,
}) async {
  final plugin =
      container.read(folderPluginsProvider).of('syncthing') as SyncthingPlugin;
  final address = Uri.directory(root.path);
  return addFolderOf(
    container,
    plugin,
    plugin.candidate(address, address, inside),
  );
}

/// Adds the folder [candidate] names, of [plugin], through the folder list
/// of [container]; the folder added.
Future<Folder> addFolderOf(
  ProviderContainer container,
  FolderPlugin plugin,
  PluginFolderCandidate candidate,
) async {
  await container.read(foldersProvider.future);
  final added = await container.read(foldersProvider.notifier).add(plugin, [
    (candidate: candidate, name: 'Files', color: 'teal'),
  ]);
  return added.value.single;
}
