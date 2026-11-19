import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_markdown/truce_markdown.dart' show relinkedMarkdown;

import 'document_image_store.dart';
import 'image_names.dart';

/// How a Markdown document arrives at a place ([FileArrival]): the
/// images of ours it links go along into the new place's folder, and its
/// links change so each leads to its image from there. A restored one
/// first brings back its images that were removed meanwhile (best
/// effort). Each folder's images are [_storeOf]'s.
final class MarkdownArrival implements FileArrival {
  const MarkdownArrival(this._storeOf);

  final DocumentImageStore Function(Folder folder) _storeOf;

  @override
  Future<Result<Uint8List?, StoreError>> arrive(Arrival arrival) async {
    final (:bytes, :folder, :from, :to, :restored) = arrival;
    final file = TextFile.decode(bytes);
    if (file == null) return const Ok(null);
    final names = ImageNames.linkedBy(file.text);
    if (names.isEmpty) return const Ok(null);
    final source = _storeOf(folder);
    if (restored) await source.bringBack(names);
    final target = _storeOf(to.folder);
    if (to.folder.id != folder.id) {
      final copied = await source.copyInto(target, names);
      if (copied case Err(:final error)) return Err(error);
    }
    if (ImageNames.linksAlike(from.parent, to.subfolder)) {
      return const Ok(null);
    }
    return (await target.relinkFrom(to.subfolder)).map(
      (relink) => switch (relinkedMarkdown(file.text, relink)) {
        final text? => file.encode(text),
        null => null,
      },
    );
  }
}
