import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:truce_core/truce_core.dart';

import '../editor/ui/document_image.dart';
import '../folders/document_folder.dart';
import 'document_files.dart';

/// The images the document at [document] in [folder] shows: a web image from its
/// url, and an image in its base folder by its link relative to the document,
/// read through [files]. Any other image (another scheme, outside what the
/// folders show) doesn't show.
DocumentImages documentImages(
  DocumentFiles files, {
  required DocumentFolder folder,
  required RelPath document,
}) => (url) {
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https') return NetworkImage(url);
  return switch (document.linked(url)) {
    final path? => FolderImage(folder.base.id, path, files.bytesOf),
    null => null,
  };
};

/// The image in the file at [path] of the base folder [baseId], whose bytes
/// [read] gives. Equal to another of the same file, so the image cache
/// decodes it once.
@immutable
final class FolderImage extends ImageProvider<FolderImage> {
  const FolderImage(this.baseId, this.path, this.read);

  final String baseId;
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
      other is FolderImage && other.baseId == baseId && other.path == path;

  @override
  int get hashCode => Object.hash(baseId, path);
}
