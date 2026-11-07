import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'occurrence_texts.dart';

/// Asks the user for a time zone, found by typing part of its name; the
/// one picked (an IANA name), `null` if they back out.
Future<String?> pickZone(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _ZonePicker());

class _ZonePicker extends StatefulWidget {
  const _ZonePicker();

  @override
  State<_ZonePicker> createState() => _ZonePickerState();
}

class _ZonePickerState extends State<_ZonePicker> {
  /// Every zone with how it reads, read once as the picker opens.
  final _zones = [for (final zone in zoneNames()) (zone, zoneText(zone))];
  var _search = '';

  @override
  Widget build(BuildContext context) {
    final found = [
      for (final (zone, text) in _zones)
        if (text.toLowerCase().contains(_search)) (zone, text),
    ];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Time zone, e.g. Berlin',
                ),
                onChanged: (search) =>
                    setState(() => _search = search.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: found.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(found[index].$2),
                  onTap: () => Navigator.pop(context, found[index].$1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
