/// What the user is told once both versions were merged: that nothing
/// was lost, or which older versions (e.g. of events) newer changes
/// replaced, the first few by name. [lost]: the names of those older
/// versions.
String mergeOutcome(List<String> lost) => switch (lost) {
  [] => 'Merged. No changes were lost.',
  _ =>
    'Merged. Some conflicts were resolved automatically; the overwritten '
        'changes are in Backups: ${_named(lost)}.',
};

/// Names shown before the rest is counted.
const _namedAtMost = 3;

/// [lost] as one short list: the first few names, then how many more.
String _named(List<String> lost) {
  final named = lost.take(_namedAtMost).map((name) => '"$name"').join(', ');
  final more = lost.length - _namedAtMost;
  return more > 0 ? '$named and $more more' : named;
}
