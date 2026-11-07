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

/// A calendar part on [text], its edits made at [now] (else [editedAt]),
/// importing the file [pickFile] gives (by default none), its view kept
/// in [kept] (by default the month).
CalendarEditorPart calendarPart(
  String text, {
  bool readOnly = false,
  DateTime Function()? now,
  PickCalendarFile? pickFile,
  KeptView? kept,
}) {
  final view = kept ?? KeptView();
  return CalendarEditorPart(
    (
      text: text,
      version: const Version(1),
      view: view.settings,
      readOnly: readOnly,
      isNew: false,
    ),
    view.page,
    pickFile: pickFile ?? () async => const Ok(null),
    now: now ?? () => editedAt,
    // Never fire: no file keeps the edits here.
    startTimer: ManualTimers().start,
  );
}

/// What a device keeps of how a calendar shows, as a test sets and reads
/// it: the file page's side of it.
final class KeptView {
  /// Kept as opening in [kind].
  KeptView([CalendarViewKind kind = CalendarViewKind.month])
    : settings = CalendarView(kind: kind).settings;

  ViewSettings settings;

  /// The view the calendar opens in, as kept now.
  CalendarViewKind get kind => CalendarView.of(settings).kind;

  /// The page, keeping what the part changes; it has its file.
  EditorPage get page => EditorPage(
    keepView: (change) => settings = change(settings),
    withFile: (_) async {},
  );
}

/// The file the test page shows.
final pageFolder = folderId('home');
final pagePath = path('a.ics');
final FileKey pageFile = (folder: pageFolder, path: pagePath);

/// Shows [part]'s calendar page as of [today] on a device in [deviceZone],
/// with its Add
/// button while it can be edited, its hints added to [hints], taking
/// what [starts] asks of it, with the file's menu; closes the part's editor once the test
/// ends.
Future<void> pumpPage(
  WidgetTester tester,
  CalendarEditorPart part, {
  required DateTime today,
  List<String>? hints,
  String? deviceZone,
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
    starts: starts ?? CalendarStarts(),
    now: () => today,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          // The file's menu, as the file page shows it.
          appBar: AppBar(
            actions: [
              PopupMenuButton<VoidCallback>(
                key: const Key('file menu'),
                onSelected: (action) => action(),
                itemBuilder: (context) => view.menu(context, ViewSettings.none),
              ),
            ],
          ),
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
