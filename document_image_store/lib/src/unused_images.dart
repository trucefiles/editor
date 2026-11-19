import 'dart:convert';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'document_image_store.dart';
import 'image_names.dart';

/// Why no unused images were looked for.
enum CleanupRefused {
  /// A document, conflict copy, subfolder or draft couldn't be read, so
  /// an image it shows could look unused.
  notAllRead,

  /// The store couldn't be listed, e.g. the folder can't be reached.
  storeUnreadable,
}

/// The user's cleanup of one folder's unused document images: those no
/// document, conflict copy or draft of the folder names. Every one of
/// them is read first; images changed in the last [fresh] stay, as their
/// document may not hold its link yet (here or on another device).
/// Open documents are secured by the caller first, so their edits are
/// in a file or a draft.
final class UnusedImages {
  UnusedImages(
    this._store,
    this._services, {
    required this._drafts,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How long a new image is left alone.
  static const fresh = Duration(hours: 1);

  final DocumentImageStore _store;
  final FolderServices _services;

  /// The folder's drafts on this device, as written; `null` if one can't
  /// be read.
  final Future<List<String>?> Function() _drafts;
  final DateTime Function() _now;

  /// The images that would go, oldest first.
  Future<Result<List<FileEntry>, CleanupRefused>> find() async {
    final Map<String, FileEntry> images;
    switch (await _store.images()) {
      case Ok(:final value):
        images = value;
      case Err():
        return const Err(CleanupRefused.storeUnreadable);
    }
    if (images.isEmpty) return const Ok([]);
    final texts = await _texts();
    if (texts == null) return const Err(CleanupRefused.notAllRead);
    final used = {for (final text in texts) ...ImageNames.namesIn(text)};
    final before = _now().subtract(fresh);
    return Ok(
      images.entries
          .where((image) => !used.contains(image.key))
          .map((image) => image.value)
          .where((entry) => entry.modified.isBefore(before))
          .toList()
        ..sort((a, b) => a.modified.compareTo(b.modified)),
    );
  }

  /// Removes [images], as [find] gave them, each after a backup; how many
  /// went. One that changed meanwhile, or can't be backed up, stays.
  Future<int> remove(List<FileEntry> images) async {
    var removed = 0;
    for (final image in images) {
      if (await _store.remove(image) is Ok) removed++;
    }
    return removed;
  }

  /// The text of every document, conflict copy and draft of the folder;
  /// `null` if any can't be read.
  Future<List<String>?> _texts() async {
    final FolderScan scan;
    switch (await _services.scanner.scan()) {
      case Ok(:final value) when value.unreadable.isEmpty:
        scan = value;
      case Ok() || Err():
        return null;
    }
    final drafts = await _drafts();
    if (drafts == null) return null;
    final texts = [...drafts];
    for (final file in scan.files) {
      switch (await _services.store.read(file.path)) {
        case Ok(:final value):
          texts.add(_asText(value.bytes));
        case Err():
          return null;
      }
    }
    for (final copy in scan.conflicts.expand((conflict) => conflict.copies)) {
      switch (await _services.conflicts.readCopy(copy)) {
        case Ok(:final value):
          texts.add(_asText(value));
        case Err():
          return null;
      }
    }
    return texts;
  }

  /// Names are plain ASCII, so any text encoding finds them.
  static String _asText(List<int> bytes) =>
      utf8.decode(bytes, allowMalformed: true);
}
