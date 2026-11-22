import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_images/truce_images.dart';

/// What the picture [content] holds tells of itself (its size, when,
/// with what and where it was taken): read once, its header and EXIF
/// data only; none if it can't be read.
Future<List<FileFact>> imageFileFacts(ShownContent content) async =>
    switch (await content.read()) {
      final bytes? => switch (imageFactsOf(bytes)) {
        final facts? => factsOf(facts),
        null => const [],
      },
      null => const [],
    };

/// [facts] in words, each only where it is told.
List<FileFact> factsOf(ImageFacts facts) => [
  if ((facts.width, facts.height) case (final width?, final height?))
    TextFact('Dimensions', '$width × $height pixels'),
  if (facts.taken case final taken?) TimeFact('Taken', taken),
  if (facts.camera case final camera?) TextFact('Camera', camera),
  if (facts.lens case final lens?) TextFact('Lens', lens),
  if (!facts.exposure.isEmpty)
    TextFact('Exposure', exposureText(facts.exposure)),
  if (facts.location case (:final latitude, :final longitude))
    MapPointFact('Location', latitude: latitude, longitude: longitude),
];

/// E.g. `1/125 s · f/1.8 · ISO 100 · 6.8 mm`, with what is told.
String exposureText(Exposure exposure) => [
  if (exposure.seconds case final seconds?) '${_seconds(seconds)} s',
  if (exposure.fNumber case final fNumber?) 'f/${_short(fNumber)}',
  if (exposure.iso case final iso?) 'ISO $iso',
  if (exposure.focalLength case final focal?) '${_short(focal)} mm',
].join(' · ');

/// Below a second as a fraction of one where it is close to one, e.g.
/// `1/125` (cameras round these), else as a number, e.g. `0.8`.
String _seconds(({int numerator, int denominator}) time) {
  final seconds = time.numerator / time.denominator;
  final parts = (1 / seconds).round();
  return seconds < 1 && (1 / parts - seconds).abs() <= seconds * 0.05
      ? '1/$parts'
      : _short(seconds);
}

/// With at most one decimal, none if it is 0.
String _short(double value) => switch (value.toStringAsFixed(1)) {
  final text when text.endsWith('.0') => text.substring(0, text.length - 2),
  final text => text,
};
