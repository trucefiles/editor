import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/choice_tile.dart';

void main() {
  testWidgets('shows the choice made; a tap asks for one and tells the '
      'pick, backing out tells nothing', (tester) async {
    final chosen = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChoiceTile(
            title: 'Fruit',
            subtitle: 'Apples',
            choices: const ['a', 'p'],
            labelOf: (fruit) => fruit == 'a' ? 'Apples' : 'Pears',
            current: 'a',
            onChosen: (fruit) async => chosen.add(fruit),
          ),
        ),
      ),
    );
    expect(find.text('Apples'), findsOneWidget);

    await tester.tap(find.text('Fruit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pears'));
    await tester.pumpAndSettle();
    expect(chosen, ['p']);

    await tester.tap(find.text('Fruit'));
    await tester.pumpAndSettle();
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(chosen, ['p']);
  });
}
