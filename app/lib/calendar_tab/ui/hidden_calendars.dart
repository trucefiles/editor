import 'package:flutter/material.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_files/truce_files.dart';

import '../calendar_tab_controller.dart';

/// The chip that lists the calendars hidden from the Calendar tab, by
/// their count; the one the user picks to bring back is given to
/// [onShowAgain].
class HiddenCalendarsChip extends StatelessWidget {
  const HiddenCalendarsChip(
    this.hidden, {
    required this.colorOf,
    required this.onShowAgain,
    super.key,
  });

  final List<HiddenCalendar> hidden;
  final Color Function(ListedFile file) colorOf;
  final ValueChanged<ListedFile> onShowAgain;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(Icons.visibility_off_outlined),
    label: Text('Hidden (${hidden.length})'),
    onPressed: () async {
      final picked = await _pick(context);
      if (picked != null) onShowAgain(picked);
    },
  );

  /// The hidden calendar the user picks to bring back; `null` if none.
  Future<ListedFile?> _pick(BuildContext context) =>
      showModalBottomSheet<ListedFile>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const ListTile(title: Text('Tap a calendar to bring it back')),
              for (final calendar in hidden)
                ListTile(
                  leading: CalendarDot(colorOf(calendar.file)),
                  title: Text(calendar.title),
                  onTap: () => Navigator.pop(context, calendar.file),
                ),
            ],
          ),
        ),
      );
}
