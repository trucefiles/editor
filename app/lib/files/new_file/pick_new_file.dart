import 'package:flutter/material.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

import 'name_dialog.dart';

/// What the user picked to make new, and the name they gave it first if
/// it is named.
typedef NewPick = ({NewFileChoice<EditableType> made, String name});

/// Asks what to make new among [choices]: no question if there is only
/// one; a name first for one that is named. `null` if the user backed
/// out.
Future<NewPick?> pickNewFile(
  BuildContext context,
  List<NewFileChoice<EditableType>> choices,
) async {
  final made = choices.length == 1
      ? choices.single
      : await showModalBottomSheet<NewFileChoice<EditableType>>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final choice in choices)
                  ListTile(
                    title: Text(choice.label),
                    onTap: () => Navigator.pop(context, choice),
                  ),
              ],
            ),
          ),
        );
  if (made == null || !context.mounted) return null;
  if (!made.named) return (made: made, name: '');
  final name = await showNameDialog(context, title: 'New ${made.label}');
  return name == null ? null : (made: made, name: name);
}
