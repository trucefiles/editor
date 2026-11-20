import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

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
/// document, conflict copy of one or draft of one in the folder links,
/// as read. Every one of them is read first; images that changed or came here in the last
/// [fresh] stay, as their document may not hold its link yet (here or
/// on another device).
/// Open documents are secured by the caller first, so their edits are
/// in a file or a draft.
final class UnusedImages {
  UnusedImages(
    this._store,
    this._services, {
    required this._drafts,
    required this._isDocument,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How long a new image is left alone.
  static const fresh = Duration(hours: 1);

  final DocumentImageStore _store;
  final FolderServices _services;

  /// The folder's drafts on this device; `null` if one can't be read.
  final Future<List<FileDraft>?> Function() _drafts;
  final DateTime Function() _now;

  /// Whether a file is a Markdown document, by the app's file types.
  final bool Function(RelPath path) _isDocument;

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
    final used = await _usedNames();
    if (used == null) return const Err(CleanupRefused.notAllRead);
    final before = _now().subtract(fresh);
    return Ok(
      images.entries
          .where((image) => !used.contains(image.key))
          .map((image) => image.value)
          .where((entry) => entry.arrived.isBefore(before))
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

  /// The image names every document of the folder, conflict copy of one
  /// and draft of one links, each read in turn and not kept; `null` if
  /// any can't be read.
  Future<Set<String>?> _usedNames() async {
    final FolderScan scan;
    switch (await _services.scanner.scan()) {
      case Ok(:final value) when value.unreadable.isEmpty:
        scan = value;
      case Ok() || Err():
        return null;
    }
    final drafts = await _drafts();
    if (drafts == null) return null;
    final used = {
      for (final draft in drafts)
        if (_isDocument(draft.path)) ...ImageNames.linkedBy(draft.text),
    };
    for (final file in scan.files.where((f) => _isDocument(f.path))) {
      switch (await _services.store.read(file.path)) {
        case Ok(:final value):
          used.addAll(_linkedBy(value.bytes));
        case Err():
          return null;
      }
    }
    final copies = scan.conflicts
        .where((conflict) => _isDocument(conflict.mainPath))
        .expand((conflict) => conflict.copies);
    for (final copy in copies) {
      switch (await _services.conflicts.readCopy(copy)) {
        case Ok(:final value):
          used.addAll(_linkedBy(value));
        case Err():
          return null;
      }
    }
    return used;
  }

  /// The names the document [bytes] links; as shown if they aren't
  /// UTF-8, so no image of a broken file is taken for unused.
  static Set<String> _linkedBy(Uint8List bytes) =>
      ImageNames.linkedBy(TextFile.textToShow(bytes));
}
