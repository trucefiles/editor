/// Names shown before the rest is counted.
const _namedAtMost = 3;

/// [names] as one short list for the user: the first few in quotes,
/// then how many more (e.g. `"Dentist", "Swim" and 2 more`).
String fewNamed(List<String> names) {
  final named = names.take(_namedAtMost).map((name) => '"$name"').join(', ');
  final more = names.length - _namedAtMost;
  return more > 0 ? '$named and $more more' : named;
}
