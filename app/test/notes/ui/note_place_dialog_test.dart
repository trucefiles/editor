import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note_place.dart';
import 'package:truce_editor/notes/ui/note_place_dialog.dart';

import '../../support.dart';

void main() {
  final notes = folderAt(Directory('/notes'));
  final work = folderAt(Directory('/work'), id: 'f2');

  /// Opens the dialog at [initial]; the returned future completes with its
  /// result.
  Future<Future<NotePlace?>> open(
    WidgetTester tester,
    Map<NoteFolder, List<RelPath>> subfolders, {
    NotePlace? initial,
  }) async {
    late Future<NotePlace?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showNotePlaceDialog(
              context,
              title: 'Move note',
              action: 'Move',
              folders: [notes, work],
              initial: initial ?? (folder: notes, subfolder: null),
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

  testWidgets('keeps the initial place by default', (tester) async {
    final result = await open(
      tester,
      {
        notes: [path('a'), path('a/b')],
      },
      initial: (folder: notes, subfolder: path('a')),
    );

    await tester.tap(find.text('Move'));

    expect(await result, (folder: notes, subfolder: path('a')));
  });

  testWidgets('picks the chosen subfolder', (tester) async {
    final result = await open(tester, {
      notes: [path('a'), path('a/b')],
    });

    await tester.tap(find.text('Top level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a/b').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));

    expect(await result, (folder: notes, subfolder: path('a/b')));
  });

  testWidgets('a subfolder that is gone starts at the top level', (
    tester,
  ) async {
    final result = await open(
      tester,
      {
        notes: [path('a')],
      },
      initial: (folder: notes, subfolder: path('gone')),
    );

    await tester.tap(find.text('Move'));

    expect(await result, (folder: notes, subfolder: null));
  });

  testWidgets('offers no subfolders for a folder without any', (tester) async {
    await open(tester, {
      work: [path('x')],
    });

    expect(find.text('Subfolder'), findsNothing);
  });

  testWidgets('cancel picks nothing', (tester) async {
    final result = await open(tester, const {});

    await tester.tap(find.text('Cancel'));

    expect(await result, isNull);
  });
}
