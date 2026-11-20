import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_markdown/truce_markdown.dart' show relinkedMarkdown;
import 'package:truce_text_editing/truce_text_editing.dart';

import 'document_image_store.dart';
import 'image_names.dart';
import 'images_follow.dart';

/// How a Markdown document arrives at a place ([FileArrival]): its
/// images follow it ([imagesFollow]), its links changed in the bytes
/// written. A restored one first brings back its images that were
/// removed meanwhile (best effort). Each folder's images are
/// [_storeOf]'s.
final class MarkdownArrival implements FileArrival {
  const MarkdownArrival(this._storeOf);

  final DocumentImageStore Function(FolderId folder) _storeOf;

  @override
  Future<Result<Uint8List?, StoreError>> arrive(Arrival arrival) async {
    final (:bytes, :folder, :from, :to, :by) = arrival;
    final file = TextFile.decode(bytes);
    if (file == null) return const Ok(null);
    final names = ImageNames.linkedBy(file.text);
    if (by == ArrivalBy.restore) await _storeOf(folder.id).bringBack(names);
    final relink = await imagesFollow(
      names,
      from: (folder: folder.id, documentFolder: from.parent),
      to: (folder: to.folder.id, documentFolder: to.subfolder),
      storeOf: _storeOf,
    );
    return relink.map(
      (relink) => switch (relink) {
        final relink? => switch (relinkedMarkdown(file.text, relink)) {
          final text? => file.encode(text),
          null => null,
        },
        null => null,
      },
    );
  }
}
