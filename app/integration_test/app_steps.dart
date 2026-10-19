import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/editor/note_mode.dart';
import 'package:truce_editor/notes/ui/note_editor_screen.dart';

import 'test_app.dart';
import 'ui_driver.dart';

const savedOnDevice = 'Saved on this device. Tap to save in the folder now';
const placeAndName = 'Place and name';

/// The steps a user takes in the app, shared by the UI tests.
extension AppSteps on WidgetTester {
  /// Launches [app] and adds its notes folder.
  Future<void> addFolder(TestApp app) async {
    await app.launch(this);
    await waitFor(find.text('Add folder'));
    await tapAndSettle(find.text('Add folder'));
    await waitUntil(() => find.text('Add folder').evaluate().isEmpty);
  }

  /// Opens the note titled [title] from the grid.
  Future<void> openNote(String title) async {
    await waitFor(find.text(title));
    await tapAndSettle(find.text(title));
  }

  /// Waits until the open note has closed.
  Future<void> waitForNoteClosed({
    Duration timeout = const Duration(seconds: 15),
  }) => waitUntil(
    () => find.byType(NoteEditorScreen).evaluate().isEmpty,
    timeout: timeout,
  );

  /// Switches the open note to the mode labeled [mode], e.g. 'Read'.
  Future<void> chooseMode(String mode) async {
    await tapAndSettle(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton<NoteMode>),
    );
    await tapAndSettle(find.text(mode).last);
  }

  /// Types [text] over the open note's whole text, in Markdown edit.
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

  /// Sets the open note's "Checked items" choice, from the default.
  Future<void> chooseCheckedItems(String choice) async {
    await chooseInMenu('Checked items: Done section');
    await tapAndSettle(find.text(choice));
  }

  /// Starts a new note and types [text] into it, where the caret waits.
  Future<void> typeNewNote(String text) async {
    await tapAndSettle(find.byTooltip('New note'));
    await waitFor(find.byTooltip(placeAndName));
    await typeLines(text);
  }

  /// Picks [subfolder] in the open place-and-name dialog.
  Future<void> pickSubfolder(String subfolder) async {
    await waitFor(find.text('Top level'));
    await tapAndSettle(find.text('Top level'));
    await tapAndSettle(find.text(subfolder).last);
  }

  /// Fills in the open place-and-name dialog and confirms it.
  Future<void> fillPlace({String? subfolder, String? name}) async {
    if (subfolder != null) await pickSubfolder(subfolder);
    if (name != null) {
      await enterText(find.widgetWithText(TextField, 'Name'), name);
    }
    await tapAndSettle(find.text('OK'));
  }

  /// Sets the open note's place and name.
  Future<void> placeNote({String? subfolder, String? name}) async {
    await tapAndSettle(find.byTooltip(placeAndName));
    await fillPlace(subfolder: subfolder, name: name);
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

  /// Removes [app]'s notes folder, refreshes, and waits through the
  /// retries until the app marks it as unreachable.
  Future<void> loseFolder(TestApp app) async {
    app.notes.renameSync('${app.notes.path}-away');
    await tap(find.byTooltip('Refresh'));
    await waitFor(find.text('Trying to reach Notes…'));
    await waitUntil(
      () => find.text('Trying to reach Notes…').evaluate().isEmpty,
      timeout: const Duration(seconds: 15),
    );
  }

  /// Opens the compare view the open note offers.
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
