import 'package:flutter/material.dart';

/// Asks the user to pick one of [choices], each shown by [labelOf], with
/// [current] marked; the pick, or nothing if they back out. The pick
/// comes wrapped, so a choice of `null` (such as "No limit") is told
/// apart from backing out.
Future<(T,)?> showChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<T> choices,
  required String Function(T choice) labelOf,
  required T current,
}) => showDialog<(T,)>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: [
      RadioGroup<T>(
        groupValue: current,
        // A radio reports only the choice it stands for.
        onChanged: (choice) => Navigator.pop(context, (choice as T,)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in choices)
              RadioListTile<T>(value: choice, title: Text(labelOf(choice))),
          ],
        ),
      ),
    ],
  ),
);
