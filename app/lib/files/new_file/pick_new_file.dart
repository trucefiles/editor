import 'package:flutter/material.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

/// Asks what to make new among [choices]: no question if there is only
/// one. `null` if the user backed out.
Future<NewFileChoice<EditableType>?> pickNewFile(
  BuildContext context,
  List<NewFileChoice<EditableType>> choices,
) async => choices.length == 1
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
