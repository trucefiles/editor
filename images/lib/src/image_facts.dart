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
  final (size, exif) = switch (kind) {
    ImageKind.jpeg => _jpegHeader(bytes),
    ImageKind.png => (
      _headerSize(bytes, img.PngDecoder()),
      _exifIn(pngChunks(bytes), 'eXIf'),
    ),
    ImageKind.webp => (
      _headerSize(bytes, img.WebPDecoder()),
      _exifIn(webpChunks(bytes), 'EXIF'),
    ),
    ImageKind.gif => (_headerSize(bytes, img.GifDecoder()), null),
    ImageKind.bmp => (_headerSize(bytes, img.BmpDecoder()), null),
  };
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

typedef _Size = ({int width, int height});

/// The size [decoder] reads from the header; `null` if it can't be read.
_Size? _headerSize(Uint8List bytes, img.Decoder decoder) {
  try {
    return switch (decoder.startDecode(bytes)) {
      final info? => (width: info.width, height: info.height),
      null => null,
    };
    // The `image` package may throw on a broken header.
  } on Object {
    return null;
  }
}

/// A JPEG's size and EXIF data, from one walk of its segments. Own code:
/// the `image` package's header read walks every byte of the picture
/// data to its end (a visible cost on a large photo), and so does its
/// EXIF read on a photo without EXIF data. Both sit before the picture
/// data: the size in the first frame header, EXIF in an APP1 segment.
(_Size?, img.ExifData?) _jpegHeader(Uint8List bytes) {
  final segments = jpegSegments(bytes)?.segments ?? const [];
  return (
    switch (segments.where(_isFrameHeader).firstOrNull?.data) {
      final data? when data.length >= 5 => (
        height: data[1] << 8 | data[2],
        width: data[3] << 8 | data[4],
      ),
      _ => null,
    },
    _readExif(segments.where(_isExif).firstOrNull?.data),
  );
}

/// Start-of-frame markers: 0xC0 to 0xCF, but for the tables (C4, CC)
/// and a reserved one (C8).
bool _isFrameHeader(JpegSegment segment) =>
    segment.marker >= 0xC0 &&
    segment.marker <= 0xCF &&
    !const {0xC4, 0xC8, 0xCC}.contains(segment.marker);

/// An APP1 segment that holds EXIF data.
bool _isExif(JpegSegment segment) =>
    segment.marker == 0xE1 && _startsWithExif(segment.data);

bool _startsWithExif(Uint8List data) =>
    data.length >= _exifStart.length &&
    String.fromCharCodes(data.take(_exifStart.length)) == _exifStart;

/// What starts EXIF data in a JPEG, and in some PNG and WebP files too.
const _exifStart = 'Exif\u0000\u0000';

/// Own code for PNG and WebP: the `image` package reads their EXIF data
/// only along with the pixels.
img.ExifData? _exifIn(List<Chunk>? chunks, String type) =>
    _readExif(chunks?.where((chunk) => chunk.type == type).firstOrNull?.data);

/// [data] as EXIF data, with or without the `Exif` start; `null` where
/// there is none or it can't be read (the `image` package throws on EXIF
/// data it can't read).
img.ExifData? _readExif(Uint8List? data) {
  if (data == null) return null;
  final tiff = _startsWithExif(data)
      ? Uint8List.sublistView(data, _exifStart.length)
      : data;
  try {
    final exif = img.ExifData.fromInputBuffer(img.InputBuffer(tiff));
    return exif.isEmpty ? null : exif;
  } on Object {
    return null;
  }
}

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
