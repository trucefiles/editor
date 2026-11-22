import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'chunks.dart';
import 'image_kind.dart';

/// What a picture's header and EXIF data tell of it; each `null` where
/// they don't. Read without its pixels ([imageFactsOf]).
final class ImageFacts {
  const ImageFacts({
    this.width,
    this.height,
    this.taken,
    this.camera,
    this.lens,
    this.exposure = const Exposure(),
    this.location,
  });

  /// Its size in pixels, as it shows (turned as its orientation says).
  final int? width;
  final int? height;

  /// When it was taken, on the camera's clock (no time zone).
  final DateTime? taken;

  /// The camera's make and model, e.g. "Pixel 7".
  final String? camera;

  final String? lens;
  final Exposure exposure;

  /// Where it was taken.
  final MapPoint? location;
}

/// How a picture was exposed; each `null` where it is not told.
final class Exposure {
  const Exposure({this.seconds, this.fNumber, this.iso, this.focalLength});

  /// How long, as the camera wrote it, e.g. 1/125.
  final ({int numerator, int denominator})? seconds;
  final double? fNumber;
  final int? iso;

  /// In millimeters.
  final double? focalLength;

  bool get isEmpty =>
      seconds == null && fNumber == null && iso == null && focalLength == null;
}

/// A point on a map, in degrees: north and east are positive.
typedef MapPoint = ({double latitude, double longitude});

/// The facts of [bytes], a picture of a kind [ImageKind.of] knows; `null`
/// for any other. Reads its header and EXIF data only, never its pixels:
/// JPEG, WebP and PNG (its `eXIf` chunk) carry EXIF data; GIF and BMP
/// only a size.
ImageFacts? imageFactsOf(Uint8List bytes) {
  final kind = ImageKind.of(bytes);
  if (kind == null) return null;
  final size = _sizeOf(bytes, kind);
  final exif = _exifOf(bytes, kind);
  final turned = (exif?.imageIfd.orientation ?? 1) >= 5;
  return ImageFacts(
    width: turned ? size?.height : size?.width,
    height: turned ? size?.width : size?.height,
    taken: _taken(exif),
    camera: _camera(exif),
    lens: _text(exif?.exifIfd[_lensModel]),
    exposure: _exposure(exif),
    location: _location(exif),
  );
}

/// The header's size; `null` if it can't be read (the `image` package
/// may throw on a broken one).
img.DecodeInfo? _sizeOf(Uint8List bytes, ImageKind kind) {
  try {
    return _decoderOf(kind).startDecode(bytes);
  } on Object {
    return null;
  }
}

img.Decoder _decoderOf(ImageKind kind) => switch (kind) {
  ImageKind.jpeg => img.JpegDecoder(),
  ImageKind.png => img.PngDecoder(),
  ImageKind.gif => img.GifDecoder(),
  ImageKind.webp => img.WebPDecoder(),
  ImageKind.bmp => img.BmpDecoder(),
};

/// `null` where there is none, or it can't be read: the `image` package
/// throws on EXIF data it can't read.
img.ExifData? _exifOf(Uint8List bytes, ImageKind kind) {
  try {
    final exif = switch (kind) {
      ImageKind.jpeg => img.decodeJpgExif(bytes),
      ImageKind.png => _exifIn(pngChunks(bytes), 'eXIf'),
      ImageKind.webp => _exifIn(webpChunks(bytes), 'EXIF'),
      ImageKind.gif || ImageKind.bmp => null,
    };
    return exif == null || exif.isEmpty ? null : exif;
  } on Object {
    return null;
  }
}

/// Own code for PNG and WebP: the `image` package reads their EXIF data
/// only along with the pixels.
img.ExifData? _exifIn(List<Chunk>? chunks, String type) =>
    switch (chunks?.where((chunk) => chunk.type == type).firstOrNull) {
      final chunk? => img.ExifData.fromInputBuffer(img.InputBuffer(chunk.data)),
      null => null,
    };

const _make = 0x010f,
    _model = 0x0110,
    _dateTime = 0x0132,
    _dateTimeOriginal = 0x9003,
    _exposureTime = 0x829a,
    _fNumber = 0x829d,
    _iso = 0x8827,
    _focalLength = 0x920a,
    _lensModel = 0xa434;

DateTime? _taken(img.ExifData? exif) => _date(
  _text(exif?.exifIfd[_dateTimeOriginal]) ?? _text(exif?.imageIfd[_dateTime]),
);

/// EXIF dates read `2026:11:22 13:05:59`; `null` for any other text,
/// e.g. a date left blank as zeros.
DateTime? _date(String? text) =>
    switch (_exifDate.firstMatch(text ?? '')?.groups([1, 2, 3, 4, 5, 6])) {
      final parts? => switch (parts.map((part) => int.parse(part!)).toList()) {
        [final y, final mo, final d, final h, final mi, final s]
            when y > 0 && mo > 0 && d > 0 =>
          DateTime(y, mo, d, h, mi, s),
        _ => null,
      },
      null => null,
    };

final _exifDate = RegExp(r'^(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)');

/// The model, after the make unless the model names it already.
String? _camera(img.ExifData? exif) =>
    switch ((_text(exif?.imageIfd[_make]), _text(exif?.imageIfd[_model]))) {
      (final make?, final model?)
          when !model.toLowerCase().startsWith(make.toLowerCase()) =>
        '$make $model',
      (_, final model?) => model,
      (final make, null) => make,
    };

Exposure _exposure(img.ExifData? exif) {
  final ifd = exif?.exifIfd;
  return Exposure(
    seconds: switch (_rational(ifd?[_exposureTime])) {
      final time? => (numerator: time.numerator, denominator: time.denominator),
      null => null,
    },
    fNumber: _rational(ifd?[_fNumber])?.toDouble(),
    iso: switch (ifd?[_iso]) {
      final iso? when iso.length > 0 && iso.toInt() > 0 => iso.toInt(),
      _ => null,
    },
    focalLength: _rational(ifd?[_focalLength])?.toDouble(),
  );
}

MapPoint? _location(img.ExifData? exif) {
  final gps = exif?.gpsIfd;
  if (gps == null) return null;
  final latitude = _degrees(gps[0x0002], _text(gps[0x0001]), negative: 'S');
  final longitude = _degrees(gps[0x0004], _text(gps[0x0003]), negative: 'W');
  if (latitude == null || longitude == null) return null;
  return (latitude: latitude, longitude: longitude);
}

/// Degrees, minutes and seconds as one number, negative for [negative]
/// ([ref], e.g. south); `null` unless all three are told and in range.
double? _degrees(img.IfdValue? value, String? ref, {required String negative}) {
  if (value == null || value.length != 3) return null;
  final parts = List.generate(3, value.toRational);
  if (parts.any((part) => part.denominator == 0)) return null;
  final [degrees, minutes, seconds] = [
    for (final part in parts) part.toDouble(),
  ];
  final total = degrees + minutes / 60 + seconds / 3600;
  if (total.isNaN || total > 180) return null;
  return ref?.toUpperCase() == negative ? -total : total;
}

/// `null` unless it is a number that can be read.
img.Rational? _rational(img.IfdValue? value) => switch (value) {
  final value? when value.length > 0 => switch (value.toRational()) {
    final rational when rational.denominator != 0 && rational.numerator > 0 =>
      rational,
    _ => null,
  },
  _ => null,
};

/// [value] as text without the zeros and spaces that pad it; `null` if
/// that leaves nothing.
String? _text(img.IfdValue? value) =>
    switch (value?.toString().replaceAll('\u0000', '').trim()) {
      final text? when text.isNotEmpty => text,
      _ => null,
    };
