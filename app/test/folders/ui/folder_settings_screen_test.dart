import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_error.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/ui/folder_settings_screen.dart';
import 'package:truce_editor/sync_tool/base_folder_services.dart';

import '../../support.dart';

void main() {
  final folder = folderAt(
    Directory('/sync'),
    selection: Selection.of([path('notes')]),
  );
  final other = folderAt(
    Directory('/sync'),
    id: 'f2',
    baseId: folder.base.id,
    selection: Selection.of([path('home')]),
  );
  late _Folders folders;

  Future<void> open(
    WidgetTester tester, {
    DocumentFolder? shown,
    bool missesOldVersions = false,
  }) async {
    final opened = shown ?? folder;
    folders = _Folders([opened, other]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foldersProvider.overrideWith(() => folders),
          subfolderNamesProvider.overrideWithValue(
            (_) => const _Names({
              null: ['home', 'notes', 'work'],
              'notes': ['deep'],
            }),
          ),
          folderNoticesProvider.overrideWith((ref, base) async => const []),
          missesOldVersionsProvider.overrideWith(
            (ref, base) async => missesOldVersions,
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FolderSettingsScreen(opened),
                ),
              ),
              child: Text(
                ref.watch(foldersProvider).hasValue ? 'home' : 'loading',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  Finder checkboxOf(String folder) => find.descendant(
    of: find.widgetWithText(ListTile, folder),
    matching: find.byType(Checkbox),
  );

  testWidgets('saves the name and what the folder shows', (tester) async {
    await open(tester);
    expect(find.text('Synced by: Syncthing'), findsOne);
    expect(tester.widget<Checkbox>(checkboxOf('notes')).value, isTrue);

    await tester.enterText(find.byType(TextField), ' Work ');
    await tester.tap(checkboxOf('work'));
    await tester.tap(checkboxOf('notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(folders.changed.single.name, 'Work');
    expect(folders.changed.single.selection, Selection.of([path('work')]));
    expect(find.byType(FolderSettingsScreen), findsNothing);
  });

  testWidgets('opens the folders on the way to a subfolder it shows', (
    tester,
  ) async {
    await open(
      tester,
      shown: folder.copyWith(selection: Selection.of([path('notes/deep')])),
    );

    expect(tester.widget<Checkbox>(checkboxOf('deep')).value, isTrue);
  });

  testWidgets("another folder's part can't be picked, nor the whole", (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Another folder shows part of it.'), findsOne);
    expect(tester.widget<Checkbox>(checkboxOf('home')).onChanged, isNull);
  });

  testWidgets('can only save once something is shown', (tester) async {
    await open(tester);

    await tester.tap(checkboxOf('notes'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a refused change stays on the screen and says why', (
    tester,
  ) async {
    await open(tester);
    folders.answer = const Err(FolderError.overlaps);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('overlaps with a folder'), findsOne);
    expect(find.byType(FolderSettingsScreen), findsOne);
  });

  testWidgets('hints at the synced folder itself for more history', (
    tester,
  ) async {
    await open(tester, missesOldVersions: true);

    expect(
      find.text('Pick the Syncthing folder itself to get more history.'),
      findsOne,
    );
  });
}

/// The folders added, recording the changes asked for.
final class _Folders extends FoldersController {
  _Folders(this.folders);

  final List<DocumentFolder> folders;
  final changed = <DocumentFolder>[];
  Result<void, FolderError> answer = const Ok(null);

  @override
  Future<List<DocumentFolder>> build() async => folders;

  @override
  Future<Result<void, FolderError>> change(DocumentFolder changed) async {
    this.changed.add(changed);
    return answer;
  }
}

/// Folder names by the path of their parent (`null` for the top).
final class _Names implements SubfolderNames {
  const _Names(this.byParent);

  final Map<String?, List<String>> byParent;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async =>
      Ok(byParent[folder?.value] ?? const []);
}
