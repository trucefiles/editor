import 'package:flutter/material.dart';

/// A color as a dot, beside the name of what has it: a calendar, an
/// event.
class CalendarDot extends StatelessWidget {
  const CalendarDot(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CircleAvatar(radius: 9, backgroundColor: color);
}
