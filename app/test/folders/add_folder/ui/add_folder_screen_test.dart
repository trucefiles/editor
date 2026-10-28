import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/add_folder/add_folder_flow.dart';
import 'package:truce_editor/folders/add_folder/add_folder_wiring.dart';
import 'package:truce_editor/folders/add_folder/ui/add_folder_screen.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_error.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/folder_picker.dart';
import 'package:truce_editor/sync_tool/sync_tools.dart';
import 'package:truce_test_support/truce_test_support.dart'
    show FakeFolderMarkers;

import '../../../support.dart';

void main() {
  late List<({String basePath, String toolId, Selection selection})> added;
  late Result<DocumentFolder, FolderError> answer;

  setUp(() {
    added = [];
    answer = const Err(FolderError.notSaved);
  });

  /// Opens the screen over a home page, with [folders] added before; the
  /// picker picks `/sync`, which no tool recognizes.
  Future<void> open(
    WidgetTester tester, {
    List<DocumentFolder> folders = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foldersProvider.overrideWith(() => _Folders(folders)),
          folderPickerProvider.overrideWithValue(const _Picker('/sync')),
          addFolderWorkProvider.overrideWith(
            (ref) => AddFolderWork(
              tools: ref.watch(syncToolsProvider).all,
              markersOf: (_) => const FakeFolderMarkers([{}]),
              namesOf: (_) => const _Names({
                null: ['home', 'notes'],
                'notes': ['work'],
              }),
              isToolFolder: (_) => false,
              add:
                  ({
                    required basePath,
                    required toolId,
                    required selection,
                    required name,
                    required color,
                  }) async {
                    added.add((
                      basePath: basePath,
                      toolId: toolId,
                      selection: selection,
                    ));
                    return answer;
                  },
            ),
          ),
        ],
        child: MaterialApp(
          // Watches the folders, as the app has them loaded.
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AddFolderScreen(),
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

  Future<void> pickSyncFolder(WidgetTester tester) async {
    await tester.tap(find.text('Pick a folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plain folder'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds the subfolders picked, named after the one', (
    tester,
  ) async {
    answer = Ok(folderAt(tempFolder()));
    await open(tester);

    await tester.tap(find.text('Pick a folder'));
    await tester.pumpAndSettle();
    expect(find.text('How is /sync synced?'), findsOne);
    expect(find.text('Syncthing'), findsOne);
    await tester.tap(find.text('Plain folder'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('notes'));
    await tester.pumpAndSettle();
    await tester.tap(checkboxOf('work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'work'), findsOne);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(added.single, (
      basePath: '/sync',
      toolId: 'plain',
      selection: Selection.of([path('notes/work')]),
    ));
    expect(find.byType(AddFolderScreen), findsNothing);
  });

  testWidgets('a refused folder stays on the screen and says why', (
    tester,
  ) async {
    await open(tester);
    await pickSyncFolder(tester);
    await tester.tap(find.text('Whole folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('The folder list could not be saved.'), findsOne);
    expect(find.byType(AddFolderScreen), findsOne);
  });

  testWidgets('back goes one step back, then leaves', (tester) async {
    await open(tester);
    await pickSyncFolder(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pick a folder'), findsOne);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AddFolderScreen), findsNothing);
  });

  testWidgets('shows more of a folder added before, never what it shows', (
    tester,
  ) async {
    final before = folderAt(
      tempFolder(),
      selection: Selection.of([path('notes/work')]),
    );
    await open(tester, folders: [before]);

    await tester.tap(find.text(before.base.path));
    await tester.pumpAndSettle();
    await tester.tap(find.text('notes'));
    await tester.pumpAndSettle();

    expect(find.text('Another folder shows part of it.'), findsOne);
    expect(find.text('In another folder'), findsNWidgets(2));
    expect(tester.widget<Checkbox>(checkboxOf('home')).onChanged, isNotNull);
    expect(tester.widget<Checkbox>(checkboxOf('work')).onChanged, isNull);
  });
}

/// The folders added before.
final class _Folders extends FoldersController {
  _Folders(this.folders);

  final List<DocumentFolder> folders;

  @override
  Future<List<DocumentFolder>> build() async => folders;
}

final class _Picker implements FolderPicker {
  const _Picker(this.path);

  final String path;

  @override
  Future<Result<String?, PickError>> pick() async => Ok(path);
}

/// Folder names by the path of their parent (`null` for the top).
final class _Names implements SubfolderNames {
  const _Names(this.byParent);

  final Map<String?, List<String>> byParent;

  @override
  Future<Result<List<String>, StoreError>> namesIn(RelPath? folder) async =>
      Ok(byParent[folder?.value] ?? const []);
}
