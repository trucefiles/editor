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
  final model = AfChecklist(text);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
      home: Scaffold(
        body: AppFlowyEditor(
          editorState: model.editorState,
          autoFocus: true,
          editorStyle: const EditorStyle.desktop().copyWith(
            textSpanDecorator: dimmedMarks,
          ),
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
    if (n.attributes['lineId'] == id) return n;
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

final _bold = RegExp(r'\*\*(.+?)\*\*');
const dim = Color(0xFF9E9E9E);

/// PROTOTYPE: same text, marks dimmed and bold between them.
InlineSpan dimmedMarks(BuildContext context, Node node, int index,
    TextInsert insert, TextSpan before, TextSpan after) {
  final text = insert.text;
  final base = before.style;
  final children = <TextSpan>[];
  var pos = 0;
  for (final m in _bold.allMatches(text)) {
    children
      ..add(TextSpan(text: text.substring(pos, m.start)))
      ..add(TextSpan(text: '**', style: const TextStyle(color: dim)))
      ..add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.bold)))
      ..add(TextSpan(text: '**', style: const TextStyle(color: dim)));
    pos = m.end;
  }
  children.add(TextSpan(text: text.substring(pos)));
  return TextSpan(style: base, children: children);
}

void main() {

  testWidgets('typing changes only the touched line', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '1', 4);
    await type(tester, ' and honey');
    debugPrint(m.text);
    expect(lines(m.text)[1], '* [ ] milk and honey');
    for (final i in [0, 2, 3, 4, 5]) {
      expect(lines(m.text)[i], lines(source)[i], reason: 'line $i');
    }
  });

  testWidgets('Enter splits the item', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '3', 5);
    await type(tester, '\n');
    debugPrint('after enter:\n${m.text}\n---');
    await type(tester, 'X');
    debugPrint('after X:\n${m.text}\n---');
  });

  testWidgets('Backspace at item start', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '3', 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    debugPrint('after 1 backspace:\n${m.text}\n---');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    debugPrint('after 2 backspaces:\n${m.text}\n---');
  });

  testWidgets('Tab / Shift+Tab', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '3', 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    debugPrint('after tab:\n${m.text}\n---');
    String ids(Node n) => n.children.map((c) => '${c.attributes['lineId']}/${c.id}[${ids(c)}]').join(' ');
    debugPrint('ids: ${ids(m.editorState.document.root)}');
  });

  testWidgets('checkbox tap', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final m = await pump(tester);
    await tester.tap(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TodoListIcon').at(1));
    await tester.pumpAndSettle();
    debugPrint('after toggle:\n${m.text}\n--- writes ${m.writes.length}');
  });

  testWidgets('arrow down keeps column', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final m = await pump(tester);
    await caret(tester, m, '1', 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    debugPrint('down: ${m.editorState.selection}');
  });

  testWidgets('dimmed marks', variant: TargetPlatformVariant.only(TargetPlatform.linux), (tester) async {
    final m = await pump(tester, '- [ ] bread **fresh** today');
    final span = tester
        .widgetList<RichText>(find.byWidgetPredicate((w) => w is RichText))
        .map((t) => t.text)
        .firstWhere((s) => s.toPlainText().contains('fresh'));
    final styles = <String>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.text != null && s.text!.isNotEmpty) {
        styles.add('${s.text}:${s.style?.fontWeight == FontWeight.bold ? 'B' : ''}${s.style?.color == dim ? 'dim' : ''}');
      }
      return true;
    });
    debugPrint(styles.join(' | '));
    await caret(tester, m, '0', 10);
    await type(tester, 'X');
    expect(m.text, '- [ ] bread **frXesh** today');
  });
}
