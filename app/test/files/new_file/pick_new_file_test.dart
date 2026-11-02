import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/file_types/calendar_file_type.dart';
import 'package:truce_editor/files/new_file/pick_new_file.dart';

import '../../support.dart';

void main() {
  final choices = appFileTypes().newFileChoices;

  /// Asks what to make new, and gives what the user picked to [picked].
  Future<void> pumpPicker(
    WidgetTester tester,
    void Function(NewPick? pick) picked,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked(await pickNewFile(context, choices)),
          child: const Text('New'),
        ),
      ),
    ),
  );

  testWidgets('a document opens unnamed; a calendar is named first', (
    tester,
  ) async {
    NewPick? pick;
    await pumpPicker(tester, (picked) => pick = picked);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choices.first.label));
    await tester.pumpAndSettle();
    expect((pick!.made, pick!.name), (choices.first, ''));

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Health calendar'));
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Create');
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Me ');
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(pick!.made.type, isA<CalendarFileType>());
    expect(pick!.made.label, 'Health calendar');
    expect(pick!.name, 'Me');
  });

  testWidgets('backing out of the name makes nothing', (tester) async {
    NewPick? pick;
    var asked = false;
    await pumpPicker(tester, (picked) {
      asked = true;
      pick = picked;
    });

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(asked, isTrue);
    expect(pick, isNull);
  });
}
