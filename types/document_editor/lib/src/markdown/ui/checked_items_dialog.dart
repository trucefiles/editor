import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

/// Lets the user pick where a checklist's checked items go; the choice,
/// or `null` if cancelled.
Future<CheckedItems?> showCheckedItemsDialog(
  BuildContext context, {
  required CheckedItems current,
}) => showDialog<CheckedItems>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text('Checked items'),
    children: [
      RadioGroup<CheckedItems>(
        groupValue: current,
        onChanged: (choice) => Navigator.pop(context, choice),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              value: CheckedItems.inPlace,
              title: Text(checkedItemsName(CheckedItems.inPlace)),
              subtitle: const Text('They stay where they are.'),
            ),
            RadioListTile(
              value: CheckedItems.doneSection,
              title: Text(checkedItemsName(CheckedItems.doneSection)),
              subtitle: const Text(
                'Shown under "Done" at the bottom, but they stay in place in '
                'the file.',
              ),
            ),
            RadioListTile(
              value: CheckedItems.moveToEnd,
              title: Text(checkedItemsName(CheckedItems.moveToEnd)),
              subtitle: const Text(
                'Checked items move to the end of the list. Uncheck one '
                'and it moves back up.',
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);

/// The name of [choice], also read after "Checked items:" in menus.
String checkedItemsName(CheckedItems choice) => switch (choice) {
  CheckedItems.inPlace => 'Stay in place',
  CheckedItems.doneSection => 'Show at end',
  CheckedItems.moveToEnd => 'Move to end',
};
