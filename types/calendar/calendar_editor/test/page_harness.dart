import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
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

/// The view a device keeps for calendars, as a test sets and reads it.
final class KeptView {
  KeptView([this.kind = CalendarViewKind.month]);

  CalendarViewKind kind;

  CalendarViewChoice get choice => CalendarViewChoice(
    last: () => kind,
    keep: (kind) async => this.kind = kind,
  );
}

/// Shows [part]'s calendar page as of [today] on a device in [deviceZone]
/// that keeps the view in [kept] (by default the month), its hints added
/// to [hints]; closes the part's editor once the test ends.
Future<void> pumpPage(
  WidgetTester tester,
  CalendarEditorPart part, {
  required DateTime today,
  List<String>? hints,
  String? deviceZone,
  KeptView? kept,
}) async {
  // Not awaited: with no file to keep its edits, the editor never ends.
  addTearDown(() => unawaited(part.editor.close()));
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
              viewChoice: (kept ?? KeptView()).choice,
              now: () => today,
            ).view(
              EditorHost(kept: part.owner.state.text, hint: (hints ?? []).add),
              autofocus: false,
            ),
      ),
    ),
  );
  // The views show their events after the first frame.
  await tester.pumpAndSettle();
}

/// The calendar [part] holds now.
Calendar calendarOf(CalendarEditorPart part) => part.owner.state.calendar!;
