import 'package:collection/collection.dart';

import '../read/component.dart';
import '../read/content_line.dart';

/// One health entry of a day: an all-day event tagged
/// `CATEGORIES:HEALTH,<KIND>`, with a readable summary for other apps and
/// its values in `X-TRUCE-*` properties.
sealed class HealthEntry {
  const HealthEntry();

  /// The kind, as `CATEGORIES` names it.
  String get kind;

  /// What other apps show of it.
  String get summary;

  /// Its values as properties.
  List<ContentLine> get values;

  /// The entry [event] holds; `null` if it is none (or of a kind the app
  /// doesn't know).
  static HealthEntry? of(Component event) {
    final categories = [
      for (final line in event.all('CATEGORIES'))
        for (final category in splitTextList(line.value))
          category.trim().toUpperCase(),
    ];
    if (!categories.contains(healthCategory)) return null;
    String text(String name) => unescapeText(event.value(name) ?? '');
    return switch (categories.firstWhereOrNull(
      (category) => category != healthCategory,
    )) {
      'PERIOD' => Period(
        Flow.values.firstWhereOrNull(
              (flow) => flow.name == text('X-TRUCE-FLOW').toLowerCase(),
            ) ??
            Flow.medium,
      ),
      'SYMPTOM' => Symptom(
        text('X-TRUCE-NAME'),
        level: (int.tryParse(text('X-TRUCE-LEVEL')) ?? 1).clamp(1, 3),
      ),
      'MEDICATION' => Medication(
        text('X-TRUCE-NAME'),
        dose: text('X-TRUCE-DOSE'),
      ),
      'MEASURE' => Measure(
        text('X-TRUCE-NAME'),
        value: text('X-TRUCE-VALUE'),
        unit: text('X-TRUCE-UNIT'),
      ),
      'NOTE' => const HealthNote(),
      _ => null,
    };
  }
}

/// The category every health entry has.
const healthCategory = 'HEALTH';

/// How strong a period day's flow is.
enum Flow { spotting, light, medium, heavy }

/// A day of the period.
final class Period extends HealthEntry {
  const Period(this.flow);

  final Flow flow;

  @override
  String get kind => 'PERIOD';

  @override
  String get summary => 'Period: ${flow.name}';

  @override
  List<ContentLine> get values => [ContentLine('X-TRUCE-FLOW', flow.name)];

  @override
  bool operator ==(Object other) => other is Period && other.flow == flow;

  @override
  int get hashCode => flow.hashCode;
}

/// A symptom, from 1 (mild) to 3 (strong).
final class Symptom extends HealthEntry {
  const Symptom(this.name, {required this.level});

  final String name;
  final int level;

  @override
  String get kind => 'SYMPTOM';

  @override
  String get summary => '$name: $level/3';

  @override
  List<ContentLine> get values => [
    ContentLine('X-TRUCE-NAME', escapeText(name)),
    ContentLine('X-TRUCE-LEVEL', '$level'),
  ];

  @override
  bool operator ==(Object other) =>
      other is Symptom && other.name == name && other.level == level;

  @override
  int get hashCode => Object.hash(name, level);
}

/// A medication taken, with its dose as the user writes it.
final class Medication extends HealthEntry {
  const Medication(this.name, {required this.dose});

  final String name;
  final String dose;

  @override
  String get kind => 'MEDICATION';

  @override
  String get summary => dose.isEmpty ? name : '$name: $dose';

  @override
  List<ContentLine> get values => [
    ContentLine('X-TRUCE-NAME', escapeText(name)),
    if (dose.isNotEmpty) ContentLine('X-TRUCE-DOSE', escapeText(dose)),
  ];

  @override
  bool operator ==(Object other) =>
      other is Medication && other.name == name && other.dose == dose;

  @override
  int get hashCode => Object.hash(name, dose);
}

/// A measure (e.g. temperature, weight), its value and unit as written.
final class Measure extends HealthEntry {
  const Measure(this.name, {required this.value, required this.unit});

  final String name;
  final String value;
  final String unit;

  @override
  String get kind => 'MEASURE';

  @override
  String get summary => unit.isEmpty ? '$name: $value' : '$name: $value $unit';

  @override
  List<ContentLine> get values => [
    ContentLine('X-TRUCE-NAME', escapeText(name)),
    ContentLine('X-TRUCE-VALUE', escapeText(value)),
    if (unit.isNotEmpty) ContentLine('X-TRUCE-UNIT', escapeText(unit)),
  ];

  @override
  bool operator ==(Object other) =>
      other is Measure &&
      other.name == name &&
      other.value == value &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(name, value, unit);
}

/// A note of the day: its text is the event's description.
final class HealthNote extends HealthEntry {
  const HealthNote();

  @override
  String get kind => 'NOTE';

  @override
  String get summary => 'Note';

  @override
  List<ContentLine> get values => const [];

  @override
  bool operator ==(Object other) => other is HealthNote;

  @override
  int get hashCode => 0;
}
