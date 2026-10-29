import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/add_folder/add_folder_flow.dart';
import 'package:truce_editor/folders/add_folder/add_folder_wiring.dart';
import 'package:truce_editor/folders/add_folder/ui/add_folder_screen.dart';
import 'package:truce_editor/folders/base_folder.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_error.dart';
import 'package:truce_editor/folders/folder_list_contract.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/folder_picker.dart';
import 'package:truce_test_support/truce_test_support.dart' show FakeSyncTool;

import '../../../support.dart';

void main() {
  final picked = Uri.parse('fake://host/sync');
  late List<({Uri address, String toolId, Selection selection})> added;
  late Result<DocumentFolder, FolderError> answer;
  late FakeSyncTool syncthing;
  late FakeSyncTool plain;

  setUp(() {
    added = [];
    answer = const Err(FolderError.notSaved);
    syncthing = FakeSyncTool('syncthing');
    plain = FakeSyncTool('plain');
    for (final tool in [syncthing, plain]) {
      tool.place(picked).files.emptyFolders.addAll([
        path('home'),
        path('notes/work'),
      ]);
    }
  });

  /// Opens the screen over a home page, with [folders] added before; the
  /// picker picks `fake://host/sync`, which no tool recognizes.
  Future<void> open(
    WidgetTester tester, {
    List<DocumentFolder> folders = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foldersProvider.overrideWith(() => _Folders(folders)),
          folderPickerProvider.overrideWithValue(_Picker(picked)),
          addFolderWorkProvider.overrideWith(
            (ref) => AddFolderWork(
              tools: [syncthing, plain],
              subfoldersOf: (base) => syncthing.place(base.address).subfolders,
              add:
                  ({
                    required address,
                    required toolId,
                    required selection,
                    required name,
                    required color,
                  }) async {
                    added.add((
                      address: address,
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
                ref.watch(loadedFoldersProvider).hasValue ? 'home' : 'loading',
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
    await tester.tap(find.text('Fake plain'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds the subfolders picked, named after the one', (
    tester,
  ) async {
    answer = Ok(folderAt(tempFolder()));
    await open(tester);

    await tester.tap(find.text('Pick a folder'));
    await tester.pumpAndSettle();
    expect(find.text('How is fake://host/sync synced?'), findsOne);
    expect(find.text('Fake syncthing'), findsOne);
    await tester.tap(find.text('Fake plain'));
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
      address: picked,
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
    final base = BaseFolder(id: 'b1', address: picked, toolId: syncthing.id);
    await open(
      tester,
      folders: [
        DocumentFolder(
          id: 'f1',
          base: base,
          selection: Selection.of([path('notes/work')]),
          name: 'Work',
          color: Colors.teal,
        ),
      ],
    );

    await tester.tap(find.text(base.shownAddress));
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
  FolderListState build() => FoldersLoaded(folders);
}

final class _Picker implements FolderPicker {
  const _Picker(this.address);

  final Uri address;

  @override
  Future<Result<Uri?, PickError>> pick() async => Ok(address);
}
