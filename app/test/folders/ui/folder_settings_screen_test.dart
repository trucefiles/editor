import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/open_folders_wiring.dart';
import 'package:truce_editor/folders/ui/folder_settings_screen.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../support.dart';

void main() {
  late Folder folder;
  late _Folders folders;
  late ProviderContainer container;

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
          appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
          loadedDeviceSettingsProvider.overrideWithValue(
            DeviceSettings.standard,
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
    container = ProviderScope.containerOf(tester.element(find.text('home')));
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

  testWidgets('Enter in the name saves, as Save does', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(folders.changed.single.name, 'Work');
    expect(find.byType(FolderSettingsScreen), findsNothing);
  });

  testWidgets("switching the folder's images out of Recently edited takes "
      'effect at once, with nothing to save', (tester) async {
    await open(tester);
    final images = find.widgetWithText(
      SwitchListTile,
      'Show images in Recently edited',
    );
    expect(tester.widget<SwitchListTile>(images).value, isTrue);

    await tester.runAsync(() async {
      await tester.tap(images);
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(images).value, isFalse);
    expect(
      container
          .read(deviceSettingsProvider)
          .requireValue
          .home
          .showsUneditedOf(folder.id),
      isFalse,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(FolderSettingsScreen), findsNothing);
  });

  testWidgets('leaving with nothing changed asks nothing', (tester) async {
    await open(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(FolderSettingsScreen), findsNothing);
  });

  testWidgets('leaving with a changed name asks first; Keep editing stays, '
      'Discard leaves without saving', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Work');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOne);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderSettingsScreen), findsOne);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderSettingsScreen), findsNothing);
    expect(folders.changed, isEmpty);
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
