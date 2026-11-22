import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'chunks.dart';
import 'image_kind.dart';

/// [bytes], a picture of [kind], without the data that tells where it
/// was taken: GPS in its EXIF data and its XMP data, which may hold it
/// too. Everything else keeps its bytes, the picture itself and its
/// orientation included, so nothing is encoded anew; bytes after the
/// picture's end go. GIF and BMP carry none. `null` if the bytes can't
/// be read as far as needed: never kept with their location unseen.
///
/// Own code for XMP and for PNG and WebP: the `image` package rewrites
/// only a JPEG's EXIF data without encoding the picture anew.
Uint8List? withoutLocation(Uint8List bytes, ImageKind kind) => switch (kind) {
  ImageKind.jpeg => switch (_jpegWithoutGps(bytes)) {
    final withoutGps? => _jpegWithoutXmp(withoutGps),
    null => null,
  },
  ImageKind.png => _pngWithout(bytes),
  ImageKind.webp => _webpWithout(bytes),
  ImageKind.gif || ImageKind.bmp => bytes,
};

/// Drops the GPS part of [exif], in place.
void _dropGps(img.ExifData exif) {
  exif.imageIfd.sub.directories.remove('gps');
  exif.imageIfd.data.remove(_gpsPointer);
}

/// The EXIF tag that points to the GPS part.
const _gpsPointer = 0x8825;

/// The `image` package throws on EXIF data it can't read.
Uint8List? _jpegWithoutGps(Uint8List bytes) {
  try {
    final exif = img.decodeJpgExif(bytes);
    if (exif == null || exif.gpsIfd.isEmpty) return bytes;
    _dropGps(exif);
    return img.injectJpgExif(bytes, exif);
  } on Object {
    return null;
  }
}

final _xmpStarts = [
  ascii.encode('http://ns.adobe.com/xap/1.0/\u0000'),
  ascii.encode('http://ns.adobe.com/xmp/extension/\u0000'),
];

/// [bytes] up to their end marker, without the APP1 segments that hold
/// XMP data; `null` if they can't be walked to that end.
Uint8List? _jpegWithoutXmp(Uint8List bytes) {
  const app1 = 0xE1;
  final walked = jpegSegments(bytes);
  if (walked == null) return null;
  // The picture's data never holds 0xFF 0xD9 before its end.
  final end = _endOfImage(bytes, walked.scan);
  if (end == null) return null;
  final out = BytesBuilder(copy: false)..add(bytes.sublist(0, 2));
  for (final segment in walked.segments) {
    if (!(segment.marker == app1 &&
        _xmpStarts.any((start) => _startsWith(segment.data, start)))) {
      out.add(bytes.sublist(segment.start, segment.end));
    }
  }
  return (out..add(bytes.sublist(walked.scan, end))).takeBytes();
}

/// Where the end marker found from [from] ends; `null` if there is none.
int? _endOfImage(Uint8List bytes, int from) {
  for (var at = from; at + 1 < bytes.length; at++) {
    if (bytes[at] == 0xFF && bytes[at + 1] == 0xD9) return at + 2;
  }
  return null;
}

/// [bytes] up to their end chunk, without the eXIf chunk and the text
/// chunks that hold XMP data; `null` if they can't be walked to the end
/// chunk.
Uint8List? _pngWithout(Uint8List bytes) {
  final chunks = pngChunks(bytes);
  if (chunks == null) return null;
  final out = BytesBuilder(copy: false)..add(bytes.sublist(0, 8));
  for (final chunk in chunks.where((chunk) => !_isPngLocation(chunk))) {
    out.add(bytes.sublist(chunk.start, chunk.end));
  }
  return out.takeBytes();
}

bool _isPngLocation(Chunk chunk) => switch (chunk.type) {
  'eXIf' => true,
  'iTXt' || 'tEXt' || 'zTXt' => _startsWith(chunk.data, _pngXmpKeyword),
  _ => false,
};

final _pngXmpKeyword = ascii.encode('XML:com.adobe.xmp\u0000');

/// [bytes] up to the end their size gives, without the EXIF and XMP
/// chunks, with the flags and size that name them set to match; `null`
/// if they can't be walked to that end.
Uint8List? _webpWithout(Uint8List bytes) {
  const exifFlag = 0x08, xmpFlag = 0x04;
  final walked = webpChunks(bytes);
  if (walked == null) return null;
  final chunks = [
    for (final chunk in walked)
      if (chunk.type != 'EXIF' && chunk.type != 'XMP ')
        switch (bytes.sublist(chunk.start, chunk.end)) {
          // The extended header's flags say which chunks follow.
          final header when chunk.type == 'VP8X' && chunk.data.isNotEmpty =>
            header..[8] &= ~(exifFlag | xmpFlag),
          final kept => kept,
        },
  ];
  final body = chunks.fold(0, (sum, chunk) => sum + chunk.length);
  final out = BytesBuilder(copy: false)
    ..add(bytes.sublist(0, 4))
    ..add(
      Uint8List(4)..buffer.asByteData().setUint32(0, body + 4, Endian.little),
    )
    ..add(bytes.sublist(8, webpHeader));
  chunks.forEach(out.add);
  return out.takeBytes();
}

bool _startsWith(Uint8List data, List<int> start) =>
    data.length >= start.length &&
    start.indexed.every((entry) => data[entry.$1] == entry.$2);
