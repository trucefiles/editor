import 'dart:convert';
import 'dart:typed_data';

/// One chunk of a PNG or WebP picture: its [type] (e.g. `eXIf`, `EXIF`),
/// where it starts and ends in the picture's bytes (with its header,
/// length and padding), and its [data].
typedef Chunk = ({String type, int start, int end, Uint8List data});

/// One segment of a JPEG before its picture data: its [marker] (e.g.
/// `0xE1` for APP1), where it starts and ends in the picture's bytes
/// (with its marker and length), and its [data] (none for a marker that
/// stands alone).
typedef JpegSegment = ({int marker, int start, int end, Uint8List data});

/// A JPEG's segments after its start marker, up to its picture data
/// ([scan], where the start-of-scan segment begins); `null` if [bytes]
/// can't be walked to there. Stops before the picture data, so a walk
/// costs the same for a small or a large picture.
({List<JpegSegment> segments, int scan})? jpegSegments(Uint8List bytes) {
  const startOfScan = 0xDA;
  final segments = <JpegSegment>[];
  var at = 2;
  // A single-pass walk: its place in the bytes is its state.
  while (at + 4 <= bytes.length && bytes[at] == 0xFF) {
    final marker = bytes[at + 1];
    if (marker == startOfScan) return (segments: segments, scan: at);
    final end = _standsAlone(marker)
        ? at + 2
        : at + 2 + (bytes[at + 2] << 8 | bytes[at + 3]);
    if (end > bytes.length) return null;
    segments.add((
      marker: marker,
      start: at,
      end: end,
      data: Uint8List.sublistView(
        bytes,
        _standsAlone(marker) ? end : at + 4,
        end,
      ),
    ));
    at = end;
  }
  return null;
}

/// Markers without a length: start of image, TEM and the restarts.
bool _standsAlone(int marker) =>
    marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7);

/// A PNG's chunks after its signature, up to and with its end chunk;
/// `null` if [bytes] can't be walked to that end. Bytes after it are
/// in none.
List<Chunk>? pngChunks(Uint8List bytes) {
  const signature = 8;
  final chunks = <Chunk>[];
  var at = signature;
  // A single-pass walk: its place in the bytes is its state.
  while (at + 12 <= bytes.length) {
    final length = ByteData.sublistView(bytes, at).getUint32(0);
    final end = at + 12 + length;
    if (end > bytes.length) return null;
    final type = _fourCc(bytes, at + 4);
    chunks.add((
      type: type,
      start: at,
      end: end,
      data: Uint8List.sublistView(bytes, at + 8, at + 8 + length),
    ));
    if (type == 'IEND') return chunks;
    at = end;
  }
  return null;
}

/// How many bytes start a WebP before its first chunk.
const webpHeader = 12;

/// A WebP's chunks after its header, up to the end its RIFF size gives;
/// `null` if [bytes] can't be walked to exactly that end.
List<Chunk>? webpChunks(Uint8List bytes) {
  if (bytes.length < webpHeader) return null;
  final riffEnd =
      8 + ByteData.sublistView(bytes, 4).getUint32(0, Endian.little);
  if (riffEnd > bytes.length) return null;
  final chunks = <Chunk>[];
  var at = webpHeader;
  while (at + 8 <= riffEnd) {
    final size = ByteData.sublistView(
      bytes,
      at + 4,
    ).getUint32(0, Endian.little);
    final end = at + 8 + size + size % 2;
    if (end > riffEnd) return null;
    chunks.add((
      type: _fourCc(bytes, at),
      start: at,
      end: end,
      data: Uint8List.sublistView(bytes, at + 8, at + 8 + size),
    ));
    at = end;
  }
  return at == riffEnd ? chunks : null;
}

/// The four letters at [at] that name a chunk.
String _fourCc(Uint8List bytes, int at) =>
    ascii.decode(Uint8List.sublistView(bytes, at, at + 4), allowInvalid: true);
