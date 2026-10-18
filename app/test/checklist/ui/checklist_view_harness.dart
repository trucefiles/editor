import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/checklist/checklist_editor.dart';
import 'package:truce_editor/checklist/ui/checklist_row.dart';
import 'package:truce_editor/checklist/ui/checklist_view.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';

import '../../support.dart';

/// A checklist shown on its own. Nothing is saved during the test; call
/// [close] at its end.
final class ShownChecklist {
  ShownChecklist._(this._tester, this._session, this._editor);

  final WidgetTester _tester;
  final NoteEditSession _session;
  final ChecklistEditor _editor;

  /// The text of the list as edited.
  String get text => _editor.list.text;

  /// The text handed on to the note.
  String get saved => _session.text;

  /// Drops the session and its pending save before the test ends.
  Future<void> close() async {
    await _tester.pumpWidget(const SizedBox());
    _session.dispose();
  }
}

/// Shows [text] as a checklist.
Future<ShownChecklist> showChecklist(
  WidgetTester tester,
  String text, {
  bool separateDone = true,
}) async {
  final dir = tempFolder();
  final folder = folderAt(dir);
  final session = NoteEditSession(
    noteOf(folder, text),
    NoteFiles(folder, servicesFor(folder)),
    tempDrafts(),
    saveDelay: const Duration(days: 1),
  );
  final editor = ChecklistEditor(session);
  addTearDown(editor.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: ChecklistView(editor, separateDone: separateDone)),
      ),
    ),
  );
  return ShownChecklist._(tester, session, editor);
}

/// The text field showing [text].
Finder field(String text) => find.widgetWithText(TextField, text);

/// Text field of the [index]th item row.
Finder item(int index) => find.descendant(
  of: find.byType(ChecklistItemRow).at(index),
  matching: find.byType(TextField),
);

/// The steps of the checklist view tests.
extension ChecklistDriver on WidgetTester {
  TextField _field(Finder finder) => widget<TextField>(finder);

  /// Whether the field showing [text] has the focus.
  bool hasFocus(String text) => _field(field(text)).focusNode!.hasFocus;

  TextSelection selectionOf(String text) =>
      _field(field(text)).controller!.selection;

  /// What the field found by the hint or text [text] holds.
  String typedIn(String text) => _field(field(text)).controller!.text;

  double top(Finder finder) => getTopLeft(finder).dy;

  Future<void> tapAndPump(Finder finder) async {
    await tap(finder);
    await pump();
  }

  Future<void> tapAndSettle(Finder finder) async {
    await tap(finder);
    await pumpAndSettle();
  }

  Future<void> pressAndPump(LogicalKeyboardKey key) async {
    await sendKeyEvent(key);
    await pump();
  }

  Future<void> pressAndSettle(LogicalKeyboardKey key) async {
    await sendKeyEvent(key);
    await pumpAndSettle();
  }

  /// Presses the keyboard's Enter (done) key.
  Future<void> pressEnter() async {
    await testTextInput.receiveAction(TextInputAction.done);
    await pump();
    await pump();
  }

  Future<void> dragAndSettle(
    Finder finder,
    Offset offset, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    await drag(finder, offset, kind: kind);
    await pumpAndSettle();
  }

  /// Long-presses [handle] and drags it by [offset].
  Future<void> dragHandle(Finder handle, Offset offset) async {
    final gesture = await startGesture(getCenter(handle));
    await pump(kLongPressTimeout);
    await gesture.moveBy(offset);
    await pump();
    await gesture.up();
    await pumpAndSettle();
  }

  /// Puts the cursor of [field] at [offset].
  Future<void> cursorIn(Finder field, int offset) async {
    await tapAndPump(field);
    _field(field).controller!.selection = TextSelection.collapsed(
      offset: offset,
    );
    await pump();
  }

  /// Puts the cursor of the field showing [text] at [offset].
  Future<void> cursorAt(String text, int offset) =>
      cursorIn(field(text), offset);
}
