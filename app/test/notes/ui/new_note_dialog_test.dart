import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/ui/new_note_dialog.dart';

import '../../support.dart';

void main() {
  final notes = folderAt(Directory('/notes'));
  final work = folderAt(Directory('/work'), id: 'f2');

  /// Opens the dialog; the returned future completes with its result.
  Future<Future<NewNoteInput?>> open(
    WidgetTester tester,
    Map<NoteFolder, List<RelPath>> subfolders,
  ) async {
    late Future<NewNoteInput?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showNewNoteDialog(
              context,
              folders: [notes, work],
              initial: notes,
              subfoldersOf: (folder) => subfolders[folder] ?? const [],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('creates at the top level by default', (tester) async {
    final result = await open(tester, {
      notes: [path('a'), path('a/b')],
    });

    await tester.enterText(find.byType(TextField), 'Plan');
    await tester.tap(find.text('Create'));

    expect(await result, (title: 'Plan', folder: notes, subfolder: null));
  });

  testWidgets('creates in the chosen subfolder', (tester) async {
    final result = await open(tester, {
      notes: [path('a'), path('a/b')],
    });

    await tester.enterText(find.byType(TextField), 'Plan');
    await tester.tap(find.text('Top level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a/b').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));

    expect(await result, (
      title: 'Plan',
      folder: notes,
      subfolder: path('a/b'),
    ));
  });

  testWidgets('offers no subfolders for a folder without any', (tester) async {
    await open(tester, {
      work: [path('x')],
    });

    expect(find.text('Subfolder'), findsNothing);
  });
}
