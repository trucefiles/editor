import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_kind.dart';

/// [bytes], a picture of [kind], without the data that tells where it
/// was taken: GPS in its EXIF data and its XMP data, which may hold it
/// too. Everything else keeps its bytes, the picture itself and its
/// orientation included, so nothing is encoded anew. GIF and BMP carry
/// none.
///
/// Own code for XMP and for PNG and WebP: the `image` package rewrites
/// only a JPEG's EXIF data without encoding the picture anew.
Uint8List withoutLocation(Uint8List bytes, ImageKind kind) => switch (kind) {
  ImageKind.jpeg => _jpegWithoutXmp(_jpegWithoutGps(bytes)),
  ImageKind.png => _pngWithout(bytes),
  ImageKind.webp => _webpWithout(bytes),
  ImageKind.gif || ImageKind.bmp => bytes,
};

/// Drops the GPS part of [exif], in place.
void dropGps(img.ExifData exif) {
  exif.imageIfd.sub.directories.remove('gps');
  exif.imageIfd.data.remove(_gpsPointer);
}

/// The EXIF tag that points to the GPS part.
const _gpsPointer = 0x8825;

Uint8List _jpegWithoutGps(Uint8List bytes) {
  final exif = img.decodeJpgExif(bytes);
  if (exif == null || exif.gpsIfd.isEmpty) return bytes;
  dropGps(exif);
  return img.injectJpgExif(bytes, exif) ?? bytes;
}

final _xmpStarts = [
  ascii.encode('http://ns.adobe.com/xap/1.0/\u0000'),
  ascii.encode('http://ns.adobe.com/xmp/extension/\u0000'),
];

/// [bytes] without the APP1 segments that hold XMP data; as they are if
/// they can't be walked.
Uint8List _jpegWithoutXmp(Uint8List bytes) {
  const app1 = 0xE1, startOfScan = 0xDA;
  final out = BytesBuilder(copy: false)..add(bytes.sublist(0, 2));
  var at = 2;
  // A single-pass parser: its place in the bytes is its state.
  while (at + 4 <= bytes.length && bytes[at] == 0xFF) {
    final marker = bytes[at + 1];
    if (marker == startOfScan) break;
    if (_standsAlone(marker)) {
      out.add(bytes.sublist(at, at + 2));
      at += 2;
      continue;
    }
    final end = at + 2 + (bytes[at + 2] << 8 | bytes[at + 3]);
    if (end > bytes.length) return bytes;
    final data = Uint8List.sublistView(bytes, at + 4, end);
    if (!(marker == app1 &&
        _xmpStarts.any((start) => _startsWith(data, start)))) {
      out.add(bytes.sublist(at, end));
    }
    at = end;
  }
  out.add(bytes.sublist(at));
  return out.takeBytes();
}

/// Markers without a length: start of image, TEM and the restarts.
bool _standsAlone(int marker) =>
    marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7);

/// [bytes] without the eXIf chunk and the text chunks that hold XMP data;
/// as they are if they can't be walked.
Uint8List _pngWithout(Uint8List bytes) {
  const signature = 8;
  final out = BytesBuilder(copy: false)..add(bytes.sublist(0, signature));
  var at = signature;
  while (at + 12 <= bytes.length) {
    final length = ByteData.sublistView(bytes, at).getUint32(0);
    final end = at + 12 + length;
    if (end > bytes.length) return bytes;
    final type = ascii.decode(
      bytes.sublist(at + 4, at + 8),
      allowInvalid: true,
    );
    final data = Uint8List.sublistView(bytes, at + 8, at + 8 + length);
    if (!_isPngLocation(type, data)) out.add(bytes.sublist(at, end));
    at = end;
  }
  out.add(bytes.sublist(at));
  return out.takeBytes();
}

bool _isPngLocation(String type, Uint8List data) => switch (type) {
  'eXIf' => true,
  'iTXt' || 'tEXt' || 'zTXt' => _startsWith(data, _pngXmpKeyword),
  _ => false,
};

final _pngXmpKeyword = ascii.encode('XML:com.adobe.xmp\u0000');

/// [bytes] without the EXIF and XMP chunks, with the flags and size that
/// name them set to match; as they are if they can't be walked.
Uint8List _webpWithout(Uint8List bytes) {
  const header = 12, exifFlag = 0x08, xmpFlag = 0x04;
  final chunks = <Uint8List>[];
  var at = header;
  while (at + 8 <= bytes.length) {
    final fourCc = ascii.decode(bytes.sublist(at, at + 4), allowInvalid: true);
    final size = ByteData.sublistView(
      bytes,
      at + 4,
    ).getUint32(0, Endian.little);
    final end = at + 8 + size + size % 2;
    if (end > bytes.length) return bytes;
    final chunk = Uint8List.fromList(bytes.sublist(at, end));
    if (fourCc == 'VP8X') chunk[8] &= ~(exifFlag | xmpFlag);
    if (fourCc != 'EXIF' && fourCc != 'XMP ') chunks.add(chunk);
    at = end;
  }
  if (at != bytes.length) return bytes;
  final body = chunks.fold(0, (sum, chunk) => sum + chunk.length);
  final out = BytesBuilder(copy: false)
    ..add(bytes.sublist(0, 4))
    ..add(
      Uint8List(4)..buffer.asByteData().setUint32(0, body + 4, Endian.little),
    )
    ..add(bytes.sublist(8, header));
  chunks.forEach(out.add);
  return out.takeBytes();
}

bool _startsWith(Uint8List data, List<int> start) =>
    data.length >= start.length &&
    start.indexed.every((entry) => data[entry.$1] == entry.$2);
