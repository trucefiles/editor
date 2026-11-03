import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/files/ui/all_files_view.dart';
import 'package:truce_files/truce_files.dart';

void main() {
  testWidgets('leading cards show in every order and look', (tester) async {
    for (final order in FileOrder.values) {
      for (final view in FileView.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AllFilesView(
                const [],
                settings: HomeSettings.standard.copyWith(
                  order: order,
                  view: view,
                ),
                folders: const [],
                leading: const [Text('orphan')],
              ),
            ),
          ),
        );

        expect(find.text('orphan'), findsOne, reason: '$order, $view');
      }
    }
  });
}
