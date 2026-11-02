import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_page/truce_document_page.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_test_support/truce_test_support.dart' show ManualTimers;

/// When the tests' edits are made.
final editedAt = DateTime.utc(2026, 11, 1, 12);

/// A calendar part on [text], its edits made at [now] (else [editedAt]).
CalendarEditorPart calendarPart(
  String text, {
  bool readOnly = false,
  DateTime Function()? now,
}) => CalendarEditorPart(
  (
    text: text,
    version: const Version(1),
    view: ViewSettings.none,
    readOnly: readOnly,
    isNew: false,
  ),
  now: now ?? () => editedAt,
  // Never fire: no file keeps the edits here.
  startTimer: ManualTimers().start,
);

/// Shows [part]'s calendar page as of [today] on a device in [deviceZone],
/// its hints added to [hints]; closes the part's editor once the test ends.
Future<void> pumpPage(
  WidgetTester tester,
  CalendarEditorPart part, {
  required DateTime today,
  List<String>? hints,
  String? deviceZone,
}) async {
  // Not awaited: with no file to keep its edits, the editor never ends.
  addTearDown(() => unawaited(part.editor.close()));
  // Tall enough that the picked day's events show below the month.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body:
            CalendarEditorView(
              part,
              deviceZone: () async => deviceZone,
              today: () => today,
            ).view(
              EditorHost(kept: part.owner.state.text, hint: (hints ?? []).add),
              autofocus: false,
            ),
      ),
    ),
  );
}

/// The calendar [part] holds now.
Calendar calendarOf(CalendarEditorPart part) => part.owner.state.calendar!;
