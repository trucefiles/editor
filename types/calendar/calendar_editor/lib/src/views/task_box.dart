import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

/// What the user does with a task's date of the calendar keyed
/// [calendar]: taps it.
typedef OnTask<K> = void Function(K calendar, TaskEntry task);

/// The user checks a task's date of the calendar keyed [calendar] off
/// ([done]), or opens it again.
typedef OnCheck<K> = void Function(K calendar, TaskEntry task, bool done);

/// A task's box: checked once it is [done]. A tap tells [onChanged] the
/// other state; without it the box only shows the state. Own rather than
/// the framework's [Checkbox]: that one keeps its size and room around
/// it, and the box must fit a one-line tile in the month; screen readers
/// still hear a checkbox.
class TaskBox extends StatelessWidget {
  const TaskBox({
    required this.done,
    this.onChanged,
    this.color,
    this.size = 20,
    super.key,
  });

  final bool done;
  final ValueChanged<bool>? onChanged;

  /// The box's color; the text color around it if `null`.
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final icon = Icon(
      done ? Icons.check_box : Icons.check_box_outline_blank,
      size: size,
      color: color,
    );
    return Semantics(
      checked: done,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged(!done),
      child: ExcludeSemantics(
        child: onChanged == null
            ? icon
            : Tooltip(
                message: done ? 'Mark as not done' : 'Mark as done',
                child: InkResponse(
                  onTap: () => onChanged(!done),
                  radius: size,
                  child: icon,
                ),
              ),
      ),
    );
  }
}
