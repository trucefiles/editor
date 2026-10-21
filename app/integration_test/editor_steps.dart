import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import 'app_steps.dart';
import 'test_app.dart';
import 'ui_driver.dart';

/// What a user does and sees in an open note's editor, with the mouse
/// and keyboard of a desktop.
extension EditorSteps on WidgetTester {
  /// The id of the node that holds a line reading [text], as the editor
  /// holds it.
  String lineNode(String text) => _lineAt(text).node;

  /// The node holding the line [text], and where that line starts in it.
  ({String node, int start}) _lineAt(String text) => [
    for (final node
        in SuperEditorInspector.findDocument()!.whereType<TextNode>())
      if (node.text.toPlainText().split('\n') case final lines
          when lines.contains(text))
        (
          node: node.id,
          start: lines
              .take(lines.indexOf(text))
              .fold(0, (start, line) => start + line.length + 1),
        ),
  ].first;

  /// Where the line node [nodeId] shows the character at [offset].
  Offset pointIn(String nodeId, int offset) {
    final layout = SuperEditorInspector.findDocumentLayout();
    final rect = layout.getRectForPosition(
      DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: offset),
      ),
    )!;
    return layout.getAncestorOffsetFromDocumentOffset(rect.center);
  }

  /// Clicks the line holding [text] at [offset] in it.
  Future<void> clickLine(String text, int offset) async {
    final (:node, :start) = _lineAt(text);
    await tapAt(pointIn(node, start + offset), kind: PointerDeviceKind.mouse);
    await pumpAndSettle();
  }

  /// Whether the editor shows a line reading exactly [text].
  bool showsLine(String text) =>
      find.text(text, findRichText: true).evaluate().isNotEmpty;

  /// Drags the item holding [text] by its handle with the mouse, by
  /// [offset].
  Future<void> dragItem(String text, Offset offset) async {
    final row = pointIn(lineNode(text), 0);
    final start = [
      for (final element in find.byIcon(Icons.drag_indicator).evaluate())
        if (element.renderObject case final RenderBox box)
          box.localToGlobal(box.size.center(Offset.zero)),
    ].firstWhere((center) => (center.dy - row.dy).abs() < 12);
    final gesture = await startGesture(start, kind: PointerDeviceKind.mouse);
    const steps = 10;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(offset / steps.toDouble());
      await pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await pumpAndSettle();
  }

  /// Presses the toolbar button labeled [label], e.g. 'Checklist'.
  Future<void> pressTool(String label) async {
    await tap(find.byTooltip(label));
    await pumpAndSettle();
  }

  /// Writes [text] as `note.md` in [app], adds its folder and opens the
  /// note [title] in Visual edit.
  Future<void> openVisual(TestApp app, String title, String text) async {
    app.write('note.md', text);
    await addFolder(app);
    await openNote(title);
    if (find.byTooltip('Mode: Visual edit').evaluate().isEmpty) {
      await chooseMode('Visual edit');
    }
  }

  /// Leaves the note and waits for `note.md` in [app] to hold [text].
  Future<void> leaveExpecting(TestApp app, String text) async {
    await pageBack();
    await waitForFile(app.file('note.md'), text);
  }
}
