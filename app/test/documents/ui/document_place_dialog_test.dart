import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document_place.dart';
import 'package:truce_editor/documents/ui/document_place_dialog.dart';
import 'package:truce_editor/folders/document_folder.dart';

import '../../support.dart';

void main() {
  final documents = folderAt(Directory('/documents'));
  final work = folderAt(Directory('/work'), id: 'f2');

  /// Opens the dialog at [initial]; the returned future completes with its
  /// result.
  Future<Future<DocumentPlace?>> open(
    WidgetTester tester,
    Map<DocumentFolder, List<RelPath>> subfolders, {
    DocumentPlace? initial,
  }) async {
    late Future<DocumentPlace?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showNotePlaceDialog(
              context,
              title: 'Move document',
              action: 'Move',
              folders: [documents, work],
              initial: initial ?? (folder: documents, subfolder: null),
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
        documents: [path('a'), path('a/b')],
      },
      initial: (folder: documents, subfolder: path('a')),
    );

    await tester.tap(find.text('Move'));

    expect(await result, (folder: documents, subfolder: path('a')));
  });

  testWidgets('picks the chosen subfolder', (tester) async {
    final result = await open(tester, {
      documents: [path('a'), path('a/b')],
    });

    await tester.tap(find.text('Top level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a/b').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));

    expect(await result, (folder: documents, subfolder: path('a/b')));
  });

  testWidgets('a subfolder that is gone starts at the top level', (
    tester,
  ) async {
    final result = await open(
      tester,
      {
        documents: [path('a')],
      },
      initial: (folder: documents, subfolder: path('gone')),
    );

    await tester.tap(find.text('Move'));

    expect(await result, (folder: documents, subfolder: null));
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

  testWidgets('with a name, asks for it too', (tester) async {
    late Future<({DocumentPlace place, String name})?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showNoteFileDialog(
              context,
              folders: [documents, work],
              initial: (folder: documents, subfolder: null),
              name: 'Milk',
              subfoldersOf: (_) => const [],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Milk'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Shopping');
    await tester.tap(find.text('OK'));

    expect(await result, (
      place: (folder: documents, subfolder: null),
      name: 'Shopping',
    ));
  });

  testWidgets('without a name, asks for none', (tester) async {
    await open(tester, const {});

    expect(find.byType(TextField), findsNothing);
  });
}
