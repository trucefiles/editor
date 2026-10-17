import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto/af_adapter.dart';

const source =
    '# Shop  \n'
    '* [ ] milk\n'
    '\t* [X] eggs\n'
    '*   [ ] bread **fresh**\n'
    '\n'
    'Some text with trailing spaces   ';

Future<AfChecklist> pump(WidgetTester tester, [String text = source]) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  final model = AfChecklist(text);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
      home: Scaffold(
        body: AppFlowyEditor(
          editorState: model.editorState,
          autoFocus: true,
          characterShortcutEvents: [
            insertNewLineAfterTodoList,
            insertNewLine,
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return model;
}

Future<void> caret(WidgetTester tester, AfChecklist m, String id, int offset) async {
  Node? find(Node n) {
    if (n.id == id) return n;
    for (final c in n.children) {
      final f = find(c);
      if (f != null) return f;
    }
    return null;
  }
  final path = find(m.editorState.document.root)!.path;
  m.editorState.selection = Selection.collapsed(Position(path: path, offset: offset));
  await tester.pumpAndSettle();
}

/// Sends one IME insertion delta, as a platform keyboard does.
Future<void> type(WidgetTester tester, String char) async {
  final log = tester.testTextInput.log;
  final client = log.lastWhere((c) => c.method == 'TextInput.setClient').arguments[0] as int;
  final state = log.lastWhere((c) => c.method == 'TextInput.setEditingState').arguments as Map;
  final old = state['text'] as String;
  final at = state['selectionBase'] as int;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall('TextInputClient.updateEditingState', [
        client,
        {
          'text': old.replaceRange(at, at, char),
          'selectionBase': at + char.length,
          'selectionExtent': at + char.length,
          'selectionAffinity': 'TextAffinity.downstream',
          'selectionIsDirectional': false,
          'composingBase': -1,
          'composingExtent': -1,
        },
      ]),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

List<String> lines(String t) => t.split('\n');

void main() {

  testWidgets('typing changes only the touched line', (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '1', 4);
    await type(tester, ' and honey');
    debugPrint(m.text);
    expect(lines(m.text)[1], '* [ ] milk and honey');
    for (final i in [0, 2, 3, 4, 5]) {
      expect(lines(m.text)[i], lines(source)[i], reason: 'line $i');
    }
  });

  testWidgets('Enter splits the item', (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '3', 5);
    await type(tester, '\n');
    debugPrint('after enter:\n${m.text}\n---');
  });

  testWidgets('Backspace at item start', (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '3', 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    debugPrint('after 1 backspace:\n${m.text}\n---');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    debugPrint('after 2 backspaces:\n${m.text}\n---');
  });

  testWidgets('Tab / Shift+Tab', (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '3', 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    debugPrint('after tab:\n${m.text}\n---');
    String ids(Node n) => n.children.map((c) => '${c.id}[${ids(c)}]').join(' ');
    debugPrint('ids: ${ids(m.editorState.document.root)}');
  });

  testWidgets('checkbox tap', (tester) async {
    final m = await pump(tester);
    await tester.tap(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TodoListIcon').at(1));
    await tester.pumpAndSettle();
    debugPrint('after toggle:\n${m.text}\n--- writes ${m.writes.length}');
  });

  testWidgets('arrow down keeps column', (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '1', 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    debugPrint('down: ${m.editorState.selection}');
  });
}
