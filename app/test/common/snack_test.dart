import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/snack.dart';

void main() {
  group('a hint shows', () {
    test('at least 4 seconds, even when short', () {
      expect(
        hintDuration('Removed', withAction: false),
        const Duration(seconds: 4),
      );
    });

    test('longer as its text grows', () {
      // 2 s and 1 s per 15 characters.
      expect(
        hintDuration('x' * 90, withAction: false),
        const Duration(seconds: 8),
      );
    });

    test('at most 10 seconds, however long', () {
      expect(
        hintDuration('x' * 500, withAction: false),
        const Duration(seconds: 10),
      );
    });

    test('the full 10 seconds with an action such as Undo', () {
      expect(
        hintDuration('File deleted', withAction: true),
        const Duration(seconds: 10),
      );
    });
  });

  testWidgets('a hint can be closed before its time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSnack(context, 'Reloaded.'),
              child: const Text('Tell'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tell'));
    await tester.pumpAndSettle();
    expect(find.text('Reloaded.'), findsOne);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Reloaded.'), findsNothing);
  });
}
