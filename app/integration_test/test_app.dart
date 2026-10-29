import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/platform/folder_picker.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'ui_driver.dart';

/// The real app on fresh temp storage, with a folder picker that returns
/// [documents], then [work], instead of opening the system dialog.
final class TestApp {
  TestApp._(this.documents, this.work, this._storage);

  /// Creates the temp folders; both are deleted after the test.
  factory TestApp.create() {
    final root = Directory.systemTemp.createTempSync('truce_ui_test');
    addTearDown(() => root.deleteSync(recursive: true));
    final documents = Directory('${root.path}/Documents')..createSync();
    final work = Directory('${root.path}/Work')..createSync();
    return TestApp._(documents, work, AppStorage('${root.path}/app'));
  }

  /// The folder the picker hands to the app.
  final Directory documents;

  /// The folder the picker hands to the app the second time.
  final Directory work;

  final AppStorage _storage;

  /// Starts the app, with the locale data and device settings that `main`
  /// loads.
  Future<void> launch(WidgetTester tester) async {
    await initializeDateFormatting();
    final settings = await deviceSettingsStoreIn(_storage).load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStorageProvider.overrideWithValue(_storage),
          deviceIdProvider.overrideWithValue('0123456789abcdef'),
          loadedDeviceSettingsProvider.overrideWithValue(settings),
          systemTrayProvider.overrideWithValue(null),
          folderPickerProvider.overrideWithValue(
            _QueuedPicker([documents.path, work.path]),
          ),
        ],
        child: const TruceApp(),
      ),
    );
  }

  /// Starts the app with [mode] as the refresh setting, e.g. manual for
  /// tests of what refreshes without live updates.
  Future<void> useRefresh(RefreshMode mode) => _useSettings(
    (settings) => settings.copyWith(
      refresh: RefreshSettings.standard.copyWith(mode: mode),
    ),
  );

  /// Starts the app with [zoom] saved for [target].
  Future<void> useTextZoom(TextZoomTarget target, TextZoom zoom) =>
      _useSettings((settings) => settings.withTextZoom(target, zoom));

  /// Starts the app with the saved device settings changed by [change].
  Future<void> _useSettings(
    DeviceSettings Function(DeviceSettings settings) change,
  ) async {
    final store = deviceSettingsStoreIn(_storage);
    await store.save(change(await store.load()));
  }

  /// Starts the app with a saved folder list it can't read.
  void damageFolderList() =>
      File('${_storage.settingsPath}/folder_list.json')
          .writeCreatingFolders('{"broken": true}');

  /// [name] may lead through subfolders; [write] creates them.
  File file(String name) => File('${documents.path}/$name');

  /// Writes [text] to [name], creating its subfolders.
  void write(String name, String text) =>
      file(name)..writeCreatingFolders(text);

  /// [name] may lead through subfolders.
  Directory folder(String name) => Directory('${documents.path}/$name');

  /// The files at the top of the documents folder.
  Iterable<File> get topFiles => documents.listSync().whereType<File>();

  /// The names of what [name] holds, files and folders; the documents folder
  /// itself if [name] is empty.
  List<String> namesIn([String name = '']) => [
    for (final entry in folder(name).listSync()) entry.uri.pathSegments.last,
  ];

  /// The sync conflict copies in [name], or in the documents folder itself.
  List<File> conflictCopies([String name = '']) => [
    for (final file in folder(name).listSync().whereType<File>())
      if (file.path.contains('.sync-conflict-')) file,
  ];
}

/// Picks [_paths] in turn, then the last one again.
final class _QueuedPicker implements FolderPicker {
  _QueuedPicker(this._paths);

  final List<String> _paths;
  int _picks = 0;

  @override
  Future<Result<Uri?, PickError>> pick() async =>
      Ok(Uri.file(_paths[min(_picks++, _paths.length - 1)]));
}

/// A test of the app, [body]; then closes the screens still open and
/// lets a closed document finish its last steps (its file written, its
/// draft dropped) before the app goes. The screens are popped, not left
/// the user's way, as that may ask the user (e.g. to discard edits). A
/// closed document's last steps are file work no widget shows, so the
/// app runs a set time for them. One more frame runs for the work
/// widgets schedule as they go (the editor lets go of the keyboard a
/// frame later), before Flutter checks that none is left.
void testApp(String description, WidgetTesterCallback body) =>
    testWidgets(description, (tester) async {
      await body(tester);
      final navigator = find.byType(Navigator);
      if (navigator.evaluate().isNotEmpty) {
        tester
            .state<NavigatorState>(navigator.first)
            .popUntil((route) => route.isFirst);
      }
      await tester.runFor(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
