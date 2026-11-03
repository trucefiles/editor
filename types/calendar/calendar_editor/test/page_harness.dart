import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_test_support/truce_test_support.dart'
    show ManualTimers, folderId, path;

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

/// The file the test page shows.
final pageFolder = folderId('home');
final pagePath = path('a.ics');
final FileKey pageFile = (folder: pageFolder, path: pagePath);

/// Shows [part]'s calendar page as of [today] on a device in [deviceZone]
/// that keeps the view in [kept] (by default the month), with its Add
/// button while it can be edited, its hints added to [hints], taking what [starts] asks of it;
/// closes the part's editor once the test ends.
Future<void> pumpPage(
  WidgetTester tester,
  CalendarEditorPart part, {
  required DateTime today,
  List<String>? hints,
  String? deviceZone,
  KeptView? kept,
  CalendarStarts? starts,
}) async {
  // Not awaited: with no file to keep its edits, the editor never ends.
  addTearDown(() => unawaited(part.editor.close()));
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final view = CalendarEditorView(
    part,
    deviceZone: () async => deviceZone,
    viewChoice: (kept ?? KeptView()).choice,
    starts: starts ?? CalendarStarts(),
    now: () => today,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          // As the file page shows it: only while the file can be edited.
          floatingActionButton: part.isEditing
              ? view.floatingButton(context)
              : null,
          body: view.view(
            EditorHost(
              kept: part.owner.state.text,
              folder: pageFolder,
              path: pagePath,
              bytesOf: (_) async => null,
              hint: (hints ?? []).add,
              color: Colors.teal,
            ),
            autofocus: false,
          ),
        ),
      ),
    ),
  );
  // The views show their events after the first frame.
  await tester.pumpAndSettle();
}

/// The calendar [part] holds now.
Calendar calendarOf(CalendarEditorPart part) => part.owner.state.calendar!;
