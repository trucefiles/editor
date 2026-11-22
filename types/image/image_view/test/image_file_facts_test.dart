import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_image_view/src/image_file_facts.dart';
import 'package:truce_images/truce_images.dart';

void main() {
  test('words each fact told, and only those', () {
    final facts = factsOf(
      ImageFacts(
        width: 4000,
        height: 3000,
        taken: DateTime(2026, 11, 22, 13, 5),
        camera: 'Pixel 7',
        exposure: const Exposure(
          seconds: (numerator: 10, denominator: 1250),
          fNumber: 1.85,
          iso: 100,
          focalLength: 6.0,
        ),
        location: (latitude: 48.1, longitude: 11.5),
      ),
    );

    expect(
      [for (final fact in facts) fact.label],
      ['Dimensions', 'Taken', 'Camera', 'Exposure', 'Location'],
    );
    expect((facts[0] as TextFact).text, '4000 × 3000 pixels');
    expect((facts[1] as TimeFact).at, DateTime(2026, 11, 22, 13, 5));
    expect((facts[3] as TextFact).text, '1/125 s · f/1.9 · ISO 100 · 6 mm');
    final location = facts[4] as MapPointFact;
    expect((location.latitude, location.longitude), (48.1, 11.5));
  });

  test('a long exposure reads in seconds', () {
    expect(
      exposureText(const Exposure(seconds: (numerator: 5, denominator: 2))),
      '2.5 s',
    );
  });

  test(
    'tells nothing of content that is no picture or cannot be read',
    () async {
      expect(
        await imageFileFacts(
          ShownContent(1, () async => Uint8List.fromList('text'.codeUnits)),
        ),
        isEmpty,
      );
      expect(await imageFileFacts(ShownContent(2, () async => null)), isEmpty);
    },
  );
}
