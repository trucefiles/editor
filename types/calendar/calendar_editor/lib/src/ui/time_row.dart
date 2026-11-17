import 'package:flutter/material.dart';

import 'occurrence_texts.dart';
import 'zone_picker.dart';

/// One row of a day and, unless all day, a time of day and below it its
/// time zone ([zone], `null` for the device's), each a button that asks
/// for a new one; no zone without [onZone].
class TimeRow extends StatelessWidget {
  const TimeRow({
    required this.label,
    required this.day,
    required this.time,
    this.zone,
    required this.onDay,
    required this.onTime,
    this.onZone,
    super.key,
  });

  final String label;
  final DateTime day;
  final TimeOfDay? time;
  final String? zone;
  final void Function(DateTime day) onDay;
  final void Function(TimeOfDay time) onTime;
  final void Function(String zone)? onZone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _dayAndTime(context),
      if ((time, onZone) case (_?, final onZone?))
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 64),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              textStyle: Theme.of(context).textTheme.bodySmall,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              final picked = await pickZone(context);
              if (picked != null) onZone(picked);
            },
            child: Text(switch (zone) {
              final zone? => zoneText(zone),
              null => 'Time zone',
            }),
          ),
        ),
    ],
  );

  Widget _dayAndTime(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final time = this.time;
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(1900),
                lastDate: DateTime(2200),
              );
              if (picked != null) onDay(picked);
            },
            child: Text(words.formatMediumDate(day)),
          ),
        ),
        if (time != null)
          TextButton(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked != null) onTime(picked);
            },
            child: Text(
              words.formatTimeOfDay(
                time,
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
