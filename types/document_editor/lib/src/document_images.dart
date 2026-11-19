import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:truce_core/truce_core.dart';

import 'ui/document_image.dart';

/// The images the document at [document] in [folder] shows, for the
/// open of it at [openedAt]: a web image from its url, and an image in
/// its folder, read by [bytesOf]: one the app keeps where [keptAt] says
/// first, wherever its link points, else by its link relative to the
/// document. Any other image (another scheme, outside the folder)
/// doesn't show. Equal for the same folder, folder of the document and
/// open: they find the same images ([keptAt] is one rule by name).
@immutable
final class FolderImages implements DocumentImageLookup {
  const FolderImages(
    this.bytesOf, {
    required this.folder,
    required this.document,
    required this.openedAt,
    this.keptAt = _keptNowhere,
  });

  final Future<Uint8List?> Function(RelPath path) bytesOf;
  final FolderId folder;
  final RelPath document;
  final RelPath? Function(String link) keptAt;

  static RelPath? _keptNowhere(String link) => null;

  /// When the document was opened: a picture changed on disk shows anew
  /// at the next open.
  final DateTime openedAt;

  @override
  ImageProvider? of(String url) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') return NetworkImage(url);
    final paths = {?keptAt(url), ?document.linked(url)}.toList();
    return paths.isEmpty
        ? null
        : FolderImage(folder, paths, bytesOf, openedAt: openedAt);
  }

  @override
  bool operator ==(Object other) =>
      other is FolderImages &&
      other.folder == folder &&
      other.document.parent == document.parent &&
      other.openedAt == openedAt;

  @override
  int get hashCode => Object.hash(folder, document.parent, openedAt);
}

/// The image in the first file of [paths] in [folder] that [read]
/// gives, for the open of its document at [openedAt]. Equal to another
/// of the same files and open, so the image cache decodes it once per
/// open.
@immutable
final class FolderImage extends ImageProvider<FolderImage> {
  const FolderImage(
    this.folder,
    this.paths,
    this.read, {
    required this.openedAt,
  });

  final FolderId folder;
  final List<RelPath> paths;
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
    debugLabel: paths.first.value,
  );

  Future<Codec> _codec(ImageDecoderCallback decode) async {
    for (final path in paths) {
      if (await read(path) case final bytes?) {
        return decode(await ImmutableBuffer.fromUint8List(bytes));
      }
    }
    throw StateError('Image ${paths.first.value} unreadable');
  }

  @override
  bool operator ==(Object other) =>
      other is FolderImage &&
      other.folder == folder &&
      const ListEquality<RelPath>().equals(other.paths, paths) &&
      other.openedAt == openedAt;

  @override
  int get hashCode =>
      Object.hash(folder, const ListEquality<RelPath>().hash(paths), openedAt);
}
