import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:truce_images/truce_images.dart';

Uint8List _sample(String name) => File('test/samples/$name').readAsBytesSync();

/// EXIF data as a phone writes it.
img.ExifData _phoneExif() {
  final exif = img.ExifData();
  exif.imageIfd
    ..make = 'Google'
    ..model = 'Pixel 7'
    ..orientation = 6;
  exif.exifIfd
    ..[0x9003] = img.IfdValueAscii('2026:11:22 13:05:59')
    ..[0xa434] = img.IfdValueAscii('Main camera')
    ..[0x829a] = img.IfdValueRational(1, 125)
    ..[0x829d] = img.IfdValueRational(18, 10)
    ..[0x8827] = img.IfdValueShort(100)
    ..[0x920a] = img.IfdValueRational(681, 100);
  exif.gpsIfd
    ..[0x0001] = img.IfdValueAscii('S')
    ..[0x0002] = img.IfdValueRational.list([
      img.Rational(33, 1),
      img.Rational(51, 1),
      img.Rational(36, 1),
    ])
    ..[0x0003] = img.IfdValueAscii('W')
    ..[0x0004] = img.IfdValueRational.list([
      img.Rational(70, 1),
      img.Rational(30, 1),
      img.Rational(0, 1),
    ]);
  return exif;
}

img.Image _picture() => img.Image(width: 8, height: 6)..exif = _phoneExif();

/// [png] with an eXIf chunk holding [exif] after its header chunk; with
/// the `Exif` start a JPEG has if [exifStart], as some programs write it.
Uint8List _withPngExif(
  Uint8List png,
  img.ExifData exif, {
  bool exifStart = false,
}) {
  final out = img.OutputBuffer(bigEndian: true);
  if (exifStart) out.writeBytes('Exif\u0000\u0000'.codeUnits);
  exif.write(out);
  final data = out.getBytes();
  final chunk = img.OutputBuffer(bigEndian: true)
    ..writeUint32(data.length)
    ..writeBytes('eXIf'.codeUnits)
    ..writeBytes(data)
    // Readers here skip the checksum.
    ..writeUint32(0);
  const afterHeader = 8 + 25;
  return Uint8List.fromList([
    ...png.sublist(0, afterHeader),
    ...chunk.getBytes(),
    ...png.sublist(afterHeader),
  ]);
}

void main() {
  void expectPhoneFacts(ImageFacts facts) {
    expect((facts.width, facts.height), (6, 8), reason: 'turned');
    expect(facts.taken, DateTime(2026, 11, 22, 13, 5, 59));
    expect(facts.camera, 'Google Pixel 7');
    expect(facts.lens, 'Main camera');
    expect(facts.exposure.seconds, (numerator: 1, denominator: 125));
    expect(facts.exposure.fNumber, 1.8);
    expect(facts.exposure.iso, 100);
    expect(facts.exposure.focalLength, 6.81);
    expect(facts.location!.latitude, closeTo(-33.86, 0.001));
    expect(facts.location!.longitude, -70.5);
  }

  test("reads a JPEG's size and EXIF data", () {
    expectPhoneFacts(imageFactsOf(img.encodeJpg(_picture()))!);
  });

  test("reads a WebP's size and EXIF chunk", () {
    expectPhoneFacts(imageFactsOf(img.encodeWebP(_picture()))!);
  });

  test("reads a PNG's size and eXIf chunk", () {
    final png = img.encodePng(img.Image(width: 8, height: 6));
    expectPhoneFacts(imageFactsOf(_withPngExif(png, _phoneExif()))!);
  });

  test('reads an eXIf chunk that starts as in a JPEG', () {
    final png = img.encodePng(img.Image(width: 8, height: 6));
    expectPhoneFacts(
      imageFactsOf(_withPngExif(png, _phoneExif(), exifStart: true))!,
    );
  });

  test('reads where a sample was taken, north and east', () {
    final facts = imageFactsOf(_sample('located.jpg'))!;

    expect(facts.location!.latitude, closeTo(48.1417, 0.0001));
    expect(facts.location!.longitude, closeTo(11.5694, 0.0001));
    expect(
      (facts.width, facts.height),
      (48, 64),
      reason: 'its orientation turns it',
    );
  });

  test('a GIF tells only its size', () {
    final facts = imageFactsOf(_sample('animated.gif'))!;

    expect((facts.width, facts.height), (40, 20));
    expect(facts.taken, isNull);
    expect(facts.camera, isNull);
    expect(facts.exposure.isEmpty, isTrue);
    expect(facts.location, isNull);
  });

  test('a camera whose model names its make is told once', () {
    final exif = img.ExifData();
    exif.imageIfd
      ..make = 'Canon'
      ..model = 'Canon EOS R6';
    final jpeg = img.encodeJpg(img.Image(width: 2, height: 2)..exif = exif);

    expect(imageFactsOf(jpeg)!.camera, 'Canon EOS R6');
  });

  test('a date left blank is none', () {
    final exif = img.ExifData();
    exif.exifIfd[0x9003] = img.IfdValueAscii('0000:00:00 00:00:00');
    final jpeg = img.encodeJpg(img.Image(width: 2, height: 2)..exif = exif);

    expect(imageFactsOf(jpeg)!.taken, isNull);
  });

  test("a JPEG's size and EXIF data are read before its picture data, "
      'which is never walked', () {
    final jpeg = img.encodeJpg(_picture());
    // Cut a few bytes into the picture data: nothing after its start is
    // needed.
    final scan = List.generate(
      jpeg.length - 1,
      (at) => at,
    ).firstWhere((at) => jpeg[at] == 0xFF && jpeg[at + 1] == 0xDA);

    expectPhoneFacts(imageFactsOf(Uint8List.sublistView(jpeg, 0, scan + 20))!);
  });

  test('a JPEG without EXIF data tells its size', () {
    final facts = imageFactsOf(img.encodeJpg(img.Image(width: 5, height: 3)))!;

    expect((facts.width, facts.height), (5, 3));
    expect(facts.camera, isNull);
  });

  test('a JPEG segment too short for its own length tells nothing', () {
    // A length of 1, less than the two bytes it takes itself.
    final broken = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 1, 0, 0]);

    final facts = imageFactsOf(broken)!;

    expect(facts.width, isNull);
    expect(facts.camera, isNull);
  });

  test('anything else than a known picture is none', () {
    expect(imageFactsOf(Uint8List.fromList('text'.codeUnits)), isNull);
  });

  test('a picture cut short keeps what its start tells', () {
    final jpeg = img.encodeJpg(_picture());

    expect(
      () => imageFactsOf(Uint8List.sublistView(jpeg, 0, 40)),
      returnsNormally,
    );
  });
}
