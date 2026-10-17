import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:proto/se_adapter.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  testWidgets('open-items editor leaves done lines in place', (tester) async {
    const text = '- [ ] a\n- [x] done1\n  - [ ] sub of done\n- [ ] b\n- [X] done2';
    final open = SeChecklist(
      text,
      shownFilter: (line, list) => !list.doneIds.contains(line.id),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: open.editor,
          inputSource: TextInputSource.ime,
          componentBuilders: [TaskComponentBuilder(open.editor), ...defaultComponentBuilders],
        ),
      ),
    ));
    expect([for (final n in open.document) n.id], ['0', '3']);
    await tester.placeCaretInParagraph('0', 1);
    await tester.typeImeText('!');
    await tester.pressEnter();
    await tester.typeImeText('new');
    debugPrint(open.text);
    expect(open.text,
        '- [ ] a!\n- [ ] new\n- [x] done1\n  - [ ] sub of done\n- [ ] b\n- [X] done2');
  });
}
