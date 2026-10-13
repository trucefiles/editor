import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/app.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/platform/folder_picker.dart';

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
        folderPickerProvider.overrideWithValue(_FixedPicker(notes.path)),
      ],
      child: const TruceApp(),
    ),
  );

  File file(String name) => File('${notes.path}/$name');
}

final class _FixedPicker implements FolderPicker {
  const _FixedPicker(this._path);

  final String _path;

  @override
  Future<Result<String?, PickError>> pick() async => Ok(_path);
}
