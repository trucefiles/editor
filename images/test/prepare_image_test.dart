import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:truce_images/truce_images.dart';

Uint8List _sample(String name) => File('test/samples/$name').readAsBytesSync();

bool _holds(Uint8List bytes, String text) =>
    latin1.decode(bytes).contains(text);

const _keepAll = ImageSettings(removeLocation: false, makeSmaller: false);
const _noLocation = ImageSettings(removeLocation: true, makeSmaller: false);
const _smaller = ImageSettings(removeLocation: true, makeSmaller: true);

void main() {
  group('ImageKind', () {
    test('tells kinds by their bytes, not their names', () {
      expect(ImageKind.of(_sample('located.jpg')), ImageKind.jpeg);
      expect(ImageKind.of(_sample('located.png')), ImageKind.png);
      expect(ImageKind.of(_sample('located.webp')), ImageKind.webp);
      expect(ImageKind.of(_sample('animated.gif')), ImageKind.gif);
      expect(
        ImageKind.of(img.encodeBmp(img.Image(width: 2, height: 2))),
        ImageKind.bmp,
      );
      expect(ImageKind.of(utf8.encode('<svg></svg>')), isNull);
      expect(ImageKind.of(Uint8List(0)), isNull);
    });
  });

  group('prepareImage', () {
    test('takes anything else than a picture of a known kind as none', () {
      expect(prepareImage(utf8.encode('ftypheic'), _keepAll), isNull);
    });

    test('keeps every byte when nothing is asked', () {
      final bytes = _sample('located.jpg');
      expect(prepareImage(bytes, _keepAll)!.bytes, bytes);
    });

    test('a JPEG loses GPS and XMP but keeps its orientation and picture', () {
      final bytes = _sample('located.jpg');
      expect(img.decodeJpgExif(bytes)!.gpsIfd.isEmpty, isFalse);
      expect(_holds(bytes, 'GPSLatitude'), isTrue);
      final out = prepareImage(bytes, _noLocation)!;
      expect(out.kind, ImageKind.jpeg);
      final exif = img.decodeJpgExif(out.bytes)!;
      expect(exif.gpsIfd.isEmpty, isTrue);
      expect(exif.imageIfd.orientation, 6);
      expect(exif.imageIfd.make, 'SampleCam');
      expect(_holds(out.bytes, 'GPSLatitude'), isFalse);
      expect(img.decodeJpg(out.bytes), isNotNull);
    });

    test('a PNG loses its EXIF and XMP chunks, the rest byte for byte', () {
      final bytes = _sample('located.png');
      final out = prepareImage(bytes, _noLocation)!.bytes;
      expect(_holds(out, 'eXIf'), isFalse);
      expect(_holds(out, 'GPSLatitude'), isFalse);
      expect(_holds(out, 'IDAT'), isTrue);
      expect(img.decodePng(out)!.width, 64);
    });

    test('a WebP loses its EXIF and XMP chunks, its flags and size follow', () {
      final bytes = _sample('located.webp');
      final out = prepareImage(bytes, _noLocation)!.bytes;
      expect(_holds(out, 'EXIF'), isFalse);
      expect(_holds(out, 'GPSLatitude'), isFalse);
      final size = ByteData.sublistView(out, 4).getUint32(0, Endian.little);
      expect(size, out.length - 8);
      expect(img.decodeWebP(out)!.width, 64);
    });

    test('bytes after a picture\'s end go with its location', () {
      final trailing = utf8.encode('<x:xmpmeta GPSLatitude="1"/> and more');
      for (final name in ['located.jpg', 'located.png', 'located.webp']) {
        final sample = _sample(name);
        final bytes = Uint8List.fromList([...sample, ...trailing]);
        final out = prepareImage(bytes, _noLocation)!.bytes;
        expect(_holds(out, 'GPSLatitude'), isFalse, reason: name);
      }
    });

    test('a picture whose location can not be found is none', () {
      final png = _sample('located.png');
      final webp = _sample('located.webp');
      final jpeg = _sample('located.jpg');
      final broken = {
        // A chunk that claims more bytes than there are.
        'png': Uint8List.fromList([
          ...png.sublist(0, 8),
          0,
          0,
          0x10,
          0,
          ...png.sublist(12),
        ]),
        // A size that claims more bytes than there are.
        'webp': Uint8List.fromList([
          ...webp.sublist(0, 4),
          0xFF,
          0xFF,
          0,
          0,
          ...webp.sublist(8),
        ]),
        // Cut inside its EXIF data.
        'jpeg': jpeg.sublist(0, 40),
      };
      for (final MapEntry(:key, :value) in broken.entries) {
        expect(prepareImage(value, _noLocation), isNull, reason: key);
        expect(prepareImage(value, _keepAll), isNotNull, reason: key);
      }
    });

    test('a small picture is not encoded anew when asked to be smaller', () {
      final bytes = _sample('animated.gif');
      expect(prepareImage(bytes, _smaller)!.bytes, bytes);
    });

    test('a large picture gets 2000 on its longest side, in its own kind', () {
      final large = img.encodeJpg(img.Image(width: 3000, height: 1500));
      final out = prepareImage(large, _smaller)!;
      expect(out.kind, ImageKind.jpeg);
      final shown = img.decodeJpg(out.bytes)!;
      expect((shown.width, shown.height), (2000, 1000));
    });

    test('a large located JPEG loses its location too', () {
      final large = img.Image(width: 3000, height: 1500)
        ..exif = img.decodeJpgExif(_sample('located.jpg'))!;
      final out = prepareImage(img.encodeJpg(large), _smaller)!.bytes;
      // Upright by its orientation: 1000 wide, 2000 high, and no longer
      // tagged to be turned.
      expect(img.decodeJpg(out)!.height, 2000);
      expect(img.decodeJpgExif(out)?.imageIfd.orientation, isNull);
      expect(img.decodeJpgExif(out)?.gpsIfd.isEmpty ?? true, isTrue);
      expect(_holds(out, 'GPSLatitude'), isFalse);
    });

    test('a large located PNG loses its location too', () {
      final large = img.Image(width: 3000, height: 1500)
        ..textData = {'XML:com.adobe.xmp': '<x:xmpmeta GPSLatitude="1"/>'}
        ..exif = img.decodeJpgExif(_sample('located.jpg'))!;
      final bytes = img.encodePng(large);
      expect(_holds(bytes, 'GPSLatitude'), isTrue);
      final out = prepareImage(bytes, _smaller)!.bytes;
      expect(img.decodePng(out)!.width, 2000);
      expect(_holds(out, 'GPSLatitude'), isFalse);
    });

    test('a large animation keeps every frame', () {
      final frames = img.Image(width: 2400, height: 1200)
        ..addFrame(img.Image(width: 2400, height: 1200));
      final out = prepareImage(img.encodeGif(frames), _smaller)!;
      final shown = img.decodeGif(out.bytes)!;
      expect((shown.width, shown.numFrames), (2000, 2));
    });

    test('a large WebP stays a WebP', () {
      final large = img.WebPEncoder(lossless: false)
          .encode(img.Image(width: 2200, height: 100));
      final out = prepareImage(large, _smaller)!;
      expect(out.kind, ImageKind.webp);
      expect(img.decodeWebP(out.bytes)!.width, 2000);
    });

    test('a picture that claims a kind but can not be read is none', () {
      final broken = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0, 1, 2]);
      expect(prepareImage(broken, _smaller), isNull);
    });
  });
}
