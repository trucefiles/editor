import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
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
  SizedImage? of(String url) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      return (size) => ResizeImage(
        NetworkImage(url),
        width: size.width,
        height: size.height,
        policy: ResizeImagePolicy.fit,
        allowUpscaling: false,
      );
    }
    final paths = {?keptAt(url), ?document.linked(url)}.toList();
    return paths.isEmpty
        ? null
        : (size) => FolderImage(
            folder,
            paths,
            bytesOf,
            openedAt: openedAt,
            size: size,
          );
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
/// gives, for the open of its document at [openedAt], decoded at [size]
/// (see [BytesImage]). Equal to another of the same files, open and size,
/// so the image cache decodes it once per open.
@immutable
final class FolderImage extends BytesImage<FolderImage> {
  const FolderImage(
    this.folder,
    this.paths,
    this.read, {
    required this.openedAt,
    super.size,
  });

  final FolderId folder;
  final List<RelPath> paths;
  final Future<Uint8List?> Function(RelPath path) read;
  final DateTime openedAt;

  @override
  Future<Uint8List?> readBytes() async {
    for (final path in paths) {
      if (await read(path) case final bytes?) return bytes;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is FolderImage &&
      other.folder == folder &&
      const ListEquality<RelPath>().equals(other.paths, paths) &&
      other.openedAt == openedAt &&
      other.size == size;

  @override
  int get hashCode => Object.hash(
    folder,
    const ListEquality<RelPath>().hash(paths),
    openedAt,
    size,
  );
}
