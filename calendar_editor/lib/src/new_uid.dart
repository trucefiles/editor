import 'dart:math';

final _random = Random.secure();

/// A new event's `UID`: random, so no two devices make the same one.
String newUid() =>
    '${[for (final _ in Iterable<int>.generate(16)) _random.nextInt(256).toRadixString(16).padLeft(2, '0')].join()}@truce';
