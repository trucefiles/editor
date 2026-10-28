import 'package:collection/collection.dart';

/// The value [values] hold most often; `null` if they hold none.
T? mostUsed<T>(Iterable<T> values) => maxBy(
  groupBy(values, (value) => value).entries,
  (entry) => entry.value.length,
)?.key;
