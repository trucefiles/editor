import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';

/// The link dialog: what it asks and what it answers.
void main() {
  group('withScheme', () {
    for (final (typed, leads) in [
      ('www.example.com', 'https://www.example.com'),
      ('  example.com ', 'https://example.com'),
      ('http://a.b', 'http://a.b'),
      ('mailto:me@a.b', 'mailto:me@a.b'),
      ('/notes/a.md', '/notes/a.md'),
      ('./a.md', './a.md'),
      ('../a.md', '../a.md'),
      ('#todo', '#todo'),
      ('  ', ''),
    ]) {
      test('"$typed" leads to "$leads"', () {
        expect(withScheme(typed), leads);
      });
    }
  });

  /// Opens the dialog and returns what it answered, once [act] is done.
  Future<LinkAnswer?> answer(
    WidgetTester tester,
    Future<void> Function() act, {
    String text = 'docs',
    String? url,
    bool removable = false,
  }) async {
    LinkAnswer? answered;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answered = await askLink(
              context,
              text: text,
              url: url,
              removable: removable,
            ),
            child: const Text('ask'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return answered;
  }

  testWidgets('adding: the text and the address with https added', (
    tester,
  ) async {
    final answered = await answer(tester, () async {
      expect(find.text('Add link'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Address'), 'a.b');
      await tester.tap(find.text('Add'));
    });

    expect(answered, isA<LinkSet>());
    final set = answered! as LinkSet;
    expect((set.text, set.url), ('docs', 'https://a.b'));
  });

  testWidgets('an empty address answers nothing', (tester) async {
    final answered = await answer(tester, () => tester.tap(find.text('Add')));

    expect(answered, isNull);
  });

  testWidgets('editing offers Open and, if removable, Remove link', (
    tester,
  ) async {
    final removed = await answer(
      tester,
      () => tester.tap(find.text('Remove link')),
      url: 'https://a.b',
      removable: true,
    );
    expect(removed, isA<LinkRemoved>());

    final opened = await answer(tester, () async {
      expect(find.text('Remove link'), findsNothing);
      await tester.tap(find.text('Open'));
    }, url: 'https://a.b');
    expect(opened, isA<LinkOpened>());
  });
}
