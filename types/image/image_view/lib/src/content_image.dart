import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:truce_file_page/truce_file_page.dart';

/// The picture [content] holds, read when first shown; kept in Flutter's
/// image cache by its id, so another version is read anew. A failed
/// read is not kept, so it is tried again when it shows again.
@immutable
final class ContentImage extends ImageProvider<ContentImage> {
  const ContentImage(this.content);

  final ShownContent content;

  @override
  Future<ContentImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    ContentImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await content.read();
    if (bytes == null) throw StateError('The picture could not be read.');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is ContentImage && other.content.id == content.id;

  @override
  int get hashCode => content.id.hashCode;
}
