import 'package:meta/meta.dart';

/// One fact a file type tells about a file, under its [label] (e.g.
/// "Words", "Camera"), beside what every file has. Its kind says what
/// its value is, so the app shows dates and places the same way for
/// every type.
@immutable
sealed class FileFact {
  const FileFact(this.label);

  final String label;
}

/// A fact told as it is, e.g. a count or a camera's name.
final class TextFact extends FileFact {
  const TextFact(super.label, this.text);

  final String text;
}

/// A moment, e.g. when a picture was taken, on the clock it was told
/// in.
final class TimeFact extends FileFact {
  const TimeFact(super.label, this.at);

  final DateTime at;
}

/// A point on a map, in degrees, e.g. where a picture was taken.
final class MapPointFact extends FileFact {
  const MapPointFact(
    super.label, {
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}
