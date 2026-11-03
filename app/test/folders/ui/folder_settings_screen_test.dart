import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/open_folders_wiring.dart';
import 'package:truce_editor/folders/ui/folder_settings_screen.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../support.dart';

void main() {
  late Folder folder;
  late _Folders folders;

  Future<void> open(WidgetTester tester) async {
    folder = folderAt(tempFolder());
    folders = _Folders([folder]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foldersProvider.overrideWith(() => folders),
          folderNoticesProvider.overrideWith(
            (ref, _) async => const <FolderNotice>[],
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FolderSettingsScreen(folder),
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

  testWidgets('shows where the folder is and its kind', (tester) async {
    await open(tester);

    expect(find.text(folder.location), findsOne);
    expect(find.text('Syncthing: Folders synced with Syncthing'), findsOne);
  });

  testWidgets('saves the name', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), ' Work ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(folders.changed.single.name, 'Work');
    expect(find.byType(FolderSettingsScreen), findsNothing);
  });

  testWidgets('a blank name can not be saved', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

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
    folders.answer = const Err(FolderError.notSaved);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save the folder list, so nothing changed."),
      findsOne,
    );
    expect(find.byType(FolderSettingsScreen), findsOne);
  });
}

/// The folders added, recording the changes asked for.
final class _Folders extends FoldersController {
  _Folders(this.folders);

  final List<Folder> folders;
  final changed = <Folder>[];
  Result<void, FolderError> answer = const Ok(null);

  @override
  Future<List<Folder>> build() async => folders;

  @override
  Future<Result<void, FolderError>> change(Folder changed) async {
    this.changed.add(changed);
    return answer;
  }
}
