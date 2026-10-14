import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/edited_time.dart';

void main() {
  const local = DefaultMaterialLocalizations();
  final now = DateTime(2026, 10, 14, 18);

  String format(DateTime time) => editedTime(local, time, now: now);

  test('shows the time for today', () {
    expect(format(DateTime(2026, 10, 14, 9, 5)), '9:05 AM');
  });

  test('shows the day for this year', () {
    expect(format(DateTime(2026, 10, 13, 23)), 'Oct 13');
  });

  test('shows the date for other years', () {
    expect(format(DateTime(2025, 10, 14, 9)), 'Oct 14, 2025');
  });
}
