import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import '../ui/event_colors.dart';
import '../ui/occurrence_texts.dart';
import 'task_box.dart';

/// The tasks view: [tasks] in groups (overdue, today, later, no date),
/// and those done lately folded below. Each row shows its box in its
/// color ([shownColor], over its calendar's: [colorOf] its key), its title
/// (struck through once done), when it is due and, where several
/// calendars show, its calendar ([titleOf]). A tap on a row tells
/// [onTask], on its box [onCheck]; without [onCheck] the boxes only
/// show.
class TasksView<K> extends StatelessWidget {
  const TasksView({
    required this.tasks,
    required this.colorOf,
    this.titleOf,
    this.onTask,
    this.onCheck,
    super.key,
  });

  final TaskList<K> tasks;
  final Color Function(K calendar) colorOf;
  final String Function(K calendar)? titleOf;
  final OnTask<K>? onTask;
  final OnCheck<K>? onCheck;

  @override
  Widget build(BuildContext context) {
    final groups = [
      ('Overdue', tasks.overdue),
      ('Today', tasks.today),
      ('Later', tasks.later),
      ('No date', tasks.noDate),
    ].where((group) => group.$2.isNotEmpty);
    if (groups.isEmpty && tasks.done.isEmpty) {
      return Center(
        child: Text(
          'Nothing to do.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return PageWidth(
      builder: (context, padding) => ListView(
        padding: padding + const EdgeInsets.only(bottom: 88),
        children: [
          for (final (title, rows) in groups) ...[
            _GroupTitle(title),
            for (final row in rows) _row(row),
          ],
          if (tasks.done.isNotEmpty)
            ExpansionTile(
              title: Text('Done (${tasks.done.length})'),
              shape: const Border(),
              children: [for (final row in tasks.done) _row(row)],
            ),
        ],
      ),
    );
  }

  Widget _row(TaskRow<K> row) => _TaskTile(
    row.entry,
    color: shownColor(row.entry.part, colorOf(row.calendar)),
    calendar: titleOf?.call(row.calendar),
    onTap: switch (onTask) {
      final onTask? => () => onTask(row.calendar, row.entry),
      null => null,
    },
    onCheck: switch (onCheck) {
      final onCheck? => (done) => onCheck(row.calendar, row.entry, done),
      null => null,
    },
  );
}

/// A group's title in the tasks view.
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// One task's row: its box in [color], its title, when it is due and its
/// [calendar] if given.
class _TaskTile extends StatelessWidget {
  const _TaskTile(
    this.entry, {
    required this.color,
    required this.calendar,
    required this.onTap,
    required this.onCheck,
  });

  final TaskEntry entry;
  final Color color;
  final String? calendar;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onCheck;

  @override
  Widget build(BuildContext context) {
    final due = shortDueText(
      MaterialLocalizations.of(context),
      entry,
      use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final subtitle = [?due, ?calendar].join(' · ');
    return ListTile(
      leading: TaskBox(
        done: entry.done,
        color: color,
        onChanged: onCheck,
        // As large as the title, which grows with the text size.
        size: MediaQuery.textScalerOf(context).scale(24),
      ),
      title: Text(
        itemTitle(entry.part),
        style: entry.done
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      onTap: onTap,
    );
  }
}
