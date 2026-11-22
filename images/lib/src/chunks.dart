import 'dart:convert';
import 'dart:typed_data';

/// One chunk of a PNG or WebP picture: its [type] (e.g. `eXIf`, `EXIF`),
/// where it starts and ends in the picture's bytes (with its header,
/// length and padding), and its [data].
typedef Chunk = ({String type, int start, int end, Uint8List data});

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
    ascii.decode(bytes.sublist(at, at + 4), allowInvalid: true);
