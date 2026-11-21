import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How large a picture is decoded, in pixels: as large as its use needs,
/// never larger than the picture is, so a huge one never fills memory.
sealed class DecodeSize {
  const DecodeSize(this.width, this.height);

  /// The most pixels any shown picture is decoded at on a side (a square
  /// of it takes 64 MB).
  static const largestSide = 4096;

  final int width;
  final int height;

  /// The size a picture of [pictureWidth] × [pictureHeight] decodes at.
  ui.TargetImageSize targetFor(int pictureWidth, int pictureHeight) {
    final scale = _scale(pictureWidth, pictureHeight);
    if (scale >= 1) return const ui.TargetImageSize();
    return ui.TargetImageSize(
      width: (pictureWidth * scale).ceil(),
      height: (pictureHeight * scale).ceil(),
    );
  }

  double _scale(int pictureWidth, int pictureHeight);

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is DecodeSize &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(runtimeType, width, height);
}

/// Large enough to cover a box of [width] × [height]: for a picture cut
/// to fill it.
final class Covering extends DecodeSize {
  const Covering(super.width, super.height);

  @override
  double _scale(int pictureWidth, int pictureHeight) =>
      math.max(width / pictureWidth, height / pictureHeight);
}

/// At most [width] × [height], keeping its shape: for a picture shown
/// whole.
final class Within extends DecodeSize {
  const Within(super.width, super.height);

  @override
  double _scale(int pictureWidth, int pictureHeight) =>
      math.min(width / pictureWidth, height / pictureHeight);
}

/// A picture to show, decoded no larger than the size it is asked at.
typedef SizedImage = ImageProvider Function(Within size);

/// A picture read as bytes when it first shows, decoded at [size] (whole
/// if `null`), kept in Flutter's image cache by its [identity] and
/// [size]. A read or decode that fails leaves the cache, so the picture
/// is tried again when it shows again (Flutter would keep a failed load
/// for good).
abstract class BytesImage<T extends BytesImage<T>> extends ImageProvider<T> {
  const BytesImage({this.size});

  final DecodeSize? size;

  /// What tells this picture apart from others of its kind, as values
  /// compared one by one (e.g. a file's id and version).
  @protected
  List<Object?> get identity;

  /// The picture's bytes; `null` if they can't be read now.
  @protected
  Future<Uint8List?> readBytes();

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is BytesImage<T> &&
      other.size == size &&
      listEquals(other.identity, identity);

  @override
  int get hashCode => Object.hash(runtimeType, size, Object.hashAll(identity));

  @override
  Future<T> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this as T);

  @override
  ImageStreamCompleter loadImage(T key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(key, decode), scale: 1);

  Future<ui.Codec> _load(T key, ImageDecoderCallback decode) async {
    try {
      final bytes = await readBytes();
      if (bytes == null) throw StateError('The picture could not be read.');
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return await switch (size) {
        final size? => decode(buffer, getTargetSize: size.targetFor),
        null => decode(buffer),
      };
    } on Object {
      PaintingBinding.instance.imageCache.evict(key);
      rethrow;
    }
  }
}
