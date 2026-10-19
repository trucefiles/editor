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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              value: CheckedItems.inPlace,
              title: Text('In place'),
              subtitle: Text('They stay where they are.'),
            ),
            RadioListTile(
              value: CheckedItems.doneSection,
              title: Text('Done section'),
              subtitle: Text(
                'Shown apart at the bottom; the file keeps its order.',
              ),
            ),
            RadioListTile(
              value: CheckedItems.toEnd,
              title: Text('Move to end'),
              subtitle: Text(
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

/// The name of [choice] in menus.
String checkedItemsName(CheckedItems choice) => switch (choice) {
  CheckedItems.inPlace => 'In place',
  CheckedItems.doneSection => 'Done section',
  CheckedItems.toEnd => 'Move to end',
};
