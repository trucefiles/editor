import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_editor/documents/ui/document_place_dialog.dart';
import 'package:truce_folders/truce_folders.dart';

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
            onPressed: () => result = showDocumentPlaceDialog(
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
    late Future<PickedPlace?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showDocumentFileDialog(
              context,
              folders: [documents, work],
              initial: (folder: documents, subfolder: null),
              name: 'Milk',
              subfoldersOf: (_) => const [],
              canHold: (_, _) => true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Milk'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Milk'), 'Shopping');
    await tester.tap(find.text('OK'));

    expect(await result, (
      place: (folder: documents, subfolder: null),
      name: 'Shopping',
      newSubfolder: false,
    ));
  });

  testWidgets('without a name, asks for none', (tester) async {
    await open(tester, const {});

    expect(find.byType(TextField), findsNothing);
  });

  group('with a name, takes a typed subfolder', () {
    /// Opens the file dialog on [folder], whose documents can go only into
    /// `work` and below, or where [canHold] says; the returned future
    /// completes with its result.
    Future<Future<PickedPlace?>> openFile(
      WidgetTester tester,
      DocumentFolder folder, {
      bool Function(DocumentFolder folder, RelPath subfolder)? canHold,
    }) async {
      late Future<PickedPlace?> result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showDocumentFileDialog(
                context,
                folders: [folder],
                initial: topOf(folder),
                name: 'Milk',
                subfoldersOf: (_) => [path('work')],
                canHold:
                    canHold ??
                    (_, subfolder) => subfolder.value.startsWith('work'),
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

    Finder subfolderField() => find.descendant(
      of: find.byType(DropdownMenu<String>),
      matching: find.byType(TextField),
    );

    testWidgets('a new one inside the folder', (tester) async {
      final result = await openFile(tester, documents);

      await tester.enterText(subfolderField(), 'work/2026');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: documents, subfolder: path('work/2026')),
        name: 'Milk',
        newSubfolder: true,
      ));
    });

    testWidgets('none for the top level', (tester) async {
      final result = await openFile(tester, documents);

      await tester.enterText(subfolderField(), '');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: documents, subfolder: null),
        name: 'Milk',
        newSubfolder: false,
      ));
    });

    testWidgets('one offered, typed, is no new one', (tester) async {
      final result = await openFile(tester, documents);

      await tester.enterText(subfolderField(), 'work');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: documents, subfolder: path('work')),
        name: 'Milk',
        newSubfolder: false,
      ));
    });

    testWidgets('refuses one documents of the folder cannot go to', (
      tester,
    ) async {
      await openFile(tester, documents);

      await tester.enterText(subfolderField(), 'home');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text("Documents of this folder can't go there."), findsOne);

      await tester.enterText(subfolderField(), '../up');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text("Documents of this folder can't go there."), findsOne);
      expect(find.byType(AlertDialog), findsOne);
    });

    testWidgets('takes a subfolder typed with a slash at its end', (
      tester,
    ) async {
      final result = await openFile(tester, documents);

      await tester.enterText(subfolderField(), 'work/');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: documents, subfolder: path('work')),
        name: 'Milk',
        newSubfolder: false,
      ));
    });

    testWidgets('the top level picked from the list is the top level', (
      tester,
    ) async {
      final result = await openFile(tester, documents);

      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Top level'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(subfolderField()).controller!.text,
        'Top level',
      );
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: documents, subfolder: null),
        name: 'Milk',
        newSubfolder: false,
      ));
    });

    testWidgets("a subfolder typed with the top level's name is a "
        'subfolder', (tester) async {
      final result = await openFile(tester, documents, canHold: (_, _) => true);

      await tester.enterText(subfolderField(), 'Top level');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: documents, subfolder: path('Top level')),
        name: 'Milk',
        newSubfolder: true,
      ));
    });

    testWidgets('the error goes as the user types', (tester) async {
      await openFile(tester, documents);
      await tester.enterText(subfolderField(), 'home');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.enterText(subfolderField(), 'work');
      await tester.pumpAndSettle();

      expect(
        find.text("Documents of this folder can't go there."),
        findsNothing,
      );
    });

    testWidgets('a folder of some subfolders has no top level', (tester) async {
      await openFile(
        tester,
        folderAt(Directory('/w'), selection: Selection.of([path('work')])),
      );

      await tester.enterText(subfolderField(), '');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Pick or type a subfolder.'), findsOne);
    });
  });
}
