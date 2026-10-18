import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';
import 'package:truce_editor/notes/open_note.dart';
import 'package:truce_editor/notes/ui/edit_state_banner.dart';

import '../../support.dart';

void main() {
  late Note note;
  late NoteEditSession session;

  Note version(String text, int number) => Note(
    folder: note.folder,
    path: note.path,
    file: TextFile.decode(Uint8List.fromList(utf8.encode(text)))!,
    version: FileVersion(number),
    modified: DateTime(2026, 10, 15),
  );

  /// A session with unsaved edits and a change from elsewhere, all in
  /// memory: the long save delay keeps the edits off the disk.
  setUp(() {
    final folder = folderAt(tempFolder());
    final files = NoteFiles(folder, servicesFor(folder));
    note = Note(
      folder: folder,
      path: path('a.md'),
      file: TextFile.decode(Uint8List.fromList(utf8.encode('# a')))!,
      version: const FileVersion(1),
      modified: DateTime(2026, 10, 14),
    );
    session = NoteEditSession(
      note,
      files,
      tempDrafts(),
      saveDelay: const Duration(hours: 1),
    );
    addTearDown(session.dispose);
    session
      ..edit('# a\nmine')
      ..onRescan(version('# a\ntheirs', 2), scannedAt: Moment.now());
  });

  Future<void> pumpBanner(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: session,
            builder: (_, _) => EditStateBanner(
              OpenNote(session, sessionOf: (_) => throw UnimplementedError()),
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
  }

  testWidgets('a change from elsewhere opens both versions', (tester) async {
    await pumpBanner(tester);

    expect(find.text('Current version'), findsOneWidget);
    expect(find.text('Your edits'), findsOneWidget);
    expect(find.textContaining('mine'), findsOneWidget);
    expect(find.textContaining('theirs'), findsOneWidget);
  });

  testWidgets('keeping the current version closes the comparison', (
    tester,
  ) async {
    await pumpBanner(tester);

    await tester.tap(find.text('Keep this').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    // The backup is written outside the test's fake time.
    for (var step = 0; step < 100 && session.text != '# a\ntheirs'; step++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(session.text, '# a\ntheirs');
    expect(find.text('Your edits'), findsNothing);
    expect(find.text('Compare'), findsNothing);
  });

  testWidgets('keeps both while the user cancels', (tester) async {
    await pumpBanner(tester);

    await tester.tap(find.text('Keep this').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('A backup of both stays'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(session.state, EditState.changedElsewhere);
    expect(find.text('Your edits'), findsOneWidget);
  });

  testWidgets('settled under the dialog: closes itself, not the dialog', (
    tester,
  ) async {
    await pumpBanner(tester);
    await tester.tap(find.text('Keep this').first);
    await tester.pumpAndSettle();

    session.onRescan(version('# a\nmine', 4), scannedAt: Moment.now());
    await tester.pumpAndSettle();
    expect(find.text('Your edits'), findsNothing);
    expect(find.text('Keep this version?'), findsOneWidget);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    // The choice was settled meanwhile: the late tap changes nothing.
    expect(session.text, '# a\nmine');
    expect(session.state, EditState.saved);
  });

  testWidgets('a newer version under the dialog is never overwritten', (
    tester,
  ) async {
    await pumpBanner(tester);
    await tester.tap(find.text('Keep this').last);
    await tester.pumpAndSettle();

    session.onRescan(version('# a\ntheirs, newer', 3), scannedAt: Moment.now());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();

    expect(find.textContaining('changed again'), findsOneWidget);
    expect(session.state, EditState.changedElsewhere);
    expect(session.theirs?.file.text, '# a\ntheirs, newer');
  });

  testWidgets('shows a newer version from elsewhere', (tester) async {
    await pumpBanner(tester);

    session.onRescan(version('# a\ntheirs, newer', 3), scannedAt: Moment.now());
    await tester.pumpAndSettle();

    expect(find.textContaining('theirs, newer'), findsOneWidget);
  });

  testWidgets('closes once settled elsewhere', (tester) async {
    await pumpBanner(tester);

    // The file now holds the edits: nothing left to choose.
    session.onRescan(version('# a\nmine', 4), scannedAt: Moment.now());
    await tester.pumpAndSettle();

    expect(find.text('Your edits'), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
