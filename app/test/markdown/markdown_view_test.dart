import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/markdown/markdown_view.dart';

void main() {
  Future<void> show(WidgetTester tester, String markdown) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: MarkdownView(markdown))),
  );

  testWidgets('shows Markdown without its markup', (tester) async {
    await show(tester, '# Title\n\nSome **bold** text.\n\n- [x] done');

    expect(find.text('Title'), findsOne);
    expect(find.text('Some bold text.'), findsOne);
    expect(find.byIcon(Icons.check_box), findsOne);
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('keeps line breaks as typed', (tester) async {
    await show(tester, 'one\ntwo');

    expect(find.text('one\ntwo'), findsOne);
  });
}
