import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/platform/folder_picker.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';
import 'package:truce_editor/text_zoom/text_zoom_target.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'ui_driver.dart';

/// The real app on fresh temp storage, with a folder picker that returns
/// [files], then [work], instead of opening the system dialog.
final class TestApp {
  TestApp._(this.files, this.work, this._storage);

  /// Creates the temp folders; both are deleted after the test.
  factory TestApp.create() {
    final root = Directory.systemTemp.createTempSync('truce_ui_test');
    addTearDown(() => root.deleteSync(recursive: true));
    final files = _syncthingFolder('${root.path}/Documents');
    final work = _syncthingFolder('${root.path}/Work');
    return TestApp._(files, work, AppStorage('${root.path}/app'));
  }

  /// A directory Syncthing syncs, as its marker folder tells.
  static Directory _syncthingFolder(String path) {
    Directory('$path/.stfolder').createSync(recursive: true);
    return Directory(path);
  }

  /// The folder the picker hands to the app.
  final Directory files;

  /// The folder the picker hands to the app the second time.
  final Directory work;

  /// The folders the picker hands to the app next, in turn; the last
  /// one again and again.
  late final picks = [files, work];

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
          folderPickerProvider.overrideWithValue(_QueuedPicker(picks)),
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
      File('${_storage.settingsPath}/folders.json')
          .writeCreatingFolders('{"broken": true}');

  /// [name] may lead through subfolders; [write] creates them.
  File file(String name) => File('${files.path}/$name');

  /// Writes [text] to [name], creating its subfolders.
  void write(String name, String text) =>
      file(name)..writeCreatingFolders(text);

  /// Writes a one pixel high picture [width] pixels wide (1 or 2) to
  /// [name], creating its subfolders; pictures differ by their width.
  void writePicture(String name, {required int width}) {
    final file = this.file(name)..parent.createSync(recursive: true);
    file.writeAsBytesSync(base64.decode(_pictures[width]!));
  }

  /// [name] may lead through subfolders.
  Directory folder(String name) => Directory('${files.path}/$name');

  /// The files at the top of the documents folder.
  Iterable<File> get topFiles => files.listSync().whereType<File>();

  /// The names of what [name] holds, files and folders; the documents folder
  /// itself if [name] is empty. Without Syncthing's marker folder.
  List<String> namesIn([String name = '']) => [
    for (final entry in folder(name).listSync())
      if (entry.path.split('/').last case final entryName
          when entryName != '.stfolder')
        entryName,
  ];

  /// The sync conflict copies in [name], or in the documents folder itself.
  List<File> conflictCopies([String name = '']) => [
    for (final file in folder(name).listSync().whereType<File>())
      if (file.path.contains('.sync-conflict-')) file,
  ];
}

/// PNG pictures one pixel high, by their width.
const _pictures = {
  1:
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ'
      '/pLvAAAAAElFTkSuQmCC',
  2:
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4z8AARAAI/gH/'
      'xp559wAAAABJRU5ErkJggg==',
};

/// Picks [_paths] in turn, then the last one again.
final class _QueuedPicker implements FolderPicker {
  _QueuedPicker(this._picks);

  final List<Directory> _picks;

  @override
  Future<Result<Uri?, PickError>> pick() async => Ok(
    Uri.file((_picks.length > 1 ? _picks.removeAt(0) : _picks.single).path),
  );
}

/// A test of the app, [body]; then closes the screens still open and
/// lets a closed file finish its last steps (its file written, its
/// draft dropped) before the app goes. The screens are popped, not left
/// the user's way, as that may ask the user (e.g. to discard edits). A
/// closed file's last steps are file work no widget shows, so the
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
