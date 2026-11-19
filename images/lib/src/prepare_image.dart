import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_kind.dart';
import 'location_data.dart';

/// How pictures are made ready to keep: the device's settings.
final class ImageSettings {
  const ImageSettings({
    required this.removeLocation,
    required this.makeSmaller,
  });

  /// What a device starts with: location out, size as picked.
  static const standard = ImageSettings(
    removeLocation: true,
    makeSmaller: false,
  );

  /// Take out the data that tells where a picture was taken.
  final bool removeLocation;

  /// Make a picture whose longest side passes [longestSide] that small,
  /// in its own kind.
  final bool makeSmaller;

  /// About what a full-screen view on a large display shows.
  static const longestSide = 2000;

  ImageSettings copyWith({bool? removeLocation, bool? makeSmaller}) =>
      ImageSettings(
        removeLocation: removeLocation ?? this.removeLocation,
        makeSmaller: makeSmaller ?? this.makeSmaller,
      );

  Map<String, Object?> toJson() => {
    'removeLocation': removeLocation,
    'makeSmaller': makeSmaller,
  };

  /// The settings [json] holds, each read on its own: one missing or not
  /// written by [toJson] takes its [standard] value.
  static ImageSettings fromJson(Object? json) {
    final fields = json is Map<String, Object?>
        ? json
        : const <String, Object?>{};
    return ImageSettings(
      removeLocation: switch (fields['removeLocation']) {
        final bool remove => remove,
        _ => standard.removeLocation,
      },
      makeSmaller: switch (fields['makeSmaller']) {
        final bool smaller => smaller,
        _ => standard.makeSmaller,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImageSettings &&
      other.removeLocation == removeLocation &&
      other.makeSmaller == makeSmaller;

  @override
  int get hashCode => Object.hash(removeLocation, makeSmaller);
}

/// A picture ready to keep: its [bytes], of [kind].
final class PreparedImage {
  const PreparedImage(this.bytes, this.kind);

  final Uint8List bytes;
  final ImageKind kind;
}

/// [bytes], a picture the user picked, ready to keep by [settings]:
/// encoded anew only when made smaller; else as picked, only its
/// location data taken out if asked. `null` if it is not a picture of a
/// kind the app takes, or can't be read to make it smaller.
PreparedImage? prepareImage(Uint8List bytes, ImageSettings settings) {
  final kind = ImageKind.of(bytes);
  if (kind == null) return null;
  final Uint8List sized;
  switch (settings.makeSmaller ? _smaller(bytes, kind) : const _SmallEnough()) {
    case _Unreadable():
      return null;
    case _Smaller(:final bytes):
      sized = bytes;
    case _SmallEnough():
      sized = bytes;
  }
  // On the final bytes: an encoder may carry location along.
  return PreparedImage(
    settings.removeLocation ? withoutLocation(sized, kind) : sized,
    kind,
  );
}

/// [prepareImage] away from the caller's thread: decoding and encoding a
/// large picture takes a while.
Future<PreparedImage?> prepareInBackground(
  Uint8List bytes,
  ImageSettings settings,
) => Isolate.run(() => prepareImage(bytes, settings));

sealed class _Resized {
  const _Resized();
}

final class _Unreadable extends _Resized {
  const _Unreadable();
}

final class _SmallEnough extends _Resized {
  const _SmallEnough();
}

final class _Smaller extends _Resized {
  const _Smaller(this.bytes);

  final Uint8List bytes;
}

/// [bytes] at most [ImageSettings.longestSide] on their longest side,
/// every frame of an animation too, upright (the JPEG decoder turns it
/// by its orientation).
_Resized _smaller(Uint8List bytes, ImageKind kind) {
  final img.Image? image;
  try {
    image = switch (kind) {
      ImageKind.jpeg => img.decodeJpg(bytes),
      ImageKind.png => img.decodePng(bytes),
      ImageKind.gif => img.decodeGif(bytes),
      ImageKind.webp => img.decodeWebP(bytes),
      ImageKind.bmp => img.decodeBmp(bytes),
    };
  } on Object {
    return const _Unreadable();
  }
  if (image == null) return const _Unreadable();
  final longest = max(image.width, image.height);
  if (longest <= ImageSettings.longestSide) return const _SmallEnough();
  final scale = ImageSettings.longestSide / longest;
  final small = img.copyResize(
    image,
    width: (image.width * scale).round(),
    height: (image.height * scale).round(),
    interpolation: img.Interpolation.average,
  );
  return _Smaller(switch (kind) {
    ImageKind.jpeg => img.encodeJpg(small, quality: 90),
    ImageKind.png => img.encodePng(small),
    ImageKind.gif => img.encodeGif(small),
    ImageKind.webp => img.WebPEncoder(
      lossless: false,
      quality: 85,
    ).encode(small),
    ImageKind.bmp => img.encodeBmp(small),
  });
}
