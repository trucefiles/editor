import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_core/truce_core.dart'
    show Edited, Replaced, SecureReason, Version;
import 'package:truce_editor/editor/document_editor.dart';
import 'package:truce_editor/editor/editor_gate.dart';
import 'package:truce_editor/editor/visual/library/library_nodes.dart';
import 'package:truce_editor/editor/visual/row_looks.dart';
import 'package:truce_markdown/truce_markdown.dart'
    show
        AskLink,
        CheckedItems,
        EditMode,
        EditorOutput,
        FromFile,
        ItemsRemoved,
        SecureEditor,
        StartSaveTimer,
        ToFile,
        UndoRefused,
        editorOwner;

/// An open document's editor owner in memory, as the editor views get it:
/// records the text it sends to be kept, and the links opened.
final class TestDocument {
  TestDocument(
    String text, {
    EditMode mode = EditMode.visual,
    CheckedItems checkedItems = CheckedItems.doneSection,
  }) : _text = text,
       gate = EditorGate(
         editorOwner(
           text,
           version: const Version(1),
           mode: mode,
           checkedItems: checkedItems,
         ),
       ) {
    final outputs = gate.outputs.listen(_onOutput);
    addTearDown(outputs.cancel);
    addTearDown(gate.dispose);
  }

  final EditorGate gate;

  /// Each text sent to be kept, in order.
  final edits = <String>[];

  /// What the owner asked of the user or told them, e.g. [ItemsRemoved].
  final notices = <EditorOutput>[];

  /// The links the user opened.
  final links = <String>[];

  String _text;
  int _rev = 0;
  int _version = 1;

  /// The text as the owner keeps it now, every edit sent.
  String get text {
    gate.external(const SecureEditor(SecureReason.hide));
    return _text;
  }

  /// The text as last sent, without asking for more.
  String get sent => _text;

  /// The file changed elsewhere to [text]; shown unless edited since the
  /// last text sent.
  void changeElsewhere(String text) {
    _text = text;
    gate.external(
      FromFile(Replaced(text, version: Version(++_version), ackRev: _rev)),
    );
  }

  void _onOutput(EditorOutput output) {
    switch (output) {
      case ToFile(input: Edited(:final text, :final rev)):
        edits.add(text);
        _text = text;
        _rev = rev;
      case AskLink() || ItemsRemoved() || UndoRefused():
        notices.add(output);
      case ToFile() || StartSaveTimer():
        break;
    }
  }
}

/// Shows [document] in its editor, in the mode it is in, in [theme] and
/// in what [around] puts around the app's screens.
Future<void> pumpDocument(
  WidgetTester tester,
  TestDocument document, {
  AddItemPlace addItems = AddItemPlace.top,
  ThemeData? theme,
  TransitionBuilder? around,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    builder: around,
    home: Scaffold(
      body: ListenableBuilder(
        listenable: document.gate,
        builder: (context, _) => DocumentEditor(
          document.gate,
          text: document.sent,
          notices: document.gate.outputs,
          addItems: addItems,
          onLink: document.links.add,
          images: (_) => null,
        ),
      ),
    ),
  ),
);

/// The id of the [index]th node of type [T] in the editor.
String nodeOf<T extends DocumentNode>({int index = 0}) =>
    SuperEditorInspector.findDocument()!.whereType<T>().elementAt(index).id;

/// The frames of the row [node] shows in Visual edit.
List<Frame> framesOf(DocumentNode node) => switch (lookOf(node)) {
  TextLook(:final frames) ||
  BlockLook(:final frames) ||
  RawTextLook(:final frames) => frames,
  _ => const [],
};

/// The item whose marker shows beside [node], if any.
ItemFrame? markedItemOf(DocumentNode node) =>
    switch (framesOf(node).whereType<ItemFrame>().lastOrNull) {
      final item? when item.starts => item,
      _ => null,
    };

/// The id of the [index]th text node that starts a checkbox item.
String checkboxNodeOf({int index = 0}) =>
    _textNodeOf(index, (item) => item?.marker is BoxMarker);

/// The id of the [index]th text node that starts a bullet or numbered
/// item.
String listItemNodeOf({int index = 0}) =>
    _textNodeOf(index, (item) => item != null && item.marker is! BoxMarker);

/// The id of the [index]th text node that starts no item.
String paragraphNodeOf({int index = 0}) =>
    _textNodeOf(index, (item) => item == null);

String _textNodeOf(int index, bool Function(ItemFrame? item) test) =>
    SuperEditorInspector.findDocument()!
        .whereType<TextNode>()
        .where((node) => test(markedItemOf(node)))
        .elementAt(index)
        .id;

/// The id of the node of line [index] in Markdown edit.
String lineNodeOf(int index) =>
    SuperEditorInspector.findDocument()!.getNodeAt(index)!.id;

/// A user's taps in the editor.
extension EditorRobot on WidgetTester {
  /// Where a finger taps the line [nodeId] at [offset]: the middle of the
  /// line. The library robot's own taps hit the line's top edge.
  Offset tapPointIn(String nodeId, int offset) {
    final layout = SuperEditorInspector.findDocumentLayout();
    final rect = layout.getRectForPosition(
      DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: offset),
      ),
    )!;
    return layout.getAncestorOffsetFromDocumentOffset(rect.center);
  }

  Future<void> caretIn(String nodeId, int offset) async {
    await tapAt(tapPointIn(nodeId, offset));
    await pump(kTapTimeout);
    await pumpAndSettle();
  }

  Future<void> selectWordIn(String nodeId, int offset) async {
    final point = tapPointIn(nodeId, offset);
    await tapAt(point);
    await pump(kTapMinTime + const Duration(milliseconds: 1));
    await tapAt(point);
    await pump(kTapTimeout);
    await pumpAndSettle();
  }

  /// Lets box taps wait out their time, so they are sent.
  Future<void> boxTapsSent(TestDocument document) async {
    await pump(document.gate.checkDelay);
    await pumpAndSettle();
  }
}
