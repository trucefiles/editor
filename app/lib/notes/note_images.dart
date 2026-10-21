import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:truce_core/truce_core.dart';

import '../editor/ui/note_image.dart';
import '../folders/note_folder.dart';
import 'note_files.dart';

/// The images the note at [note] in [folder] shows: a web image from its
/// url, and an image in the folder by its link relative to the note, read
/// through [files]. Any other image (another scheme, outside the folder)
/// doesn't show.
NoteImages noteImages(
  NoteFiles files, {
  required NoteFolder folder,
  required RelPath note,
}) => (url) {
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') return NetworkImage(url);
  return switch (note.linked(url)) {
    final path? => FolderImage(folder.id, path, files.bytesOf),
    null => null,
  };
};

/// The image in the file at [path] of the folder [folder], whose bytes
/// [read] gives. Equal to another of the same file, so the image cache
/// decodes it once.
@immutable
final class FolderImage extends ImageProvider<FolderImage> {
  const FolderImage(this.folder, this.path, this.read);

  final String folder;
  final RelPath path;
  final Future<Uint8List?> Function(RelPath path) read;

  @override
  Future<FolderImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    FolderImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _codec(decode),
    scale: 1,
    debugLabel: path.value,
  );

  Future<Codec> _codec(ImageDecoderCallback decode) async {
    final bytes = await read(path);
    if (bytes == null) throw StateError('Image ${path.value} unreadable');
    return decode(await ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is FolderImage && other.folder == folder && other.path == path;

  @override
  int get hashCode => Object.hash(folder, path);
}
