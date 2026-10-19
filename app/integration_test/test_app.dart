import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/platform/folder_picker.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/refresh_settings_store.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// The real app on fresh temp storage, with a folder picker that returns
/// [notes] instead of opening the system dialog.
final class TestApp {
  TestApp._(this.notes, this._storage);

  /// Creates the temp folders; both are deleted after the test.
  factory TestApp.create() {
    final root = Directory.systemTemp.createTempSync('truce_ui_test');
    addTearDown(() => root.deleteSync(recursive: true));
    final notes = Directory('${root.path}/Notes')..createSync();
    return TestApp._(notes, AppStorage('${root.path}/app'));
  }

  /// The folder the picker hands to the app.
  final Directory notes;
  final AppStorage _storage;

  Future<void> launch(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(_storage),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        systemTrayProvider.overrideWithValue(null),
        folderPickerProvider.overrideWithValue(_FixedPicker(notes.path)),
      ],
      child: const TruceApp(),
    ),
  );

  /// Starts the app with [mode] as the refresh setting, e.g. manual for
  /// tests of what refreshes without live updates.
  Future<void> useRefresh(RefreshMode mode) =>
      RefreshSettingsStore(File('${_storage.settingsPath}/refresh.json'))
          .save(RefreshSettings.standard.copyWith(mode: mode));

  /// [name] may lead through subfolders; [write] creates them.
  File file(String name) => File('${notes.path}/$name');

  /// Writes [text] to [name], creating its subfolders.
  void write(String name, String text) =>
      file(name)..writeCreatingFolders(text);

  /// [name] may lead through subfolders.
  Directory folder(String name) => Directory('${notes.path}/$name');

  /// The files at the top of the notes folder.
  Iterable<File> get topFiles => notes.listSync().whereType<File>();

  /// The names of what [name] holds, files and folders; the notes folder
  /// itself if [name] is empty.
  List<String> namesIn([String name = '']) => [
    for (final entry in folder(name).listSync()) entry.uri.pathSegments.last,
  ];

  /// The sync conflict copies in [name], or in the notes folder itself.
  List<File> conflictCopies([String name = '']) => [
    for (final file in folder(name).listSync().whereType<File>())
      if (file.path.contains('.sync-conflict-')) file,
  ];
}

final class _FixedPicker implements FolderPicker {
  const _FixedPicker(this._path);

  final String _path;

  @override
  Future<Result<String?, PickError>> pick() async => Ok(_path);
}

/// A test of the app, [body]; then takes the app down and runs one more
/// frame, for the work widgets schedule as they go (the editor lets go of
/// the keyboard a frame later), before Flutter checks that none is left.
void testApp(String description, WidgetTesterCallback body) =>
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
