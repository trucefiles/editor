/// Indexes of lines in [lines] that [other] lacks, counting repeats: a
/// line that appears twice here but once in [other] marks its second
/// occurrence. Order is ignored, so moved lines are not marked.
Set<int> changedLines(List<String> lines, List<String> other) {
  final available = <String, int>{};
  for (final line in other) {
    available[line] = (available[line] ?? 0) + 1;
  }
  final changed = <int>{};
  for (var i = 0; i < lines.length; i++) {
    final left = available[lines[i]] ?? 0;
    if (left == 0) {
      changed.add(i);
    } else {
      available[lines[i]] = left - 1;
    }
  }
  return changed;
}
