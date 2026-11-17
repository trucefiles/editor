import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

/// How a form's repeat choice reads.
const _frequencyWords = {
  Frequency.daily: 'Every day',
  Frequency.weekly: 'Every week',
  Frequency.monthly: 'Every month',
  Frequency.yearly: 'Every year',
};

/// A form's repeat: never or how often, picked from a list ([onRepeat]
/// tells a pick); a rule the list can't show is named, and can't be
/// changed here.
class RepeatField extends StatelessWidget {
  const RepeatField({required this.repeat, required this.onRepeat, super.key});

  final Repeat? repeat;
  final ValueChanged<Repeat?> onRepeat;

  @override
  Widget build(BuildContext context) => switch (repeat) {
    OtherRepeat(:final rule) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Repeats'),
      subtitle: Text("$rule (can't be changed here)"),
    ),
    final SimpleRepeat? repeat => DropdownButtonFormField<Frequency?>(
      initialValue: repeat?.frequency,
      decoration: const InputDecoration(labelText: 'Repeats'),
      items: [
        const DropdownMenuItem(child: Text('Never')),
        for (final MapEntry(key: frequency, value: text)
            in _frequencyWords.entries)
          DropdownMenuItem(value: frequency, child: Text(text)),
      ],
      onChanged: (frequency) => onRepeat(switch (frequency) {
        null => null,
        // The rest of a repeat the form shows stays.
        _ when repeat?.frequency == frequency => repeat,
        final frequency => SimpleRepeat(frequency),
      }),
    ),
  };
}
