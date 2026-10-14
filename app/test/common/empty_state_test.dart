import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/empty_state.dart';

void main() {
  testWidgets('shows a tinted icon, the text and the action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmptyState(
          icon: Icons.search_off,
          text: 'Nothing found.',
          action: TextButton(onPressed: () {}, child: const Text('Retry')),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.search_off));
    final context = tester.element(find.byType(EmptyState));
    expect(icon.color, Theme.of(context).colorScheme.primary);
    expect(find.text('Nothing found.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
