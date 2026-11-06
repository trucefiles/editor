import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The time now, for the Calendar tab's views; a fixed clock in tests.
final calendarClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);
