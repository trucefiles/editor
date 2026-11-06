import 'package:flutter/material.dart';

/// A calendar's color as a dot, beside its name.
class CalendarDot extends StatelessWidget {
  const CalendarDot(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CircleAvatar(radius: 9, backgroundColor: color);
}
