import 'package:flutter/material.dart';

import '../../editor/checked_items.dart';

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
                'Shown apart under "Done" at the bottom; the file keeps its '
                'order.',
              ),
            ),
            RadioListTile(
              value: CheckedItems.toEnd,
              title: Text(checkedItemsName(CheckedItems.toEnd)),
              subtitle: const Text(
                'Checking moves an item to the end of the list in the file, '
                'unchecking moves it back below the open items.',
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
  CheckedItems.toEnd => 'Move to end',
};
