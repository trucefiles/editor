import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Waits in real time, for the app's timers (save delay, rescans) and file
/// access.
extension UiDriver on WidgetTester {
  /// Pumps until [finder] finds something; fails after [timeout].
  Future<void> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) => waitUntil(() => finder.evaluate().isNotEmpty, timeout: timeout);

  /// Pumps until [condition] holds; fails after [timeout].
  Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out after $timeout');
      }
      await pump(const Duration(milliseconds: 100));
    }
  }

  /// Waits until [file] holds exactly [text].
  Future<void> waitForFile(File file, String text) =>
      waitUntil(() => file.existsSync() && file.readAsStringSync() == text);

  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }
}
