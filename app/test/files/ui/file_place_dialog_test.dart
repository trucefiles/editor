import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/files/ui/file_place_dialog.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../support.dart';

void main() {
  final files = folderAt(Directory('/documents'));
  final work = folderAt(Directory('/work'), id: 'f2');

  /// Opens the dialog at [initial]; the returned future completes with its
  /// result.
  Future<Future<FilePlace?>> open(
    WidgetTester tester,
    Map<Folder, List<RelPath>> subfolders, {
    FilePlace? initial,
  }) async {
    late Future<FilePlace?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showFilePlaceDialog(
              context,
              title: 'Move document',
              action: 'Move',
              folders: [files, work],
              initial: initial ?? (folder: files, subfolder: null),
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
        files: [path('a'), path('a/b')],
      },
      initial: (folder: files, subfolder: path('a')),
    );

    await tester.tap(find.text('Move'));

    expect(await result, (folder: files, subfolder: path('a')));
  });

  testWidgets('picks the chosen subfolder', (tester) async {
    final result = await open(tester, {
      files: [path('a'), path('a/b')],
    });

    await tester.tap(find.text('Top level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('a/b').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));

    expect(await result, (folder: files, subfolder: path('a/b')));
  });

  testWidgets('a subfolder that is gone starts at the top level', (
    tester,
  ) async {
    final result = await open(
      tester,
      {
        files: [path('a')],
      },
      initial: (folder: files, subfolder: path('gone')),
    );

    await tester.tap(find.text('Move'));

    expect(await result, (folder: files, subfolder: null));
  });

  testWidgets('offers no subfolders for a folder without any', (tester) async {
    await open(tester, {
      work: [path('x')],
    });

    expect(find.text('Inside the folder'), findsNothing);
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
            onPressed: () => result = showFileNameDialog(
              context,
              folders: [files, work],
              initial: (folder: files, subfolder: null),
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
      place: (folder: files, subfolder: null),
      name: 'Shopping',
      newSubfolder: false,
    ));
  });

  testWidgets('without a name, asks for none', (tester) async {
    await open(tester, const {});

    expect(find.byType(TextField), findsNothing);
  });

  group('with a name, takes a typed subfolder', () {
    /// Opens the file dialog on [folder], whose files can go only into
    /// `work` and below, or where [canHold] says; the returned future
    /// completes with its result.
    Future<Future<PickedPlace?>> openFile(
      WidgetTester tester,
      Folder folder, {
      bool Function(Folder folder, RelPath subfolder)? canHold,
    }) async {
      late Future<PickedPlace?> result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showFileNameDialog(
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
      final result = await openFile(tester, files);

      await tester.enterText(subfolderField(), 'work/2026');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: files, subfolder: path('work/2026')),
        name: 'Milk',
        newSubfolder: true,
      ));
    });

    testWidgets('none for the top level', (tester) async {
      final result = await openFile(tester, files);

      await tester.enterText(subfolderField(), '');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: files, subfolder: null),
        name: 'Milk',
        newSubfolder: false,
      ));
    });

    testWidgets('one offered, typed, is no new one', (tester) async {
      final result = await openFile(tester, files);

      await tester.enterText(subfolderField(), 'work');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: files, subfolder: path('work')),
        name: 'Milk',
        newSubfolder: false,
      ));
    });

    testWidgets('refuses one documents of the folder cannot go to', (
      tester,
    ) async {
      await openFile(tester, files);

      await tester.enterText(subfolderField(), 'home');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text("Files can't go in there."), findsOne);

      await tester.enterText(subfolderField(), '../up');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text("Files can't go in there."), findsOne);
      expect(find.byType(AlertDialog), findsOne);
    });

    testWidgets('takes a subfolder typed with a slash at its end', (
      tester,
    ) async {
      final result = await openFile(tester, files);

      await tester.enterText(subfolderField(), 'work/');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: files, subfolder: path('work')),
        name: 'Milk',
        newSubfolder: false,
      ));
    });

    testWidgets('the top level picked from the list is the top level', (
      tester,
    ) async {
      final result = await openFile(tester, files);

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
        place: (folder: files, subfolder: null),
        name: 'Milk',
        newSubfolder: false,
      ));
    });

    testWidgets("a subfolder typed with the top level's name is a "
        'subfolder', (tester) async {
      final result = await openFile(tester, files, canHold: (_, _) => true);

      await tester.enterText(subfolderField(), 'Top level');
      await tester.tap(find.text('OK'));

      expect(await result, (
        place: (folder: files, subfolder: path('Top level')),
        name: 'Milk',
        newSubfolder: true,
      ));
    });

    testWidgets('the error goes as the user types', (tester) async {
      await openFile(tester, files);
      await tester.enterText(subfolderField(), 'home');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.enterText(subfolderField(), 'work');
      await tester.pumpAndSettle();

      expect(find.text("Files can't go in there."), findsNothing);
    });
  });
}
