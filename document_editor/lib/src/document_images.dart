import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import 'ui/document_image.dart';

/// The images the document at [document] in the base folder [baseId]
/// shows, for the open of it at [openedAt]: a web image from its url, and
/// an image in its base folder by its link relative to the document, read
/// through [files]. Any other image (another scheme, outside what the
/// folders show) doesn't show. Equal for the same base folder, folder of
/// the document and open: they find the same images.
@immutable
final class FolderImages implements DocumentImages {
  const FolderImages(
    this.files, {
    required this.baseId,
    required this.document,
    required this.openedAt,
  });

  final DocumentFiles files;
  final String baseId;
  final RelPath document;

  /// When the document was opened: a picture changed on disk shows anew
  /// at the next open.
  final DateTime openedAt;

  @override
  ImageProvider? of(String url) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') return NetworkImage(url);
    return switch (document.linked(url)) {
      final path? => FolderImage(
        baseId,
        path,
        files.bytesOf,
        openedAt: openedAt,
      ),
      null => null,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is FolderImages &&
      other.baseId == baseId &&
      other.document.parent == document.parent &&
      other.openedAt == openedAt;

  @override
  int get hashCode => Object.hash(baseId, document.parent, openedAt);
}

/// The image in the file at [path] of the base folder [baseId], whose bytes
/// [read] gives, for the open of its document at [openedAt]. Equal to
/// another of the same file and open, so the image cache decodes it once
/// per open.
@immutable
final class FolderImage extends ImageProvider<FolderImage> {
  const FolderImage(
    this.baseId,
    this.path,
    this.read, {
    required this.openedAt,
  });

  final String baseId;
  final RelPath path;
  final Future<Uint8List?> Function(RelPath path) read;
  final DateTime openedAt;

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
      other is FolderImage &&
      other.baseId == baseId &&
      other.path == path &&
      other.openedAt == openedAt;

  @override
  int get hashCode => Object.hash(baseId, path, openedAt);
}
