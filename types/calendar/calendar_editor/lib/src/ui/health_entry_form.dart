import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

/// The kinds of health entry the user can add, as the Add list names
/// them, each with the entry a new one starts as: the general ones first.
const healthKinds = <(String, HealthEntry)>[
  ('Medication', Medication('', dose: '')),
  ('Symptom', Symptom('', level: 1)),
  ('Measure', Measure('', value: '', unit: '')),
  ('Note', HealthNote()),
  ('Period', Period(PeriodFlow.medium)),
];

/// What a health entry form gives back: the [entry] and its [note].
typedef HealthEdit = ({HealthEntry entry, String note});

/// Asks for a health entry starting as [entry] with [note], titled
/// [title]; `null` if the user backed out.
Future<HealthEdit?> showHealthEntryForm(
  BuildContext context,
  HealthEntry entry, {
  String note = '',
  required String title,
}) => showDialog<HealthEdit>(
  context: context,
  builder: (_) => _HealthEntryForm(entry, note: note, title: title),
);

class _HealthEntryForm extends StatefulWidget {
  const _HealthEntryForm(this.entry, {required this.note, required this.title});

  final HealthEntry entry;
  final String note;
  final String title;

  @override
  State<_HealthEntryForm> createState() => _HealthEntryFormState();
}

class _HealthEntryFormState extends State<_HealthEntryForm> {
  late var _flow = switch (widget.entry) {
    Period(:final flow) => flow,
    _ => PeriodFlow.medium,
  };
  late var _level = switch (widget.entry) {
    Symptom(:final level) => level,
    _ => 1,
  };
  late final _name = TextEditingController(
    text: switch (widget.entry) {
      Symptom(:final name) ||
      Medication(:final name) ||
      Measure(:final name) => name,
      _ => '',
    },
  );
  late final _amount = TextEditingController(
    text: switch (widget.entry) {
      Medication(:final dose) => dose,
      Measure(:final value) => value,
      _ => '',
    },
  );
  late final _unit = TextEditingController(
    text: switch (widget.entry) {
      Measure(:final unit) => unit,
      _ => '',
    },
  );
  late final _note = TextEditingController(text: widget.note);

  @override
  void dispose() {
    for (final field in [_name, _amount, _unit, _note]) {
      field.dispose();
    }
    super.dispose();
  }

  HealthEntry get _entry => switch (widget.entry) {
    Period() => Period(_flow),
    Symptom() => Symptom(_name.text.trim(), level: _level),
    Medication() => Medication(_name.text.trim(), dose: _amount.text.trim()),
    Measure() => Measure(
      _name.text.trim(),
      value: _amount.text.trim(),
      unit: _unit.text.trim(),
    ),
    HealthNote() => const HealthNote(),
  };

  bool get _named => switch (widget.entry) {
    Symptom() || Medication() || Measure() => _name.text.trim().isNotEmpty,
    Period() || HealthNote() => true,
  };

  @override
  Widget build(BuildContext context) {
    TextField field(TextEditingController controller, String label) =>
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {}),
        );
    return AlertDialog(
      title: Text(widget.title),
      // One width whatever is picked.
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...switch (widget.entry) {
                Period() => [
                  SegmentedButton<PeriodFlow>(
                    showSelectedIcon: false,
                    segments: [
                      for (final flow in PeriodFlow.values)
                        ButtonSegment(value: flow, label: Text(flow.name)),
                    ],
                    selected: {_flow},
                    onSelectionChanged: (picked) =>
                        setState(() => _flow = picked.single),
                  ),
                ],
                Symptom() => [
                  field(_name, 'Symptom'),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Mild')),
                      ButtonSegment(value: 2, label: Text('Medium')),
                      ButtonSegment(value: 3, label: Text('Strong')),
                    ],
                    selected: {_level},
                    onSelectionChanged: (picked) =>
                        setState(() => _level = picked.single),
                  ),
                ],
                Medication() => [
                  field(_name, 'Medication'),
                  field(_amount, 'Dose'),
                ],
                Measure() => [
                  field(_name, 'What'),
                  field(_amount, 'Value'),
                  field(_unit, 'Unit'),
                ],
                HealthNote() => const <Widget>[],
              },
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 4,
                autofocus: widget.entry is HealthNote,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _named
              ? () => Navigator.pop(context, (entry: _entry, note: _note.text))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
