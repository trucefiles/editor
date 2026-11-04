import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/day_cells.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

const _out = String.fromEnvironment('SHOTS', defaultValue: '/tmp/shots');

String _health() => [
  for (final start in [DateTime.utc(2026, 9, 30), DateTime.utc(2026, 10, 28)])
    for (final i in [0, 1, 2, 3, 4])
      start.add(Duration(days: i)),
].fold(
  Calendar.read(newCalendarText('Me', health: true))!,
  (calendar, day) => applyEdit(
    calendar,
    AddEvent(
      'p${day.month}-${day.day}',
      EventDraft.health(const Period(PeriodFlow.medium), day),
      at: day,
    ),
  ),
).text;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late TestApp app;
  setUp(() {
    app = TestApp.create();
    WidgetsApp.debugAllowBannerOverride = false;
  });

  for (final (look, logical, android, dark) in [
    ('desktop', const Size(1000, 760), false, false),
    ('desktop_dark', const Size(1000, 760), false, true),
    ('touch', const Size(412, 860), true, false),
  ]) {
    testApp('stripes sample, $look', (tester) async {
      if (android) {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
      }
      if (dark) {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      }
      tester.view
        ..physicalSize = logical
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      app.write('me.ics', _health());
      await tester.addFolder(app);
      await tester.waitFor(find.text('Me'));
      await tester.openFile('Me');
      for (final variant in [0, 1, 2]) {
        debugLikelyLook = variant;
        tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
        await _shot(tester, '${look}_$variant');
      }
      debugLikelyLook = 0;
      await tester.pageBack();
      await tester.waitForNoteClosed();
    });
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final bytes = await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 1.5);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  Directory(_out).createSync(recursive: true);
  File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}
