/// What the user is told once both versions were merged: that nothing
/// clashed, or which parts (e.g. events) kept the newer change, the
/// first few by name. [lost]: the names of the parts whose older
/// version was replaced.
String mergeOutcome(List<String> lost) => switch (lost) {
  [] => 'Merged, no clashes.',
  _ =>
    'Merged. Where both changed the same part, the newer change was kept: '
        '${_named(lost)}. The older versions are in Backups.',
};

/// Names shown before the rest is counted.
const _namedAtMost = 3;

/// [lost] as one short list: the first few names, then how many more.
String _named(List<String> lost) {
  final named = lost.take(_namedAtMost).map((name) => '"$name"').join(', ');
  final more = lost.length - _namedAtMost;
  return more > 0 ? '$named and $more more' : named;
}
