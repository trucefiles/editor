import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart' show Relink;
import 'package:truce_folders/truce_folders.dart';

import 'image_names.dart';

/// One folder's document images, in its `document-images` folder (see
/// [ImageNames]), reached through the folder's files kept apart; removed
/// ones are backed up first, like a deleted file.
final class DocumentImageStore {
  DocumentImageStore(this._services, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final FolderServices _services;
  final DateTime Function() _now;

  FileStore get _files => _services.apart;

  /// Keeps [bytes], an image with [extension] (without its dot), under a
  /// new name: the link to it from a document in [documentFolder]
  /// (`null`: the top level). Fails if the folder can't be written, e.g.
  /// it can't be reached.
  Future<Result<String, StoreError>> add(
    Uint8List bytes, {
    required String extension,
    required RelPath? documentFolder,
  }) async {
    final name = ImageNames.newName(extension);
    return switch (await _files.create(ImageNames.pathOf(name), bytes)) {
      Ok() => Ok(ImageNames.linkFrom(documentFolder, name)),
      // 64 random bits: a taken name is as good as never; a new one then.
      Err(error: StoreError.alreadyExists) => add(
        bytes,
        extension: extension,
        documentFolder: documentFolder,
      ),
      Err(:final error) => Err(error),
    };
  }

  /// The images kept, by name; none before the first.
  Future<Result<Map<String, FileEntry>, StoreError>> images() async {
    final listed = await _files.list(
      enterFolder: (folder) => folder == ImageNames.folder,
      includeFile: (file) => file.parent == ImageNames.folder,
    );
    return switch (listed) {
      Ok(value: final listing) => Ok({
        for (final entry in listing.files)
          if (ImageNames.nameIn(entry.path.name) != null)
            entry.path.name: entry,
      }),
      Err(:final error) => Err(error),
    };
  }

  /// How the links of ours in a text change so each leads to its image
  /// from a document in [documentFolder] (`null`: the top level): only
  /// links whose name is ours and whose image is here.
  Future<Result<Relink, StoreError>> relinkFrom(
    RelPath? documentFolder,
  ) async => (await images()).map(
    (images) =>
        (destination) => switch (ImageNames.nameIn(destination)) {
          final name? when images.containsKey(name) =>
            switch (ImageNames.linkFrom(documentFolder, name)) {
              final link when link != destination => link,
              _ => null,
            },
          _ => null,
        },
  );

  /// Copies the images [names] that are here into [into], keeping their
  /// names; one there already is done, one not here is skipped. Stops at
  /// the first that can't be copied.
  Future<Result<void, StoreError>> copyInto(
    DocumentImageStore into,
    Set<String> names,
  ) async {
    for (final name in names) {
      final path = ImageNames.pathOf(name);
      final Uint8List bytes;
      switch (await _files.read(path)) {
        case Ok(:final value):
          bytes = value.bytes;
        case Err(error: StoreError.notFound):
          continue;
        case Err(:final error):
          return Err(error);
      }
      switch (await into._files.create(path, bytes)) {
        case Ok() || Err(error: StoreError.alreadyExists):
          break;
        case Err(:final error):
          return Err(error);
      }
    }
    return const Ok(null);
  }

  /// Removes [image], one of [images], after a backup of it, as a
  /// deleted file: it can be brought back from it ([bringBack]). Refused
  /// without the backup, or if it changed since it was listed.
  Future<Result<void, StoreError>> remove(FileEntry image) async {
    final Uint8List bytes;
    switch (await _files.read(image.path)) {
      case Ok(:final value) when value.version == image.version:
        bytes = value.bytes;
      case Ok():
        return const Err(StoreError.changedSinceRead);
      case Err(:final error):
        return Err(error);
    }
    final backedUp = await _services.backups.saveBeforeDelete(
      at: _now(),
      filePath: image.path,
      bytes: bytes,
    );
    if (backedUp is Err) return backedUp;
    return _files.delete(image.path, ifUnchanged: image.version);
  }

  /// Brings the images [names] that are missing back from their latest
  /// backups, never over an image. Best effort: one that can't come
  /// back stays missing.
  Future<void> bringBack(Set<String> names) async {
    if (names.isEmpty) return;
    final Map<String, FileEntry> here;
    switch (await images()) {
      case Ok(:final value):
        here = value;
      case Err():
        return;
    }
    for (final name in names.where((name) => !here.containsKey(name))) {
      await _bringBackOne(ImageNames.pathOf(name));
    }
  }

  Future<void> _bringBackOne(RelPath path) async {
    final backups = _services.backups;
    final latest = switch (await backups.listOf(path)) {
      Ok(:final value) => value.firstOrNull,
      Err() => null,
    };
    if (latest == null) return;
    if (await backups.read(latest) case Ok(:final value)) {
      await _files.create(path, value);
    }
  }
}
