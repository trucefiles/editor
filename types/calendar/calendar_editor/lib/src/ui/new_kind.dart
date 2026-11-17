import 'package:flutter/material.dart';

/// What the user adds to a calendar.
enum NewKind { event, task }

/// Asks whether to add an event or a task; the pick, `null` if the user
/// closes the sheet.
Future<NewKind?> pickNewKind(BuildContext context) =>
    showModalBottomSheet<NewKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            for (final (kind, icon, label) in const [
              (NewKind.event, Icons.event_outlined, 'Event'),
              (NewKind.task, Icons.task_alt, 'Task'),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(context, kind),
              ),
          ],
        ),
      ),
    );
