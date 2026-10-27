import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/document_page/ui/document_screen.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

import 'test_app.dart';
import 'ui_driver.dart';

const savedOnDevice = 'Saved on this device. Tap to save in the folder now';
const placeAndName = 'Place and name';

/// The steps a user takes in the app, shared by the UI tests.
extension AppSteps on WidgetTester {
  /// Launches [app] and adds its documents folder.
  Future<void> addFolder(TestApp app) async {
    await app.launch(this);
    await waitFor(find.text('Add folder'));
    await tapAndSettle(find.text('Add folder'));
    await waitUntil(() => find.text('Add folder').evaluate().isEmpty);
  }

  /// Opens the document titled [title] from the grid.
  Future<void> openNote(String title) async {
    await waitFor(find.text(title));
    await tapAndSettle(find.text(title));
  }

  /// Waits until the open document has closed.
  Future<void> waitForNoteClosed({
    Duration timeout = const Duration(seconds: 15),
  }) => waitUntil(
    () => find.byType(DocumentScreen).evaluate().isEmpty,
    timeout: timeout,
  );

  /// Switches the open document to the mode labeled [mode], e.g. 'Read'.
  Future<void> chooseMode(String mode) async {
    await tapAndSettle(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton<EditMode>),
    );
    await tapAndSettle(find.text(mode).last);
  }

  /// Types [text] over the open document's whole text, in Markdown edit.
  Future<void> typeOver(String text) async {
    if (find.byTooltip('Mode: Markdown edit').evaluate().isEmpty) {
      await chooseMode('Markdown edit');
    }
    await tapAndSettle(find.byType(SuperEditor));
    await pressCtlA();
    await pressBackspace();
    await typeLines(text);
  }

  /// Types [text] where the caret is, with Enter for each line break, as
  /// on a desktop keyboard.
  Future<void> typeLines(String text) async {
    for (final (index, line) in text.split('\n').indexed) {
      if (index > 0) await pressEnter();
      if (line.isNotEmpty) await typeImeText(line);
    }
  }

  /// Picks [item] in the screen's menu.
  Future<void> chooseInMenu(String item) async {
    await tapAndSettle(find.byTooltip('Show menu'));
    await tapAndSettle(find.text(item));
  }

  /// Sets the open document's "Checked items" choice, from the default.
  Future<void> chooseCheckedItems(String choice) async {
    await chooseInMenu('Checked items: Move to end');
    await tapAndSettle(find.text(choice));
  }

  /// Starts a new document and types [text] into it, where the caret waits.
  Future<void> typeNewNote(String text) async {
    await tapAndSettle(find.byTooltip('New document'));
    await waitFor(find.byTooltip(placeAndName));
    await typeLines(text);
  }

  /// Picks [subfolder] in the open place-and-name dialog.
  Future<void> pickSubfolder(String subfolder) async {
    await waitFor(find.text('Top level'));
    await tapAndSettle(find.text('Top level'));
    await tapAndSettle(find.text(subfolder).last);
  }

  /// Adds [app]'s second folder, Work, from Manage folders.
  Future<void> addWorkFolder() async {
    await tapAndSettle(find.byTooltip('Manage folders'));
    await tapAndSettle(find.text('Add folder'));
    await waitFor(find.text('Work'));
    await pageBack();
    await pumpAndSettle();
  }

  /// Picks [folder] in the open place-and-name dialog.
  Future<void> pickFolder(String folder) async {
    await tapAndSettle(find.byType(DropdownButtonFormField<DocumentFolder>));
    await tapAndSettle(find.text(folder).last);
  }

  /// Fills in the open place-and-name dialog and confirms it.
  Future<void> fillPlace({
    String? folder,
    String? subfolder,
    String? name,
  }) async {
    if (folder != null) await pickFolder(folder);
    if (subfolder != null) await pickSubfolder(subfolder);
    if (name != null) {
      await enterText(find.widgetWithText(TextField, 'Name'), name);
    }
    await tapAndSettle(find.text('OK'));
  }

  /// Sets the open document's place and name.
  Future<void> placeNote({
    String? folder,
    String? subfolder,
    String? name,
  }) async {
    await tapAndSettle(find.byTooltip(placeAndName));
    await fillPlace(folder: folder, subfolder: subfolder, name: name);
  }

  /// The user switches to another app and comes back.
  void hideAndComeBack() {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
  }

  /// Removes [folder], refreshes, and waits through the retries until
  /// the app marks it as unreachable.
  Future<void> loseFolder(Directory folder) async {
    final trying =
        'Trying to reach ${folder.path.split(Platform.pathSeparator).last}…';
    folder.renameSync('${folder.path}-away');
    await tap(find.byTooltip('Refresh'));
    await waitFor(find.text(trying));
    await waitUntil(
      () => find.text(trying).evaluate().isEmpty,
      timeout: const Duration(seconds: 15),
    );
  }

  /// Opens the compare view the open document offers.
  Future<void> openCompare() async {
    await waitFor(find.text('Compare'));
    await tapAndSettle(find.text('Compare'));
  }

  /// Taps [choice] and confirms keeping it.
  Future<void> keep(Finder choice) async {
    await tapAndSettle(choice);
    await tapAndSettle(find.text('Keep'));
  }
}
