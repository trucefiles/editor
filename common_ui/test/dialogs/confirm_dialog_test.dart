import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

void main() {
  Future<Future<bool>> open(WidgetTester tester) async {
    late Future<bool> answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => answer = showConfirmDialog(
              context,
              title: 'Delete it?',
              message: 'It goes.',
              yes: 'Delete',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete it?'), findsOne);
    expect(find.text('It goes.'), findsOne);
    return answer;
  }

  testWidgets('yes confirms', (tester) async {
    final answer = await open(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
  });

  testWidgets('Cancel or closing does not', (tester) async {
    var answer = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);

    answer = await open(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });
}
