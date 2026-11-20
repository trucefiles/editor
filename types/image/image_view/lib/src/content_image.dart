import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:truce_file_page/truce_file_page.dart';

/// The picture [content] holds, read when first shown; kept in Flutter's
/// image cache by its id, so another version is read anew. A failed
/// read is not kept, so it is tried again when it shows again.
@immutable
final class ContentImage extends ImageProvider<ContentImage> {
  /// [cover]: decoded only as large as it takes to cover a box of that
  /// many pixels (never larger than it is), for a picture cut to fill a
  /// box; whole when `null`.
  const ContentImage(this.content, {this.cover});

  final ShownContent content;
  final ({int width, int height})? cover;

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
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return switch (cover) {
      final box? => decode(
        buffer,
        getTargetSize: (width, height) => covering(box, width, height),
      ),
      null => decode(buffer),
    };
  }

  /// The size a picture of [width] × [height] decodes at to cover [box].
  @visibleForTesting
  static ui.TargetImageSize covering(
    ({int width, int height}) box,
    int width,
    int height,
  ) {
    final scale = math.max(box.width / width, box.height / height);
    if (scale >= 1) return const ui.TargetImageSize();
    return ui.TargetImageSize(
      width: (width * scale).ceil(),
      height: (height * scale).ceil(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ContentImage &&
      other.content.id == content.id &&
      other.cover == cover;

  @override
  int get hashCode => Object.hash(content.id, cover);
}
