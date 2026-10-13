import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/markdown/markdown_view.dart';

void main() {
  Future<void> show(WidgetTester tester, String markdown) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: MarkdownView(markdown))),
  );

  /// Whether some rich text shows exactly [text].
  Finder rich(String text) => find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );

  testWidgets('shows headings and paragraphs without markup', (tester) async {
    await show(tester, '# Title\n\nSome **bold** and *soft* `code`.');

    expect(rich('Title'), findsOne);
    expect(rich('Some bold and soft code.'), findsOne);
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('shows lists with bullets, numbers and task boxes', (
    tester,
  ) async {
    await show(
      tester,
      '- apple\n- pear\n\n3. three\n4. four\n\n- [x] done\n- [ ] open',
    );

    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('3.'), findsOne);
    expect(find.text('4.'), findsOne);
    expect(find.byIcon(Icons.check_box), findsOne);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOne);
    expect(rich('open'), findsOne);
  });

  testWidgets('shows nested lists, quotes, code blocks and rules', (
    tester,
  ) async {
    await show(
      tester,
      '- outer\n  - inner\n\n> quoted\n\n```\nlet x = 1;\n```\n\n---\n',
    );

    expect(rich('inner'), findsOne);
    expect(rich('quoted'), findsOne);
    expect(find.text('let x = 1;'), findsOne);
    expect(find.byType(Divider), findsOne);
  });
}
