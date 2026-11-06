import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_editor/files/new_file/pick_new_file.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

import '../../support.dart';

void main() {
  final choices = appFileTypes().newFileChoices;

  /// Asks what to make new, and gives what the user picked to [picked].
  Future<void> pumpPicker(
    WidgetTester tester,
    void Function(NewFileChoice<EditableType>? pick) picked,
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

  testWidgets('every kind opens at once, a calendar too', (tester) async {
    NewFileChoice<EditableType>? pick;
    await pumpPicker(tester, (picked) => pick = picked);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(
      [for (final choice in choices) choice.label],
      ['Document', 'Plain text', 'Calendar', 'Health calendar'],
    );
    await tester.tap(find.text('Health calendar'));
    await tester.pumpAndSettle();

    expect(pick!.type, isA<CalendarFileType>());
    expect(pick!.label, 'Health calendar');
    expect(find.byType(TextField), findsNothing, reason: 'no name asked');
  });

  testWidgets('backing out of the choice makes nothing', (tester) async {
    NewFileChoice<EditableType>? pick;
    var asked = false;
    await pumpPicker(tester, (picked) {
      asked = true;
      pick = picked;
    });

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(asked, isTrue);
    expect(pick, isNull);
  });
}
